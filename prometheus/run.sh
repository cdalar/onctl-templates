#!/bin/bash 
onctl up -n prometheus \
    -u prometheus.yml \
    -u docker-compose.yml \
    -a docker/docker.sh \
    -a prometheus.sh
