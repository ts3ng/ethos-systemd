# Skopos

[TOC]
##Overview
Skopos mediates the orderly draining and rebooting of CoreOS worker nodes with the goal of no service disruption as the Mesos/Marathon created docker instances are migrated to non-draining nodes.  

Skopos' original use cases include supporting Ethos worker-tier OS updates and Booster scale down events.  However,  the script [v1/util/launch_workers_reboot.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/util/launch_workers_reboot.sh) can be used to trigger an orderly worker-tier drain/reboot for any reason.

Skopos employs a cluster-wide locking system backed by etcd and facilitated by [etcd-locks](https://github.com/adobe-platform/etcd-locks).   While [etcd-locks](https://github.com/adobe-platform/etcd-locks) is a separate project, it was created to support Skopos. 

> Note: [etcd-locks](https://github.com/adobe-platform/etcd-locks) is based on CoreOS' [locksmith](https://github.com/coreos/locksmith).   CoreOS' locksmith uses hardcoded etcd locking locations and outcomes(reboot) while etcd-locks generalizes cluster-wide locking making no assumption as to the purpose for the lock.  

For Skopos to be effective, the app instances running across the worker tier must balanced(scheduled) such that at least 2 instances are running on *different* nodes within the balancer space.  If you allow more than one simulataneous lock holder [/adobe.com/settings/etcd-locks/coreos_reboot/num_worker](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/setup/leader/001-defaults.sh#L130),  then you must have more num_workers+1 instances minimally running on separate nodes across the worker tier.

> Using the marathon constraint  `[[ hostname UNIQUE ]]`, with instance count of at least 2, should be used for effective use of Skopos. 

As docker provides a means to create user defined networks that can be wholey isolated, this project specifically targets docker instances running with *bridged* and *host* networks only - as defined by docker.

Skopos leverages Marathon's reaction to health check failures (re-deployment) by using iptables to force them fail on purpose.  By using a set of SYN blocking only iptable's rule to the pool of current TCP listeners, existing connections are allowed to complete while new connection attempts fail.  

> For this reason, it is vital that balancers do **not** Keep-Alive connections for more that 60 seconds.  

Since Marathon will move re-schedule unhealthy docker instances, it is important to block the draining Mesos slave from accepting new Mesos offers.  By using the Mesos maintenance API and/or stopping the mesos-slave (depending on Mesos version), new attempts to deploy to draining node are rejected ensuring redeployment happens on a new node.
 
## Assumptions
### General
- The system uses CoreOS
- The system uses AWS (for now)
- etcd is deployed to the control tier with at least 3 nodes
- etcd is accessible from all nodes in the cluster
- fleet functions on all nodes in the cluster
- The mesos slave runs on all nodes in the worker tier
- The mesos masters run in the control tier
- Zookeeper runs on the same node as the mesos-master
- Only docker instances managed by Mesos are drained in the worker tier
- Mesos master and slave are controlled by systemd units and these units are used to manage the Mesos life-cycle
- The system has enough available resources to handle all resources re-scheduled by marathon eminating from a drained node(s)
- The scale down operations supported (booster draining) by Skopos are considered an end of life task for the *host* i.e the ec2 instance gets destroyed
- Inbounds connections to marathon orchestrated apps, should be mediated by a balancer with a least 2 instances running on different nodes, are supported by this process for tapering and elimination.
> Inbound connection timeouts should ideally be set to 60 secs but no more than 300 seconds

- All flight-director/marathon applications include a health check
- Outbound connections are the responsibilty of the app instance.  However, the Skopos accommodates that shutdown by sending SIGTERM (via `docker kill --signal SIGTERM`) then waits 300 seconds before sending SIGKILL (via docker kill).

> marathon-lb supports docker instance labeling that, in the future, be used to control the time between `SIGTERM` and `SIGKILL`


## Limitations
- Marathon is currently unable to handle inverse offers from Mesos.
	 - Inverse offers are sent by mesos when a node is scheduled for maintenance
- docker instances not associated with a marathon job are assumed to be controlled by a systemd unit
- bash is the main scripting vehicle for Skopos so that it works with vanilla CoreOS


##Requirements
- [etcd-locks](https://github.com/adobe-platform/etcd-locks)

## Quick start

- **Skopos** launches a systemd service unit  - on all hosts, in all tiers - using by a global fleet unit launched on the etcd leader at cluster startup.  The skopos systemd unit runs [skopos.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/util/skopos.sh)  which runs forever.
- [skopos.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/util/skopos.sh), the target of the systemd unit skopos.service, drives an orderly reboot.
	-  To manually cause a reboot of a single host, visit that host and run
```
core@coreos: touch /var/lib/skopos/needs_reboot
```
- The **update-os.service** systemd unit runs like a one-shot launching every 5 minutes via **update-os.timer** every 5 minutes
	- *update-os.service* runs [update-os.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/util/update-check.sh) which runs **update_engine_client** to see if a reboot is needed and if so, it triggers **skopos** as above.
> Note: because **update-os.service** is a short-lived service, it appears to systemd -  most of the time -  as **inactive**.  Therefore, use **update-os.timer** for as  `systemdctl is-active update-os.timer`

- **update_engine.service** is the built in CoreOS unit that downloads and installs CoreOS updates.  It does not directly reboot a host.
- [launch_booster_drain.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/util/launch_booster_drain.sh) schedules a systemd unit via fleet targeting the current host for draining. 

- [launch_workers_reboot.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/util/launch_workers_reboot.sh) - triggers *skopos* mediated reboot on all hosts in the Ethos worker tier  
	- To cause the entire worker tier to reboot,run:
```
core@coreos:/home/core $ sudo ethos-systemd/v1/util/launch_worker_reboot.sh
```
- To control the number of simultaneous hosts are rebooting per tier, use 
```
etcdctl set /adobe.com/settings/etcd-locks/coreos_reboot/num_worker 1
etcdctl set /adobe.com/settings/etcd-locks/coreos_reboot/num_control 1
etcdctl set /adobe.com/settings/etcd-locks/coreos_reboot/num_proxy 1
```
For more cluster wide control, use ansible
> See `Running` below

## Flow
Console Trigger
![Console Trigger](https://git.corp.adobe.com/pages/fortescu/images/coreos_console_trigger.svg)

Skopos

![Skopos](https://git.corp.adobe.com/pages/fortescu/images/skopos.svg)

App
![App](https://git.corp.adobe.com/pages/fortescu/images/app_deploy.svg)

Locust
![Locust](https://git.corp.adobe.com/pages/fortescu/images/locust.svg)


## Components
### Standard components
- etcd
- fleet

### Skopos components
Skopos leverages a locking system facilated by [etcd-locks](https://github.com/adobe-platform/etcd-locks) and etcd as well as a collection of scripts to handle the various steps in the draining process.
#### fleet/systemd units
Fleet is used to schedule global units with systemd.  Skopos provides scripts to dynamically create fleet units for booster draining and scheduling tier wide reboots.
##### Units
###### [update-os.service](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/fleet/required/update-os.service)
- In the past, update-os.service checked for updates and if required, it immediately caused a reboot.
- update-os.service continues to check for updates requiring reboot **but** now triggers skopos to coordinate the reboot instead of immediately rebooting.
- Invokes  [update-check.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/update-check.sh) 
> Note:  update-check.sh will permanently disable locksmith if it is still active.  locksmith cannot be used with skopos.
> Also, DO NOT make update-os.service a dependency of other units.  Use update-os.timer instead.

###### [update-os.timer](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/fleet/required/update-os.timer), [update-os.service](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/fleet/required/update-os.service)

 - update-os.timer systemd unit invokes update-os.service every 5 minutes

###### [skopos.service](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/fleet/skopos.service)
- The Skopos service unit watches for the existence of  `/var/lib/skopos/needs_reboot` to trigger the reboot mechanism.

> Note: Skopos removes `/var/lib/skopos/needs_reboot` on completion

- Under normal circumstances, the update-os.service systemd unit creates  `/var/lib/skopos/needs_reboot` to trigger skopos.service when the **update_engine_client** indicates the system needs a reboot.

- skopos.service proceeds when it can acquire the tier-wide lock.
	- Simultanous lock holder are controlled by the etcd value:
 ```
 $ etcdctl get /adobe.com/settings/etcd-locks/coreos_reboot/num_worker
 ```
 > The default value for /adobe.com/settings/etcd-locks/coreos_reboot/num_worker is 1

> Note: use `ethos-system/v1/util/lockctl.sh` to manually query, lock, unlock the tier-wide reboot lock from any host.  Exercise caution!

- Upon acquiring the tier-wide reboot lock, skopos invokes [drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/drain.sh)

- skopos.service can also be triggered asynchronously to reboot the entire worker tier by running `sudo ethos-systemd/v1/util/launch_workers_reboot.sh`


###### [drain-cleanup.timer](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/fleet/drain-cleanup.timer), [drain-cleanup.service](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/fleet/drain-cleanup.service), [drain-cleanup.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/drain-cleanup.sh)

 - drain-cleanup* works by using a systemd timer & service unit pairing.  
 - The service-unit's target [drain-cleanup.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/drain-cleanup.sh) cleans up after oneshots that are scheduled and launched asynchronously by fleet ([launch_workers_reboot.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/util/launch_workers_reboot.sh)) as oneshots and [launch_booster_drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/launch_booster_drain.sh) .
 - Without the drain-cleanup.sh, fleet book-keeping (etcd:/_coreos.com/fleet) keeps track of the fleet jobs forever, polluting etcd.

#### Docker images
##### [etcd-locks](https://github.com/adobe-platform/etcd-locks)

- [etcd-locks](https://github.com/adobe-platform/etcd-locks) provides a locking system that allows for a configurable number of simultaenous lock holders that can be logically grouped by tier.
- etcd-locks are akin to semaphores
- etcd-locks have values or *tokens*

> cluster-wide lock token values are the CoreOS machine-id (`cat /etc/machine-id`)

- skopos uses 2 types of locks: cluster-wide and host.
- cluster-wide locks have groups or tiers with a configurable number of simultaneous lock holder per-*group*.

> For instance, the *reboot* lock used for skopos.sh has 3 groups: control, proxy, and workers with simultaneous lock holders defaulting to 1,1 & 1 respectively.  In a large cluster, the worker group may allow for 2 or more simultaneous holders.

```
$ etcdctl ls --recursive | grep adobe.com
/adobe.com/locks/cluster-wide/booster_drain/groups/worker/semaphore
wide/booster_drain/groups/proxy/semaphore
/adobe.com/locks/cluster-wide/booster_drain/groups/control/semaphore
/adobe.com/locks/cluster-wide/coreos_reboot/groups/control/semaphore
/adobe.com/locks/cluster-wide/coreos_reboot/groups/worker/semaphore
/adobe.com/locks/cluster-wide/coreos_reboot/groups/proxy/semaphore
/adobe.com/locks/per-host/4cafcc53b54e4f65a942158944e09416
/adobe.com/locks/per-host/43de1d7058d74510bfe550b12a516111
/adobe.com/locks/per-host/1e5557a39de44ac88caa39dbfa64c14b
-- snip -- 
```

> Strictly speaking, groups names are arbitrary to [etcd-locks](https://github.com/adobe-platform/etcd-locks).  They are aligned with CoreOS/Ethos tiers for skopos.

- use [v1/util/lockctl.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/util/lockctl.sh) to view and manipulate cluster wide and host locks
- see [v1/lib/lock_helpers.sh](https://git.corp.adobe.com/adobe-platform/ethos-systemd/blob/master/v1/lib/lock_helpers.sh) to see how [etcd-locks](https://github.com/adobe-platform/etcd-locks) are wrapped for skopos.
- host locks are *named* using a host's machine-id.
    - they are intended to help mediate conflicting operations occurring within a single host.
        -  such as guarding from `update-os` and `booster-drain` from occurring at the same time and causing kaos.
    - skopos host lock token values are *REBOOT*, *DRAIN*,*BOOSTER*


#### Scripts
All scripts in skopos are placed in [ethos-systemd](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util).
Many scripts **source** [drain_helpers](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/lib/drain_helpers.sh) while all **source** [lock_helpers](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/lib/lock_helpers.sh).

##### [skopos.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/skopos.sh)
 - Target of Skopos systemd unit
 - Runs on every node via skopos.service
 - Watches for the existence /var/lib/skopos/needs_reboot
 - Acquires the reboot tier wide lock
 - Invokes drain.sh 
 - Reboots host
 - After reboot, waits for the node it rebooted to rejoin mesos before releasing the tier-wide lock
 
##### [drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/drain.sh)

 - Drives the draining process for control,  proxy, and worker tiers.  It uses all locking primitives, schedules mesos maintenance,  uses marathon api, docker and uses iptables to drain connections.
 - Acquires the host lock

##### [launch_workers_reboot.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/launch_workers_reboot.sh)
- Creates a dynamic `oneshot` fleet unit targeting all worker nodes.  This unit simply touches `/var/lib/skopos/needs_reboot` on all worker nodes.
- It can be called from **any** fleet enabled node
##### [launch_booster_drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/launch_booster_drain.sh)
- Creates a pure oneshot fleet unit to drive booster draining using only curl, the fleet socket (`/var/run/fleet.socket`) and the value CoreOS machine id (`/etc/machine-id`).
- The created unit targets only the host it's run from.  It uses the current host's machine-id.  Fleet identifies hosts for scheduling purposes by machine-id. 
- The script can trigger a callback on completion
- The script understands both cli switches and environment variables:
   - Environment variables
      -  `NOTIFY`
      -  `MACHINEID`
   - Command line switches
    `--notify <url>`
    
	   - invokes with url with curl
	   - default: 'mock' is a no-op
   
	    `--machine-id`
           - default: `cat /etc/machine-id`

- Invokes [booster-drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/booster-drain.sh)
- Can be called from any fleet enabled node
- Requires sudo

###### Example

- Via docker
   - Passing Environment, Mounting /var/run/fleet.socket
   
To satisfy this script, a docker image would include this script then be run  like this:
```
docker run -e MACHINEID=`cat /etc/machine-id` -v /var/run/fleet.socket:/var/run/fleet.socket  adobe-platform/booster
# /usr/local/bin/launch_booster_drain.sh
```
- From any ethos node targets the node its run.
```
sudo ethos-systemd/v1/util/launch_booster_drain.sh --notify http://www.google.com
```

#####  [booster-drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/booster-drain.sh)
The target of the fleet-unit created by  [launch_booster_drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/launch_booster_drain.sh).

It acquires the cluster-wide, tier specific `booster` lock.  It the then calls `drain.sh` with 'BOOSTER' (used with the host lock) and drives the drain.
If the `--notify` is used,  and is not `mock` then the url is invoked with the machine-id on completion.
#####  [lockctl.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/lockctl.sh)
- Provides a cli for locking, unlocking, state retrieval for host and cluster wide locks.
#### Mesos API related
These scripts are used to schedule downtime for mesos master & slaves from the perspective of the node it's executed on.  It determines the 'leader', forms the JSON with the node's context and performs the action.
##### [mesos_sched_drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/mesos_sched_drain.sh)
#####[mesos_down.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/mesos_down.sh)
#####[mesos_up.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/mesos_up.sh)
#####[mesos_status.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/mesos_status.sh)

#### Support scripts
##### Helpers
###### [lock_helpers.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/lib/lock_helpers.sh)
 These bash helpers provide wrappers around the [etcd-locks](https://github.com/adobe-platform/etcd-locks) docker image.
  They also establish an `exit` hook that provides *on-exit* chaining mechanism used extensively to clear iptables, free locks, free temp files, etc in case of unexpected exits.
###### [drain_helpers.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/lib/drain_helpers.sh)
  Contains script for draining tcp and docker instances.

####[read_tcp6](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/lib/read_tcp6.sh)
This script decodes established connections for docker instances running in bridged network mode.  Such connections are not reported by `netstat` as they are routed by iptables using `PREROUTING` and `FORWARDING` chains in the `nat` and `filter` tables respectively.

In short,  read_tcp6 gets called by drain.sh following this scheme:
- Retrieve the main docker instance pid
```
docker inspect -f '{{.State.Pid}}' dockerSHA
```
- Use the resulting pid to retrieve the process tree rooted by that pid
- From that process tree, get the list of listening ip/ports associated 

> Note: drain.sh makes heavy use of this to measure remaining connections.

## Process flow
This section gives an overview of important components

### [skopos.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/skopos.sh)
Skopos.sh mediates system reboots primarily due to CoreOS update events.

- If the current node holds the cluster-wide reboot lock on service startup:
  - Ensure zookeeper is up and healthy
  - Ensure mesos is up and healthy
  - Flush the SKOPOS table `iptables`
  - Tell Mesos that maintenance is complete
     - By calling Mesos maintenance API `/maintenance/up`
  - Release cluster-wide reboot-lock
- Wait for reboot trigger
   	- Currently, the presence of the file `/var/lib/skopos/needs_reboot` is the trigger
- wait forever for cluster-wide `reboot lock` for tier
- on acquiring lock, invoke [drain script](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/drain.sh) with token `REBOOT`
- on success, reboot *holding* drain lock

> Note: it is *very* important that the node re-establish itself *after* reboot *before* unlock reboot.

![Skopos](https://git.corp.adobe.com/pages/fortescu/images/skopos-flow1.svg)

<!--
st=>start: Skopos start
e=>end: Reboot
op1=>operation: Acquire Reboot lock
op2=>operation: Await Healthy Mesos
op3=>operation: Release Reboot lock
sub2=>operation: Sleep
sub1=>subroutine: Invoke drain.sh
cond=>condition: /var/lib/skopos/rebooting exist?
cond2=>condition: /var/lib/skopos/need_reboot exist?
cond3=>condition: success?
io=>inputoutput: Can't get host lock
io2=>inputoutput: Touch /var/lib/skopos/rebooting
st->cond
cond(yes,left)->op2
op2->op3->cond2
cond(no)->cond2
cond2(yes)->op1->sub1
cond2(no)->sub2->cond2
sub1->cond3
cond3(yes)->io2->e
cond3(no)->op3
-->

### [drain.sh](http://git.corp.adobe.com/adobe-platform/ethos-systemd/tree/master/v1/util/drain.sh) script
CLI with mulitple options available for standalone use.  It's primary callers are skopos.sh and booster-drain.sh.

#### options

##### drain
The primary option.  This script usually called by booster-drain.sh or skopos.sh.
The *drain* takes optional value that which gets used as the host lock value by [etcd-locks](https://github.com/adobe-platform/etcd-locks).  It is useful to use a verb to describe what called for drain.   drain values:
- *DRAIN*
The default.
- *REBOOT*
Value passed by skopos.sh when invoking `drain.sh drain REBOOT`
- *BOOSTER*
Value passed by booster-drain.sh.  Ex. `drain.sh drain BOOSTER`

###### Process
- setup
  - Determine Mesos unit for tier
    - If a mesos slave node, cross-reference mesos api, marathon api and docker api to yield target pids, ports, and instances tied to host.

- acquire the *host lock* using token value(*DRAIN*,*REBOOT*, or *BOOSTER*)
> Waits until acquired

   - register an on exit `lockctl unlock_host [DRAIN|BOOSTER|REBOOT]` once acquired

- if mesos-slave is 0.28 or less,  stop mesos-slave
> Note:  After 0.28, the mesos api is used to schedule draining which keeps new offers from arriving.  Unfortunately, using the mesos api */maintenance/down* call - before 0.28.1 - abruptly takes not only the mesos-slave process down but all docker dependents *without* draining
- call function drain_tcp
   - if the node is in the control tier,
         - Force Marathon leader away for node if necessary (waits)
	    - Use Mesos maintenance api to schedule, then down the node
	    > Note: Again after Mesos 0.28

   - Create iptables Chain `SKOPOS` on the PREROUTING (nat table) and filter (INPUT &FORWARD) chains
   > Note: this chain does not survive reboot - and shouldn't -  unless someone calls `iptables-save`

   - Create iptables rules derived from marathon, docker, mesos, and read_tcp data for both `bridge` and `host` docker networks
   > Note: at this point existing connections will continue while new connect attempts are refused.  Also, this works for the control tier with the lone exception that long-running connections ignore Mesos maintenance settings.

   - If the control tier, poll the mesos ELB endpoint and `/redirect`  api call until the current not is not a value.
      - Count down until the connection count reaches zero of 300 seconds elapses.

- call drain_docker
Drain docker calls
- unlock   *host lock*

###### Fig. drain overview:
![Skopos](https://git.corp.adobe.com/pages/fortescu/images/drain_overview.svg)

<!--
st=>start: drain.sh REBOOT
e=>end: exit(0)
fail=>end: exit(-1)
op1=>operation: Acquire host lock
io1=>subroutine: drain_tcp
io2=>subroutine: drain_docker
io3=>inputoutput: Release host lock
io4=>inputoutput: Sched Mesos down(API)
cond1=>condition: success?
cond2=>condition: Mesos API > 0.27
st->op1->cond1
cond1(yes)->cond2
cond1(no)->fail
cond2(no)->io1->io2->io3->e
cond2(yes)->io4->io1
-->

###### Fig. drain_tcp:
![Skopos](https://git.corp.adobe.com/pages/fortescu/images/drain_tcp.svg)

<!--
st=>start: drain tcp start
e=>end: Done
cond1=>condition: Total connections=0?
cond2=>condition: timeout?
io1=>inputoutput: Determine docker instances
io2=>inputoutput: Determine process/listener tree
io3=>inputoutput: Sleep
op4=>operation: SYN Block listeners
st->io1->io2
io2->op4->cond1
cond1(no,left)->cond2
cond1(yes)->e
cond2(yes)->e
cond2(no)->cond1
-->
##### drain docker:
![drain_docker](https://git.corp.adobe.com/pages/fortescu/images/drain_docker.svg)

<!--
st=>start: drain tcp start
e=>end: Done
cond1=>condition: Total connections=0 or timeout?
cond2=>condition: timeout exceeded?
io1=>inputoutput: Determine docker instances
op1=>operation: count active instances
op2=>operation: send SIGTERM to instances
op3=>operation: send SIGKILL to instances
op4=>operation: Sleep
cond1=>condition: Alive > 0 ?
st->io1->op2
op2->op1->cond1
cond1(no)->e
cond1(yes)->cond2
cond2(no)->op1
cond2(yes)->op3->e
-->

##### show_fw_rules
**Shows** the firewall rules that **will** be used during draining.
###### Example
```
core@ip-172-16-26-239 ~ $ sudo ethos-systemd/v1/util/drain.sh show_fw_rules
iptables -A SKOPOS -p tcp -m string --algo bm --string ELB-HealthChecker -j REJECT
iptables -A SKOPOS -p tcp --syn --dport 8080 -d 0.0.0.0/0 -j REJECT
iptables -A SKOPOS -p tcp --syn --dport 5050 -d 0.0.0.0/0 -j REJECT
drain.sh show_fw_rules
```
##### connections
Shows the total number of connections open to resources targeted for the tier.
For the worker,  aka mesos-slave nodes, this is a measure of the *mesos* initiated docker instances.  All other docker instances are not counted.
###### Examples
```
core@ip-172-16-26-239 ~ $ sudo ethos-systemd/v1/util/drain.sh connections
172.16.26.239:5050 172.16.26.237:38506
172.16.26.239:5050 172.16.26.239:42362
172.16.26.239:5050 172.16.27.239:59845
172.16.26.239:5050 172.16.26.164:15168
172.16.26.239:5050 172.16.24.142:2619
172.16.26.239:5050 172.16.24.195:1245
```

### booster_drain.sh
- Follows a similar process to skopos.sh except that it needn't consider rebooting and reversing any action taken as it's action is end of life for the host.

- Acquire the cluster-wide *booster_drain* lock
- Call drain.sh with 'BOOSTER'
  - See drain.sh
  > Note: At this point all mesos driven docker containers are down as is the mesos unit (slave or master).  iptables rules



## Support
In order to show the draining, there must be load.  To create that load, a supporting golang project - [dcos-tests](https://github.com/f4tq/dcos-tests) - was written for testing skopos.  
### [dcos-tests](https://github.com/f4tq/dcos-tests)
http server project whose api accepts urls that sleep for the user provide period to simulate long running processes.
It also accepts a time period whereby it optionally sleeps after receiving `SIGTERM`  - after closing it's listener - to support testing **drain_docker**.   Existing connections remain in process and are allowed to finish if the period is long enough.
[dcos-tests](https://github.com/f4tq/dcos-tests) was deployed on 3 nodes with marathon constraint `[[ hostname UNIQUE ]]` via flight-director and capcom.
Prerequisites:
- start an ssh tunnel to your jump host with a SOCKS tunnel set
```
# ssh -o DynamicForward=localhost:1200 -N jumphost &
```
- start an http proxy capable of using the SOCKS tunnel to forward requests
	- http proxy `polipo` used here:
```
sudo polipo socksParentProxy=localhost:1200 diskCacheRoot=/dev/null
```  
Here are the flight-director json stanza used to create the app in flight director:
- Create the App
> Note: by default,  `polipo` uses port 8123 for proxy.  curl obeys the environment variable `http_proxy`.

```
http_proxy=localhost:8123 curl -v -XPOST -d@/home/fortescu/dcos/application-fd.json -H "Content-Type: application/json" -u admin:password -v http://10.74.131.170:2001/v2/applications
```

- Create the image
```
$ curl -v -XPOST -d@/home/fortescu/dcos/dcos-tests-v2-fd.json -H "Content-Type: application/json" -u admin:password -v http://10.74.131.170:2001/v2/images
```
where `dcos-tests-v2-fd.json` contains:
```
{
  "data": {
    "attributes": {
      "name": "LoadTestA",
      "application-id": "LoadTest",
      "container-image": "",
      "num-containers": 3,
      "exposed-ports": "8080",
      "proxy-port-mapping": "10005:8080",
      "cpus": 0.5,
      "memory": 256,
      "command": "/usr/local/bin/dcos-tests --debug --term-wait 20 --http-addr :8080",
      "job-type": "LONG_RUNNING",
      "scm-repo": "admin",
      "constraints": [
        [
          "hostname",
          "UNIQUE"
        ]
      ],
      "health-check-path": "/ping"
    },
    "type": "ImageDefinition"
  }
}
```

### locust
A 3 node locust was provisioned (master-slave mode) in the Ethos bastion tier to test Skopos.  It .  Skopos was tested with up to 3000 users sending 500 req/sec when a reboot was triggered without dropping a connection.

#### [test-drain.py](https://github.com/adobe-platform/skopos/blob/fleet/locust-1/test_drain.py)
#### [ansible driven build/start/stop](https://git.corp.adobe.com/fortescu/Mesos4Dexi/blob/master/drain_test.yml#L244)

## [drain_process.md](https://github.com/adobe-platform/skopos/blob/fleet/drain_process.md)


# Troubleshooting
All the following commands are performed with ansible

### Start skopos.sh with fleet
```
ansible coreos_control -i $INVENTORY  -m raw -a 'bash -c "set -x ; LOCALIP=$(curl -sS http://169.254.169.254/latest/meta-data/local-ipv4);  ( etcdctl member list  | grep \$LOCALIP | grep -q isLeader=true ) && fleetctl start update-os.service" '
```

### Stop skopos.sh with fleet
```
ansible coreos_control -i $INVENTORY  -m raw -a 'bash -c "set -x ; LOCALIP=$(curl -sS http://169.254.169.254/latest/meta-data/local-ipv4);  ( etcdctl member list  | grep \$LOCALIP | grep -q isLeader=true ) && fleetctl stop update-os.service" '
```

### Reset all locks, iptables wrt skopos
Stop skopos.sh first
```
ansible coreos_control:coreos_workers -i $INVENTORY  -m raw -a 'bash -c "rm -f /var/lib/skopos/needs_reboot; iptables -F SKOPOS; ethos-systemd/v1/util/mesos_up.sh; ethos-systemd/v1/util/lockctl.sh unlock_reboot; ethos-systemd/v1/util/lockctl.sh unlock_host REBOOT"'  -s
```
### Monitor progress of workers reboot
```
ansible coreos_workers -i $INVENTORY   -m raw -a 'bash -c "echo \"Reboot Lock holder: \$(ethos-systemd/v1/util/lockctl.sh reboot_state)\"; echo \"Booster Lock holder: \$(ethos-systemd/v1/util/lockctl.sh booster_state)\";echo \"MachineID: \$(cat /etc/machine-id)\" ; echo \"HostState: \$(ethos-systemd/v1/util/lockctl.sh host_state)\"; echo \"Load: \$(cat /proc/loadavg)\";echo \"Active Conns: \$(ethos-systemd/v1/util/drain.sh connections | wc -l )\"; ls -l /var/lib/skopos; echo \"mesos_status: \$(ethos-systemd/v1/util/mesos_status.sh)\"; echo -n \"uptime: \";uptime "; iptables -nL SKOPOS -v' -s
```

### Output last 25 lines of `journald -u update-os.service` across worker tier
```
ansible coreos_workers -i $INVENTORY  -m raw -a 'bash -c "journalctl -u update-os.service --no-pager  | tail -25 "' 
```
# Running
Ansible makes that task of managing an ethos cluster much easier. Controlling the drain process, whether due to updates requiring a reboot or booster drain for scale down, are no exception.

## Configuring Ansible
- Install Ansible
- The following examples rely on an ansible inventory configured [here](https://git.corp.adobe.com/fortescu/Mesos4Dexi/tree/master/inventory-ethos-f4tq) for the cluster named `f4tq`.  Use `sed` to adjust the inventory tags for your cluster.
- use `./ec2.py --refresh-cache` to update your ansible cache
- use `./ec2.ini` to configure boto/ansible
- Ansible relies on a properly configured ssh config file to work seemlessly.  For cluster `f4tq`,  taken from `osx:~/.ssh/config`:
```
-- snip --
Host ethos-f4tq 10.74.131.21 
     # no proxy
     Hostname 54.197.222.207
     ProxyCommand none 
     Compression yes
     ForwardAgent yes
     StrictHostKeyChecking no
     UserKnownHostsFile /dev/null
     ServerAliveInterval 50
     DynamicForward 1200
     User core 
Host 10.74.131.* ip-10-74-131-*.ec2.internal
     Compression yes
     ForwardAgent yes
     StrictHostKeyChecking no
     UserKnownHostsFile /dev/null
     ServerAliveInterval 50
     User core
     ProxyCommand ~/.ssh/proxy.sh localhost:1200 %h %p
-- snip --
```
> Note: [see this gist for proxy.sh](https://git.corp.adobe.com/gist/fortescu/f77a089fce45e4b20b786e3422a118c1)

## Want python in on your tier?
- Install the playbook [defunctzombie.coreos-bootstrap](https://github.com/defunctzombie/ansible-coreos-bootstrap)
```
sudo ansible-galaxy install defunctzombie.coreos-bootstrap
```
- Get [coreos_ansiblize.yml]( https://git.corp.adobe.com/fortescu/Mesos4Dexi/blob/master/coresos_ansiblize.yml)
- Use the ssh/inventory above.
### Example
Now you can use standard ansible modules.

####Put an ssh key on all tiers, all nodes
```
$ ansible coreos -i $INVENTORY  -m authorized_key -a 'key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvsf04kNxTClExmZ1R9X5Vqv7dhnB2C8QByqdw1KyS0iLQn fortescu@fortescu-osx"  user="core"' 
```
## Kick of an orderly (drained) worker tier reboot
Runs only on the etcd leader.
```
fortescu@vagrant $ ansible coreos_control -i $INVENTORY  -m raw -a 'bash -c "LOCALIP=$(curl -sS http://169.254.169.254/latest/meta-data/local-ipv4);  ( etcdctl member list  | grep \$LOCALIP | grep -q isLeader=true ) && ethos-systemd/v1/util/launch_workers_reboot.sh" ' -s
```
## Watch the logs across the cluster targeting workers.

Here is an active, healthy drain with one node complete, one in progress, and 3 waiting for the reboot lock
```
ortescu@vagrant:~/ethos-projects/f4tq-aug2016-drain$ ansible coreos_workers -i $INVENTORY  -m raw -a 'bash -c "journalctl -u update-os.service --no-pager  | tail -5 "'
10.74.131.125 | SUCCESS | rc=0 >>
Sep 09 05:45:10 ip-10-74-131-125.ec2.internal skopos.sh[18345]: [1473399910][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping
Sep 09 05:45:33 ip-10-74-131-125.ec2.internal skopos.sh[18345]: Error locking: semaphore is at 0
Sep 09 05:45:33 ip-10-74-131-125.ec2.internal skopos.sh[18345]: [1473399933][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping
Sep 09 05:45:56 ip-10-74-131-125.ec2.internal skopos.sh[18345]: Error locking: semaphore is at 0
Sep 09 05:45:56 ip-10-74-131-125.ec2.internal skopos.sh[18345]: [1473399956][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping


10.74.131.147 | SUCCESS | rc=0 >>
Sep 09 05:44:04 ip-10-74-131-147.ec2.internal skopos.sh[4055]: [1473399844][/home/core/ethos-systemd/v1/util/skopos.sh] Waiting for mesos http://10.74.131.147:5051/state to pass before freeing cluster-wide reboot lock
Sep 09 05:44:05 ip-10-74-131-147.ec2.internal skopos.sh[4055]: [1473399845][/home/core/ethos-systemd/v1/util/skopos.sh] Waiting for mesos http://10.74.131.147:5051/state to pass before freeing cluster-wide reboot lock
Sep 09 05:44:06 ip-10-74-131-147.ec2.internal skopos.sh[4055]: [1473399846][/home/core/ethos-systemd/v1/util/skopos.sh] Waiting for mesos http://10.74.131.147:5051/state to pass before freeing cluster-wide reboot lock
Sep 09 05:44:07 ip-10-74-131-147.ec2.internal skopos.sh[4055]: [1473399847][/home/core/ethos-systemd/v1/util/skopos.sh] mesos/up Unlocking cluster reboot lock
Sep 09 05:44:36 ip-10-74-131-147.ec2.internal skopos.sh[4055]: [1473399876][/home/core/ethos-systemd/v1/util/skopos.sh] finished update process.  everything normal ...


10.74.131.145 | SUCCESS | rc=0 >>
Sep 09 05:45:08 ip-10-74-131-145.ec2.internal skopos.sh[29070]: [1473399908][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping
Sep 09 05:45:31 ip-10-74-131-145.ec2.internal skopos.sh[29070]: Error locking: semaphore is at 0
Sep 09 05:45:31 ip-10-74-131-145.ec2.internal skopos.sh[29070]: [1473399931][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping
Sep 09 05:45:54 ip-10-74-131-145.ec2.internal skopos.sh[29070]: Error locking: semaphore is at 0
Sep 09 05:45:54 ip-10-74-131-145.ec2.internal skopos.sh[29070]: [1473399954][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping


10.74.131.177 | SUCCESS | rc=0 >>
Sep 09 05:46:08 ip-10-74-131-177.ec2.internal skopos.sh[14725]: [1473399968][/home/core/ethos-systemd/v1/util/drain.sh] get_connection_count: task_id phpinfo.phpinfo-server.cfortier--phpinfo---a----6d60311c-7579-11e6-b401-0acf33af2b2d.28881c02-7618-11e6-9c1b-5a3124ecbb2f has 0 connections
Sep 09 05:46:08 ip-10-74-131-177.ec2.internal skopos.sh[14725]: [1473399968][/home/core/ethos-systemd/v1/util/drain.sh] get_connection_by_task_Id: loadtest.loadtesta.f4tq--dcos-tests---v0.2----82f24dd7-7579-11e6-8eeb-12a45d8fa6ad.2887f4f0-7618-11e6-9c1b-5a3124ecbb2f docker pid: 10463 network mode: bridge
Sep 09 05:46:08 ip-10-74-131-177.ec2.internal skopos.sh[14725]: [1473399968][/home/core/ethos-systemd/v1/util/drain.sh] get_connection_count: task_id loadtest.loadtesta.f4tq--dcos-tests---v0.2----82f24dd7-7579-11e6-8eeb-12a45d8fa6ad.2887f4f0-7618-11e6-9c1b-5a3124ecbb2f has 1 connections
Sep 09 05:46:08 ip-10-74-131-177.ec2.internal skopos.sh[14725]: [1473399968][/home/core/ethos-systemd/v1/util/drain.sh] get_connection_by_task_Id: loadtest.loadtesta.f4tq--dcos-tests---v0.2----82f24dd7-7579-11e6-8eeb-12a45d8fa6ad.17277364-7619-11e6-9c1b-5a3124ecbb2f docker pid: 12167 network mode: bridge
Sep 09 05:46:08 ip-10-74-131-177.ec2.internal skopos.sh[14725]: [1473399968][/home/core/ethos-systemd/v1/util/drain.sh] get_connection_count: task_id loadtest.loadtesta.f4tq--dcos-tests---v0.2----82f24dd7-7579-11e6-8eeb-12a45d8fa6ad.17277364-7619-11e6-9c1b-5a3124ecbb2f has 1 connections


10.74.131.165 | SUCCESS | rc=0 >>
Sep 09 05:45:08 ip-10-74-131-165.ec2.internal skopos.sh[316]: [1473399908][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping
Sep 09 05:45:31 ip-10-74-131-165.ec2.internal skopos.sh[316]: Error locking: semaphore is at 0
Sep 09 05:45:31 ip-10-74-131-165.ec2.internal skopos.sh[316]: [1473399931][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping
Sep 09 05:45:54 ip-10-74-131-165.ec2.internal skopos.sh[316]: Error locking: semaphore is at 0
Sep 09 05:45:54 ip-10-74-131-165.ec2.internal skopos.sh[316]: [1473399954][/home/core/ethos-systemd/v1/util/skopos.sh] update-os|Can't get reboot lock. sleeping

```	


>
> Written with [StackEdit](https://stackedit.io/). 
> Get a table of contents when viewed with StackEdit!
