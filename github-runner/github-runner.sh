#!/bin/bash
set -ex

: "${GH_REPO:?GH_REPO (owner/repo) is required}"
: "${RUNNER_TOKEN:?RUNNER_TOKEN is required}"
RUNNER_LABELS="${RUNNER_LABELS:-onctl}"
RUNNER_USER=runner
RUNNER_HOME=/opt/actions-runner

apt-get update
apt-get install -y curl jq tar

if ! id "$RUNNER_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$RUNNER_USER"
fi
getent group docker >/dev/null 2>&1 && usermod -aG docker "$RUNNER_USER" || true

case "$(uname -m)" in
  x86_64) ARCH=x64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

VERSION=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name | ltrimstr("v")')
mkdir -p "$RUNNER_HOME"
curl -fsSL "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-${ARCH}-${VERSION}.tar.gz" | tar xz -C "$RUNNER_HOME"
chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_HOME"

sudo -u "$RUNNER_USER" "$RUNNER_HOME/config.sh" \
  --url "https://github.com/${GH_REPO}" \
  --token "$RUNNER_TOKEN" \
  --name "$(hostname)" \
  --labels "$RUNNER_LABELS" \
  --ephemeral \
  --unattended

cd "$RUNNER_HOME"
./svc.sh install "$RUNNER_USER"
./svc.sh start
