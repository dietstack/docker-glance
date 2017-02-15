FROM osmaster

MAINTAINER Kamil Madac (kamil.madac@t-systems.sk)

ENV http_proxy="http://172.27.10.114:3128"
ENV https_proxy="http://172.27.10.114:3128"
ENV no_proxy="127.0.0.1,localhost"

# Source codes to download
ENV glance_repo="https://github.com/openstack/glance"
ENV glance_branch="stable/newton"
ENV glance_commit=""

# Download glance source codes
RUN git clone $glance_repo --depth=1 --single-branch --branch $glance_branch;

# Checkout commit, if it was defined above
RUN if [ ! -z $glance_commit ]; then cd glance && git checkout $glance_commit; fi

# Apply source code patches
RUN mkdir -p /patches
COPY patches/* /patches/
RUN if [ -f /patches/patch.sh ]; then /patches/patch.sh; fi

# Install glance with dependencies
RUN cd glance; pip install -r requirements.txt; pip install supervisor mysql-python python-memcached; python setup.py install

# prepare directories for storing image files and copy configs
RUN mkdir -p /var/lib/glance/images /etc/glance /etc/supervisord /var/log/supervisord; cp -a /glance/etc/* /etc/glance

# copy supervisor config
COPY configs/supervisord/supervisord.conf /etc

# copy keystone configs
COPY configs/glance/* /etc/glance/

# external volume
VOLUME /glance-override

# copy startup scripts
COPY scripts /app

# Define workdir
WORKDIR /app
RUN chmod +x /app/*

ENTRYPOINT ["/app/entrypoint.sh"]

# Define default command.
CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
