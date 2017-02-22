#!/bin/bash

pushd /glance && patch < /patches/bug-1657459.patch; popd
