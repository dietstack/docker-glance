## Glance docker

`Still in development!!!`

### Using

```
git clone git@172.27.10.10:openstack/glance-keystone.git
cd docker-glance
./build.sh
```
Result will be glance image in local image registry.

# Services

Glance project consists of several services/daemons (api, registry, cache, scrubbing). For the beginning we implement only api and registry which are vital for basic operation.
Both services are executed under Supervisor to cover multiple daemons with one daemon. This daemon is then runned by docker CMD command.

