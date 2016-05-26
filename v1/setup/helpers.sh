#!/usr/bin/bash -x

# Handle retrying of all etcd sets and gets
function etcd-set() {
    etcdctl set $@
    while [ $? != 0 ]; do sleep 1; etcdctl set $@; done
}

# TODO: check this syntax
function etcd-get() {
    etcdctl get $@
    while [ $? != 0 ]; do sleep 1; etcdctl get $@; done
}

# Handle retrying of all fleet submits and starts
function submit-fleet-unit() {
    sudo fleetctl submit $@
    while [ $? != 0 ]; do sleep 1; sudo fleetctl submit $@; done
}

function start-fleet-unit() {
    sudo fleetctl start $@
    while [ $? != 0 ]; do sleep 1; sudo fleetctl submit $@; done
}