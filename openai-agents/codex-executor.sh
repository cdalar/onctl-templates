#!/bin/bash
# Prepares the VM to be the self-hosted environment of OpenAI Agents API
# sessions: installs Node.js and the Codex CLI, creates the agent's
# working directory, and installs two helpers for the per-session part.
#
#   codex-set-key   reads the environment key on stdin and saves it to
#                   /root/.codex-env (mode 600). Stdin, not an argument
#                   or an -e variable, so the key never lands in a
#                   command line or a log.
#   codex-connect <remote_url> <environment_id>
#                   starts `codex exec-server` for one session as the
#                   systemd unit codex-exec-server, which dials out to
#                   OpenAI. No inbound port is needed.
#
# Debian/Ubuntu only (apt).
set -euo pipefail

WORKSPACE=${WORKSPACE:-/workspace}
CODEX_VERSION=${CODEX_VERSION:-alpha}
export DEBIAN_FRONTEND=noninteractive
# A locale every image has: ssh passes the client's LANG, which the image
# may not have generated, and apt's perl then warns about it at length.
export LC_ALL=C.UTF-8

if ! command -v apt-get >/dev/null; then
  echo "codex-executor.sh supports Debian/Ubuntu (apt) only" >&2
  exit 1
fi

# The distro's nodejs is enough: the Codex CLI needs Node >= 16.
if ! command -v npm >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 16 ]; then
  apt-get update -qq
  apt-get install -y -qq nodejs npm >/dev/null
fi
npm install -g --silent "@openai/codex@${CODEX_VERSION}"
mkdir -p "$WORKSPACE"

cat >/usr/local/bin/codex-set-key <<'EOF'
#!/bin/bash
# Usage: codex-set-key   (then paste the environment key and press Enter)
#    or: <something that prints the key> | codex-set-key
set -euo pipefail
umask 077
if [ -t 0 ]; then
  IFS= read -rs -p "Environment key: " key
  echo
else
  IFS= read -r key
fi
[ -n "$key" ] || { echo "no key given" >&2; exit 1; }
printf 'CODEX_API_KEY=%s\n' "$key" >/root/.codex-env
echo "saved to /root/.codex-env"
EOF

cat >/usr/local/bin/codex-connect <<EOF
#!/bin/bash
# Usage: codex-connect <remote_url> <environment_id>
# Values are the session's environment.remote_url and environment.id.
set -euo pipefail
if [ \$# -ne 2 ]; then
  echo "usage: codex-connect <remote_url> <environment_id>" >&2
  exit 2
fi
if [ ! -s /root/.codex-env ]; then
  echo "no environment key yet: run codex-set-key first" >&2
  exit 1
fi
# One executor per VM: a new session replaces the previous one.
systemctl stop codex-exec-server 2>/dev/null || true
systemctl reset-failed codex-exec-server 2>/dev/null || true
systemd-run --quiet --unit=codex-exec-server --working-directory=${WORKSPACE} \\
  --property=EnvironmentFile=/root/.codex-env \\
  "\$(command -v codex)" exec-server --remote "\$1" --environment-id "\$2"
echo "codex-exec-server started (logs: journalctl -u codex-exec-server)"
EOF
chmod 755 /usr/local/bin/codex-set-key /usr/local/bin/codex-connect

# A real check: npm installs the Codex wrapper without its platform
# binary, silently, when @alpha points at a release whose Linux build
# isn't on npm yet -- and only running it shows that. An assignment,
# because set -e ignores a failing $(...) inside a command's arguments.
codex_version=$(codex --version)
echo "${codex_version} ready, workspace ${WORKSPACE}"
echo "Next: codex-set-key, then codex-connect <remote_url> <environment_id>"
