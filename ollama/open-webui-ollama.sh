#!/bin/bash
set -eo pipefail
# install docker
curl -fsSL https://templates.onctl.com/docker/docker.sh | bash

docker run -d -p 3000:8080 -v ollama:/root/.ollama -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:ollama
for _ in $(seq 30); do docker exec open-webui ollama list &>/dev/null && break; sleep 2; done
docker exec open-webui ollama pull llama3