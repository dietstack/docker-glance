## Glance docker

### Using

```
git clone git@github.com:dietstack/glance-keystone.git
cd docker-glance
./build.sh
```
Result will be glance image in a local image registry.

# Development
There is a script called `test.sh`. This can be used either for development or testing. By default, script runs couple of docker containers (galera, memcached, keystone, glance), make tests and removes containers. This is used for testing purposes (also in CI).
When you run the script with parameter noclean, it'll build environment, runs all tests and leave all dockers running. This is usefol for development of glance containers.

# Services
Glance project consists of several services/daemons (api, registry, cache, scrubbing). For the beginning we implement only api and registry which are vital for basic operation.
Both services are executed under Supervisor to cover multiple daemons with one daemon. Supervisor is then run by docker CMD command.

