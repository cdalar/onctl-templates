#!/bin/bash
# Installs ZeroClaw (https://github.com/zeroclaw-labs/zeroclaw) and
# configures one agent per llama.cpp server it finds on LLM_HOST, so
# `zeroclaw agent -a <alias>` works as soon as the script ends, with no
# API key. ZeroClaw's own setup (`zeroclaw quickstart`) needs a terminal,
# which a template doesn't have; this writes ~/.zeroclaw/config.toml
# instead.
#
# LLM_HOST defaults to the VM's default gateway: for a Firecracker VM
# that is the host itself, which is where a local model usually runs.
#
# The agents get an unrestricted risk profile: any command, any path, no
# approval prompts. The VM is the sandbox. Don't run this on a machine
# you care about.
set -euo pipefail

ZEROCLAW_VERSION=${ZEROCLAW_VERSION:-v0.8.5}
LLM_HOST=${LLM_HOST:-$(ip route show default | awk '{print $3; exit}')}
LLM_PORTS=${LLM_PORTS:-8080 8081}

asset="zeroclaw-$(uname -m)-unknown-linux-gnu.tar.gz"
base="https://github.com/zeroclaw-labs/zeroclaw/releases/download/$ZEROCLAW_VERSION"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$asset" "$base/$asset"
curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"
(cd "$tmp" && grep " $asset\$" SHA256SUMS | sha256sum -c - >/dev/null)
tar -xzf "$tmp/$asset" -C "$tmp" zeroclaw
install -m 755 "$tmp/zeroclaw" /usr/local/bin/zeroclaw

config=$HOME/.zeroclaw/config.toml
mkdir -p "$(dirname "$config")"
cat >"$config" <<'TOML'
schema_version = 3

[risk_profiles.default]
level = "full"
allowed_commands = ["*"]
forbidden_paths = []
workspace_only = false
block_high_risk_commands = false
require_approval_for_medium_risk = false
sandbox_enabled = false

[runtime_profiles.default]
agentic = true
max_actions_per_hour = 100000
shell_timeout_secs = 600
TOML

# One provider and one agent per port that answers. The alias is the
# model id's leading letters ("gemma-4-26B..." -> gemma), or m<port> when
# that is empty or already taken.
aliases=""
for port in $LLM_PORTS; do
  model=$(curl -fsS -m 5 "http://$LLM_HOST:$port/v1/models" 2>/dev/null |
    grep -oE '"id" *: *"[^"]+"' | head -n 1 | sed -E 's/.*"([^"]+)"$/\1/') || true
  if [ -z "$model" ]; then
    echo "no model server on $LLM_HOST:$port, skipped" >&2
    continue
  fi
  alias=$(printf '%s' "$model" | sed -E 's/[^a-zA-Z].*//' | tr '[:upper:]' '[:lower:]')
  case " $aliases " in
    *" $alias "*) alias="m$port" ;;
  esac
  [ -n "$alias" ] || alias="m$port"
  aliases="$aliases $alias"
  cat >>"$config" <<TOML

[providers.models.llamacpp.$alias]
uri = "http://$LLM_HOST:$port/v1"
model = "$model"
timeout_secs = 300

[agents.$alias]
model_provider = "llamacpp.$alias"
risk_profile = "default"
runtime_profile = "default"
TOML
  echo "agent $alias -> $model ($LLM_HOST:$port)"
done

zeroclaw --version
if [ -z "$aliases" ]; then
  echo "ZeroClaw is installed, but no model server answered on $LLM_HOST (ports: $LLM_PORTS)." >&2
  echo "Add a provider and an agent to $config before running zeroclaw agent." >&2
else
  echo "Try: zeroclaw agent -a $(echo "$aliases" | awk '{print $1}')"
fi
