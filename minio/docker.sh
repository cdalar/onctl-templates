#!/bin/bash
set -eo pipefail
# install docker
curl -fsSL https://templates.onctl.com/docker/docker.sh | bash
id -u ubuntu &>/dev/null || useradd -m -G docker ubuntu

docker run -d --name minio --restart always -p 9000:9000 -p 9001:9001 minio/minio server /data --console-address ":9001"