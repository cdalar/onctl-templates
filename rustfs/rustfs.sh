#!/bin/bash
set -euo pipefail

RUSTFS_VERSION=${RUSTFS_VERSION:-latest}
DATA_DIR=${DATA_DIR:-/opt/rustfs/data}
LOG_DIR=${LOG_DIR:-/opt/rustfs/logs}

install_docker() {
  echo "Installing Docker..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    install_docker
  fi
}

prepare_directories() {
  mkdir -p "$DATA_DIR" "$LOG_DIR"
  chown -R 10001:10001 "$DATA_DIR" "$LOG_DIR"
}

start_rustfs() {
  if docker ps -a --format '{{.Names}}' | grep -q '^rustfs$'; then
    echo "Existing rustfs container found. Restarting with current configuration."
    docker rm -f rustfs >/dev/null 2>&1 || true
  fi

  docker run -d \
    --name rustfs \
    -p 9000:9000 \
    -p 9001:9001 \
    -v "$DATA_DIR:/data" \
    -v "$LOG_DIR:/logs" \
    --restart unless-stopped \
    rustfs/rustfs:"$RUSTFS_VERSION"
}

main() {
  ensure_docker
  prepare_directories
  start_rustfs
}

main "$@"
