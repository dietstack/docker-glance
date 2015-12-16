#!/bin/bash
# Integration test for glance service
# Test runs mysql,memcached,keystone and glance container and checks whether glance is running on public and admin ports

GIT_REPO=172.27.10.10
RELEASE_REPO=172.27.9.130

. lib/functions.sh

cleanup() {
    echo "Clean up ..."
    docker stop galera
    docker stop memcached
    docker stop keystone
    docker stop glance

    docker rm galera
    docker rm memcached
    docker rm keystone
    docker rm glance
}

cleanup

##### Download/Build containers

# run galera docker image
get_docker_image_from_release galera http://${RELEASE_REPO}/docker-galera latest

# pull osmaster docker image
get_docker_image_from_release osmaster http://${RELEASE_REPO}/docker-osmaster latest

# pull keystone image
get_docker_image_from_release keystone http://${RELEASE_REPO}/docker-keystone latest

# pull osadmin docker image
get_docker_image_from_release osadmin http://${RELEASE_REPO}/docker-osadmin latest

##### Start Containers

echo "Starting galera container ..."
GALERA_TAG=$(docker images | grep -w galera | head -n 1 | awk '{print $2}')
docker run -d --net=host -e INITIALIZE_CLUSTER=1 -e MYSQL_ROOT_PASS=veryS3cr3t -e WSREP_USER=wsrepuser -e WSREP_PASS=wsreppass -e DEBUG= --name galera galera:$GALERA_TAG

echo "Wait till galera is running ."
wait_for_port 3306 30

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name memcached memcached

# build glance container for current sources
./build.sh

sleep 10

# create databases
create_keystone_db
create_glance_db

echo "Starting keystone container"
KEYSTONE_TAG=$(docker images | grep -w keystone | head -n 1 | awk '{print $2}')
docker run -d --net=host -e DEBUG="true" -e DB_SYNC="true" --name keystone keystone:$KEYSTONE_TAG

echo "Wait till keystone is running ."

wait_for_port 5000 30
if [ $? -ne 0 ]; then
    echo "Error: Port 5000 (Keystone) not bounded!"
    exit $?
fi

wait_for_port 35357 30
if [ $? -ne 0 ]; then
    echo "Error: Port 35357 (Keystone Admin) not bounded!"
    exit $?
fi

echo "Starting glance container"
GLANCE_TAG=$(docker images | grep -w glance | head -n 1 | awk '{print $2}')
docker run -d --net=host -e DEBUG="true" -e DB_SYNC="true" --name glance glance:$GLANCE_TAG

##### TESTS #####

wait_for_port 9191 30
if [ $? -ne 0 ]; then
    echo "Error: Port 9191 (Glance Registry) not bounded!"
    exit $?
fi

wait_for_port 9292 30
if [ $? -ne 0 ]; then
    echo "Error: Port 9292 (Glance API) not bounded!"
    exit $?
fi

echo "======== Success :) ========="

if [[ "$1" != "noclean" ]]; then
    cleanup
fi
