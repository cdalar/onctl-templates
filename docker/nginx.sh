#!/bin/bash
# docker login -u $DOCKER_USER -p $DOCKER_PASS
docker run -d -p 80:80 --name onctl-nginx-sample nginx:stable-alpine3.17-slim