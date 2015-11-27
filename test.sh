#!/bin/bash
# Integration test for glance service
# Test runs mysql,memcached,keystone and glance container and checks whether glance is running on public and admin ports

GIT_REPO=172.27.10.10
RELEASE_REPO=172.27.9.130

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

wait_for_port() {
    local port="$1"
    local timeout=$2
    local counter=0
    echo "Wait till app is bound to port $port "
    while [[ $counter -lt $timeout ]]; do
        local counter=$[counter + 1]
        if [[ ! `ss -ntl4 | grep ":${port}"` ]]; then
            echo -n ". "
        else
            break
        fi
        sleep 1
    done

    if [[ $timeout -eq $counter ]]; then
        exit 1
    fi
}

get_docker_image_from_release() {
    local image_name=$1
    local http_image_repo_url=$2
    local version=$3

    if [[ "${version}" -eq "latest" ]]; then
        local version=$(wget -q -O - ${http_image_repo_url}/latest_tag.txt)
        echo "Remote latest version is ${version}."
    fi

    if [[ ! `docker images | grep -w ${image_name} | grep -w ${version}` ]]; then
        # docker image of requests version doesn't exists in local repository
        local http_image_url=${http_image_repo_url}/${image_name}:${version}.tgz
        echo "Getting ${image_name} from ${http_image_url} ..."
        if [[ ! `docker images | grep -w ${image_name}` ]]; then
            mkdir -p /tmp/${image_name}
            rm -f /tmp/${image_name}/*
            pushd /tmp/${image_name}
                wget ${http_image_url}
                image_file=$(ls -1t | head -n 1)
                gunzip ${image_file}
                unziped_image_file=$(ls -1t | head -n 1)
                docker load < ${unziped_image_file}
            popd
            rm -rf /tmp/${image_name}
        fi
    fi
}

cleanup

##### Download/Build containers

# run galera docker image
get_docker_image_from_release galera http://${RELEASE_REPO}/docker-galera latest

# run keystone image
get_docker_image_from_release keystone http://${RELEASE_REPO}/docker-keystone latest

# run keystone image
get_docker_image_from_release keystone http://${RELEASE_REPO}/docker-keystone latest

##### Start Containers

echo "Starting galera container ..."
GALERA_TAG=$(docker images | grep -w galera | head -n 1 | awk '{print $2}')
docker run -d --net=host -e INITIALIZE_CLUSTER=1 -e MYSQL_ROOT_PASS=veryS3cr3t -e WSREP_USER=wsrepuser -e WSREP_PASS=wsreppass -e DEBUG= --name galera galera:$GALERA_TAG

echo "Wait till galera is running ."
wait_for_port 3306 30

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name memcached memcached

# build glance container for current sources
./build

sleep 5

echo "Starting keystone container"
KEYSTONE_TAG=$(docker images | grep -w keystone | head -n 1 | awk '{print $2}')
docker run -d --net=host -e DEBUG= --name keystone keystone:$KEYSTONE_TAG

echo "Wait till keystone is running ."

wait_for_port 5000 30
if [ $? -ne 0 ]; then
    echo "Error: Port 5000 not bounded!"
    exit $?
fi

wait_for_port 35357 30
if [ $? -ne 0 ]; then
    echo "Error: Port 5000 not bounded!"
    exit $?
fi

echo "Starting glance container"
GLANCE_TAG=$(docker images | grep -w glance | head -n 1 | awk '{print $2}')
docker run -d --net=host -e DEBUG= -e DB_SYNC= --name glance glance:$GLANCE_TAG

cleanup
