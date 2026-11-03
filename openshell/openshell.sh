#!/bin/bash
# Runs an NVIDIA OpenShell gateway (https://github.com/NVIDIA/OpenShell) on
# the VM, from its published container image, with the Docker compute
# driver: each OpenShell sandbox is a pair of containers on this VM.
#
# The gateway requires mTLS: only a client holding the certificate this
# script generates can use it. That bundle is in OPENSHELL_HOME/tls/client
# and OPENSHELL_HOME/tls/ca.crt; the script prints how to fetch it.
#
# The gateway uses the host's network, so it listens on OPENSHELL_LISTEN
# directly, and the per-sandbox supervisors (also on the host network) reach
# it on 127.0.0.1.
set -euo pipefail

OPENSHELL_VERSION=${OPENSHELL_VERSION:-0.1.6}
OPENSHELL_HOME=${OPENSHELL_HOME:-/var/lib/openshell}
OPENSHELL_PORT=${OPENSHELL_PORT:-8080}
OPENSHELL_LISTEN=${OPENSHELL_LISTEN:-0.0.0.0}
OPENSHELL_SERVER_SAN=${OPENSHELL_SERVER_SAN:-${PUBLIC_IP:-}}
OPENSHELL_DEFAULT_IMAGE=${OPENSHELL_DEFAULT_IMAGE:-nvcr.io/nvidia/base/ubuntu:24.04}

if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

# openshell-sandbox refuses to start below Landlock ABI v3, which arrived in
# Linux 6.2; the gateway would come up and every sandbox would then fail.
# Ubuntu 22.04's 5.15 kernel is too old; 24.04 (6.8) works.
kernel=$(uname -r)
IFS=. read -r major minor _ <<<"$kernel"
if [ "$major" -lt 6 ] || { [ "$major" -eq 6 ] && [ "${minor%%[!0-9]*}" -lt 2 ]; }; then
  echo "OpenShell sandboxes need Linux 6.2 or newer (Landlock ABI v3); this VM runs $kernel." >&2
  echo "Use a newer image, e.g. Ubuntu 24.04." >&2
  exit 1
fi
if ! grep -qw landlock /sys/kernel/security/lsm 2>/dev/null; then
  echo "Landlock is not enabled in this kernel's LSM list ($(cat /sys/kernel/security/lsm 2>/dev/null)); OpenShell sandboxes need it." >&2
  exit 1
fi

# get.docker.com rather than docker/docker.sh: that one only knows Ubuntu.
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

registry=ghcr.io/nvidia/openshell
compose_dir=/opt/openshell
mkdir -p "$compose_dir" "$OPENSHELL_HOME"

# generate-certs keeps what is already in the output directory, so a rerun
# leaves the CA, the server certificate and the client bundle alone.
san_args=()
for san in ${OPENSHELL_SERVER_SAN//,/ }; do
  san_args+=(--server-san "$san")
done
if [ ! -f "$OPENSHELL_HOME/tls/ca.crt" ] && [ ${#san_args[@]} -eq 0 ]; then
  echo "No address to put in the server certificate: set OPENSHELL_SERVER_SAN (onctl sets PUBLIC_IP)." >&2
  exit 1
fi

cat >"$compose_dir/gateway.toml" <<EOF
# Written by onctl-templates openshell/openshell.sh; rerunning it overwrites this.
[openshell]
version = 2

[openshell.gateway]
bind_address        = "$OPENSHELL_LISTEN:$OPENSHELL_PORT"
health_bind_address = "127.0.0.1:$((OPENSHELL_PORT + 1))"
log_level           = "info"
compute_driver      = "docker"

[openshell.gateway.gateway_jwt]
signing_key_path = "$OPENSHELL_HOME/tls/jwt/signing.pem"
public_key_path  = "$OPENSHELL_HOME/tls/jwt/public.pem"
kid_path         = "$OPENSHELL_HOME/tls/jwt/kid"
gateway_id       = "openshell-onctl"

[openshell.drivers.docker]
grpc_endpoint         = "https://127.0.0.1:$OPENSHELL_PORT"
default_image         = "$OPENSHELL_DEFAULT_IMAGE"
sandbox_runtime_image = "$registry/sandbox:$OPENSHELL_VERSION"
supervisor_image      = "$registry/supervisor:$OPENSHELL_VERSION"
image_pull_policy     = "if_not_present"
sandbox_label         = "openshell"
app_armor_profile     = "Unconfined"
EOF

# OPENSHELL_HOME is bind-mounted at the same path inside the container: the
# gateway hands paths under it to the host's Docker daemon as bind-mount
# sources for the sandbox containers.
cat >"$compose_dir/docker-compose.yml" <<EOF
# Written by onctl-templates openshell/openshell.sh; rerunning it overwrites this.
services:
  init:
    image: $registry/gateway:$OPENSHELL_VERSION
    user: "0"
    restart: "no"
    command: ["generate-certs", "--output-dir", "$OPENSHELL_HOME/tls"$(printf ', "%s"' "${san_args[@]}")]
    environment:
      HOME: $OPENSHELL_HOME
    volumes:
      - $OPENSHELL_HOME:$OPENSHELL_HOME

  gateway:
    image: $registry/gateway:$OPENSHELL_VERSION
    restart: unless-stopped
    depends_on:
      init:
        condition: service_completed_successfully
    command: []
    user: "0"
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $OPENSHELL_HOME:$OPENSHELL_HOME
      - $compose_dir/gateway.toml:/etc/openshell/gateway.toml:ro
    environment:
      OPENSHELL_GATEWAY_CONFIG: /etc/openshell/gateway.toml
      OPENSHELL_LOCAL_TLS_DIR: $OPENSHELL_HOME/tls
      OPENSHELL_DB_URL: "sqlite:$OPENSHELL_HOME/gateway.db?mode=rwc"
      XDG_DATA_HOME: $OPENSHELL_HOME
      HOME: $OPENSHELL_HOME
EOF

docker compose -f "$compose_dir/docker-compose.yml" up -d

health="http://127.0.0.1:$((OPENSHELL_PORT + 1))/readyz"
for _ in $(seq 60); do
  if curl -fs -o /dev/null "$health"; then
    address=${PUBLIC_IP:-$(hostname -I | awk '{print $1}')}
    tls=$OPENSHELL_HOME/tls
    # `gateway add --remote` takes the SSH destination of the gateway host.
    ssh_user=${SUDO_USER:-$(id -un)}
    cat <<EOF
OpenShell gateway $OPENSHELL_VERSION: https://$address:$OPENSHELL_PORT (mTLS)

Client bundle, on this VM: $tls/ca.crt $tls/client/tls.crt $tls/client/tls.key
To use it from your machine with the openshell CLI (replace <vm> with the VM's onctl name):

  d=~/.config/openshell/gateways/<vm>/mtls; mkdir -p "\$d"
  for f in ca.crt client/tls.crt client/tls.key; do
    onctl ssh <vm> -- sudo cat $tls/\$f > "\$d/\$(basename \$f)"
  done
  chmod 600 "\$d"/*
  openshell gateway add https://$address:$OPENSHELL_PORT --remote $ssh_user@$address --name <vm>
  openshell -g <vm> status
  openshell -g <vm> sandbox create --name hello
EOF
    exit 0
  fi
  sleep 2
done

echo "The OpenShell gateway did not become ready within 2 minutes." >&2
docker compose -f "$compose_dir/docker-compose.yml" logs --tail 80 >&2
exit 1
