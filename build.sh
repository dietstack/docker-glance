#!/bin/bash

version=$(git describe --abbrev=7 --tags)
docker build -t glance:$version .

