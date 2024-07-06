#!/bin/bash
# install docker
curl https://templates.onctl.com/docker/docker.sh | bash
useradd -m -G docker ubuntu

docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main

