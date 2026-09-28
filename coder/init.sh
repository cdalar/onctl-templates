#!/bin/bash
set -eo pipefail
# install docker
curl -fsSL https://templates.onctl.com/docker/docker.sh | bash
id -u ubuntu &>/dev/null || useradd -m -G docker ubuntu
curl -fsSL https://coder.com/install.sh | sh
# The coder user is created by the deb/rpm package; the standalone install has none.
if id -u coder &>/dev/null; then usermod -aG docker coder; fi

sudo systemctl enable --now coder
journalctl -u coder.service -b --no-pager
