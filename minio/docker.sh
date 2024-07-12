#!/bin/bash
# install docker
curl https://templates.onctl.com/docker/docker.sh | bash
useradd -m -G docker ubuntu

docker run -p 9000:9000 -p 9001:9001 minio/minio server /data --console-address ":9001"