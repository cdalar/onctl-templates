#!/bin/bash
set -ex

# install docker
curl https://templates.onctl.com/docker/docker.sh | bash

# install git and other dependencies
apt-get install -y git

# clone supabase and set up self-hosted instance
git clone --depth 1 https://github.com/supabase/supabase /opt/supabase
cd /opt/supabase/docker
cp .env.example .env

# pull latest images and start services
docker compose pull
docker compose up -d

echo "Supabase is starting up..."
echo "Studio (dashboard): http://$(curl -s ifconfig.me):3000"
echo "API Gateway:        http://$(curl -s ifconfig.me):8000"
echo "Default credentials are in /opt/supabase/docker/.env"
