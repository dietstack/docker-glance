FROM osmaster

MAINTAINER Kamil Madac (kamil.madac@t-systems.sk)

ENV http_proxy="http://172.27.10.114:3128"
ENV https_proxy="http://172.27.10.114:3128"

# Source codes to download
ENV glance_repo="https://github.com/openstack/glance"
ENV glance_branch="stable/liberty"
ENV glance_commit=""

# Download glance source codes
RUN git clone $glance_repo --single-branch --branch $glance_branch; 

# Checkout commit, if it was defined above
RUN if [ ! -z $glance_commit ]; then cd glance && git checkout $glance_commit; fi

# Apply source code patches
RUN mkdir -p /patches
COPY patches/* /patches/
RUN /patches/patch.sh
