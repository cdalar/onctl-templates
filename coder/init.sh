#!/bin/bash
# install docker
curl https://templates.onctl.com/docker/docker.sh | bash
useradd -m -G docker ubuntu
usermod -aG docker coder
curl -L https://coder.com/install.sh | sh

sudo systemctl enable --now coder
journalctl -u coder.service -b
