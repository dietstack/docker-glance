#!/bin/bash
# Integration test for glance service
# Test runs mysql,memcached,keystone and glance container and checks whether glance is running on public and admin ports

GIT_REPO=172.27.10.10
RELEASE_REPO=172.27.9.130
CONT_PREFIX=test

. lib/functions.sh

cleanup() {
    echo "Clean up ..."

    docker stop ${CONT_PREFIX}_galera
    docker stop ${CONT_PREFIX}_memcached
    docker stop ${CONT_PREFIX}_keystone
    docker stop ${CONT_PREFIX}_glance

    docker rm ${CONT_PREFIX}_galera
    docker rm ${CONT_PREFIX}_memcached
    docker rm ${CONT_PREFIX}_keystone
    docker rm ${CONT_PREFIX}_glance
}


. lib/functions.sh

cleanup() {
    echo "Clean up ..."
    docker stop ${CONT_PREFIX}_galera
    docker stop ${CONT_PREFIX}_memcached
    docker stop ${CONT_PREFIX}_keystone
    docker stop ${CONT_PREFIX}_glance

    docker rm ${CONT_PREFIX}_galera
    docker rm ${CONT_PREFIX}_memcached
    docker rm ${CONT_PREFIX}_keystone
    docker rm ${CONT_PREFIX}_glance
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
docker run -d --net=host -e INITIALIZE_CLUSTER=1 -e MYSQL_ROOT_PASS=veryS3cr3t -e WSREP_USER=wsrepuser -e WSREP_PASS=wsreppass -e DEBUG= --name ${CONT_PREFIX}_galera galera:latest

echo "Wait till galera is running ."
wait_for_port 3306 30

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_memcached memcached

# build glance container for current sources
./build.sh

sleep 10

# create databases
create_db_osadmin keystone keystone veryS3cr3t veryS3cr3t
create_db_osadmin glance glance veryS3cr3t veryS3cr3t

echo "Starting keystone container"
docker run -d --net=host -e DEBUG="true" -e DB_SYNC="true" --name ${CONT_PREFIX}_keystone keystone:latest

echo "Wait till keystone is running ."

wait_for_port 5000 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 5000 (Keystone) not bounded!"
    exit $ret
fi

wait_for_port 35357 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 35357 (Keystone Admin) not bounded!"
    exit $ret
fi

echo "Starting glance container"
GLANCE_TAG=$(docker images | grep -w glance | head -n 1 | awk '{print $2}')
docker run -d --net=host -e DEBUG="true" -e DB_SYNC="true" --name ${CONT_PREFIX}_glance glance:$GLANCE_TAG

##### TESTS #####

wait_for_port 9191 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 9191 (Glance Registry) not bounded!"
    exit $ret
fi

wait_for_port 9292 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 9292 (Glance API) not bounded!"
    exit $ret
fi

echo "Return code $?"

# bootstrap openstack settings and upload image to glance
docker run --net=host osadmin /bin/bash -c ". /app/adminrc; bash /app/bootstrap.sh"
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Keystone bootstrap error ${ret}!"
    exit $ret
fi

docker run --net=host osadmin /bin/bash -c ". /app/userrc; openstack image create --container-format bare --disk-format qcow2 --file /app/cirros.img --public cirros"
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Cirros image import error ${ret}!"
    exit $ret
fi

echo "======== Success :) ========="

if [[ "$1" != "noclean" ]]; then
    cleanup
fi
