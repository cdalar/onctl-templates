#!/bin/bash
set -eo pipefail
sudo apt-get update && sudo apt-get install nginx -y

sudo systemctl enable nginx
sudo systemctl start nginx
