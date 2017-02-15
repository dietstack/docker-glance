#!/bin/bash

RELEASE_REPO=172.27.9.130
. lib/functions.sh

# get osmaster docker image
get_docker_image_from_release osmaster http://${RELEASE_REPO}/docker-osmaster latest

# Universal build script for docker containers
# Git project name has to start with 'docker-'

# get name of app from the path
# /../../docker-app_name > app_name
APP_NAME=${PWD##*-}

# set version based on the git commit
VERSION=$(git describe --abbrev=7 --tags)

docker build $@ -t $APP_NAME:$VERSION .
docker tag $APP_NAME:$VERSION $APP_NAME:latest

