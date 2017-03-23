FROM osmaster

MAINTAINER Kamil Madac (kamil.madac@t-systems.sk)

# Source codes to download
ENV repo="https://github.com/openstack/glance" branch="stable/newton" commit=""

# Download source codes
RUN if [ -z $commit ]; then \
       git clone $repo --single-branch --depth=1 --branch $branch; \
    else \
       git clone $repo --single-branch --branch $branch; \
       cd glance && git checkout $commit; \
    fi

# Apply source code patches
RUN mkdir -p /patches
COPY patches/* /patches/
RUN if [ -f /patches/patch.sh ]; then /patches/patch.sh; fi

# Install glance with dependencies
RUN cd glance; pip install -r requirements.txt -c /requirements/upper-constraints.txt; pip install supervisor python-memcached; python setup.py install

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
