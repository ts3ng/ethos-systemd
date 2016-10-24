### 2016-10-21
* Updated to [booster v0.5](https://github.com/adobe-platform/booster/blob/master/CHANGELOG.md#v05)
* Update aqua agent service to add docker kill aqua-launcher before starting container

### 2016-10-20
* added LVC support to splunk units. set new etcd values /splunk/config/cloudops/hvc-endpoint and /splunk/config/cloudops/lvc-endpoint instead of /splunk/config/cloudops/forward-server-list in your secrets file.

### 2016-10-14
* Remove image authorization and will re add after aqua separates image authorization with image scanning

### 2016-10-18
* Added support for Splunk low-/high-volume index tokens
* Updated docker-fluentd image to 1.0.4

### 2016-10-12
* Added 2 environment variables to booster fleet

### 2016-10-10
* Update aqua version to 1.2.3
* Move away from behance launcher container

### 2016-10-10
* Allow for the configuration of docker logging driver for application deployments.

### 2016-10-06
* Update to mesos-proxy with `jsonp` fix

### 2016-10-05
* audit-docker-daemon

### 2016-09-30
* Templatize booster fleet units for better dependency management

### 2016-09-21
* Added CHANGELOG
* Updated PULL_REQUEST_TEMPLATE.md
