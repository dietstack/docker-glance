#!/bin/bash
# Integration test for glance service
# Test runs mysql,memcached,keystone and glance container and checks whether glance is running on public and admin ports

DOCKER_PROJ_NAME=${DOCKER_PROJ_NAME:-''}
CONT_PREFIX=test

. lib/functions.sh

http_proxy_args="-e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e no_proxy=${no_proxy:-}"

cleanup() {
    echo "Clean up ..."
    docker stop ${CONT_PREFIX}_mariadb
    docker stop ${CONT_PREFIX}_memcached
    docker stop ${CONT_PREFIX}_keystone
    docker stop ${CONT_PREFIX}_glance

    docker rm -v ${CONT_PREFIX}_mariadb
    docker rm -v ${CONT_PREFIX}_memcached
    docker rm -v ${CONT_PREFIX}_keystone
    docker rm -v ${CONT_PREFIX}_glance
}

cleanup

##### Start Containers

echo "Starting mariadb container ..."
docker run  --net=host -d -e MYSQL_ROOT_PASSWORD=veryS3cr3t --name ${CONT_PREFIX}_mariadb \
       mariadb:10.1

echo "Wait till mariadb is running ."
wait_for_port 3306 120

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_memcached memcached

# build glance container for current sources
./build.sh

echo "Wait till Memcached is running ."
wait_for_port 11211 30

# create databases
create_db_osadmin keystone keystone veryS3cr3t veryS3cr3t
create_db_osadmin glance glance veryS3cr3t veryS3cr3t

echo "Starting keystone container"
docker run -d --net=host \
           -e DEBUG="true" \
           -e DB_SYNC="true" \
           $http_proxy_args \
           --name ${CONT_PREFIX}_keystone ${DOCKER_PROJ_NAME}keystone:latest

echo "Wait till keystone is running ."

wait_for_port 5000 120
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 5000 (Keystone) not bounded!"
    exit $ret
fi

wait_for_port 35357 120
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 35357 (Keystone Admin) not bounded!"
    exit $ret
fi

echo "Starting glance container"
GLANCE_TAG=$(docker images | grep -w glance | head -n 1 | awk '{print $2}')
docker run -d --net=host \
           -e DEBUG="true" \
           -e DB_SYNC="true" \
           -e LOAD_META="true" \
           $http_proxy_args \
           --name ${CONT_PREFIX}_glance ${DOCKER_PROJ_NAME}glance:$GLANCE_TAG

##### TESTS #####

wait_for_port 9191 120
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 9191 (Glance Registry) not bounded!"
    docker logs ${CONT_PREFIX}_glance
    exit $ret
fi

wait_for_port 9292 120
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 9292 (Glance API) not bounded!"
    docker logs ${CONT_PREFIX}_glance
    exit $ret
fi

echo "Return code $?"

# bootstrap openstack settings and upload image to glance
# bootstrap openstack settings
set +e

echo "Bootstrapping keystone"
docker run --rm --net=host -e DEBUG="true" --name bootstrap_keystone \
           ${DOCKER_PROJ_NAME}keystone:latest \
           bash -c "keystone-manage bootstrap --bootstrap-password veryS3cr3t \
                   --bootstrap-username admin \
                   --bootstrap-project-name admin \
                   --bootstrap-role-name admin \
                   --bootstrap-service-name keystone \
                   --bootstrap-region-id RegionOne \
                   --bootstrap-admin-url http://127.0.0.1:35357 \
                   --bootstrap-public-url http://127.0.0.1:5000 \
                   --bootstrap-internal-url http://127.0.0.1:5000 "

ret=$?
if [ $ret -ne 0 ]; then
    echo "Bootstrapping error!"
    exit $ret
fi

docker run --net=host --rm $http_proxy_args ${DOCKER_PROJ_NAME}osadmin:latest \
           /bin/bash -c ". /app/adminrc; bash -x /app/bootstrap.sh"
ret=$?
if [ $ret -ne 0 ] && [ $ret -ne 128 ]; then
    echo "Error: Keystone bootstrap error ${ret}!"
    exit $ret
fi
set -e

docker run --net=host --rm $http_proxy_args ${DOCKER_PROJ_NAME}osadmin /bin/bash -c "wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img -O /app/cirros.img; . /app/adminrc; openstack image create --container-format bare --disk-format qcow2 --file /app/cirros.img --public cirros"

ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Cirros image import error ${ret}!"
    exit $ret
fi

echo "======== Success :) ========="

if [[ "$1" != "noclean" ]]; then
    cleanup
fi
