# Optional Services on Ethos

The base Ethos clusters launch with the minimum required services (Mesos, Marathon, Zookeeper, etc.). For additional services, such as monitoring, logging, container registry logins, etc, an optional service must be defined.

## Folder Structure

The `/opt` folder is organized by the service name. Within each folder, the following structure is used:

```
└── demoservice
    ├── fleet
    │   └── demoservice.service
    ├── setup
    │   ├── common
    │   │   └── 001-script.sh
    │   └── leader
    │       └── 001-images.sh
    └── util
        └── helper.sh
```

Within the `/demoservice` service folder, the following subfolders are defined:

* `fleet`: The actual service files
* `setup`: 
    * `leader`: Scripts that will only be run once, on a single leader node. The best uses for these are to set default image values or perform other `etcd` actions to seed values into the cluster that will later be used by the service.
    * `common`: Scripts that will run on every node, including the leader. The best uses for these are file modifications, folder creation, downloading helper objects, etc.
* `util`: Scripts that are called by the service as part of `ExecStartPre` or `ExecStart`.

Additionally, the actual service files are provided (one or more).

## Setting Default Container Image Values

All Docker images that are used by the service should be defined in etcd `/images/demoservice`. The cluster works by first running a default script (`001-defaults.sh`) on the leader which sets the default image values for required containers (Mesos, etc.). Then, `003-optional.sh` runs all of the scripts inside of `/opt/demoservice/setup/leader`. These scripts can set the default image values used. Finally, the `004-custom.sh` script is run, which overrides any of these defaults based on the user's `secrets.json` `configs` section.

Your `001-images.sh` file inside of `/opt/demoservice/setup/leader` should look like:

```
#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../../lib/helpers.sh

etcd-set /images/demoservice-agent "index.docker.io/organization/demoservice-agent:latest"

```

If a user launching the stack wants to override this, they would do so in `secrets.json`.

## Execution Order

1. Cluster-required defaults are set
2. Optional service defaults are set (via the optional service's `leader/001-images.sh` file)
3. Additional, optional service leader-level scripts are run (remaining scripts in `/leader`)
4. Customer defaults optionally override these values
5. Common, optional service scripts are run on all nodes
6. Optional services are submitted

## Development Notes

* All work for the optional services should be done inside of `/opt`
* Default container image values _must_ be defined in `/opt/demoservice/leader/001-images.sh`. The user cannot be expected to provide image values for all optional services.
* If any script inside of `/opt/demoservice/util` makes AWS API calls, the IAM permissions in the `infrastructure` repository may likely need to be adjusted.
* If the service does not use a Docker image, the `leader` folder is optional.
* The `common` and `util` folders within each optional service are optional.
* IMPORTANT: any scripts in the `/opt` folder, must be executable (`chmod +x`)