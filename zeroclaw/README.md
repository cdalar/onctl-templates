## ZeroClaw with a local model

Installs [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw), a single-binary AI agent runtime, and points it at the
llama.cpp servers (`llama-server`) running on the VM's host. ZeroClaw ships no model of its own; this gives it one
without an API key.

```
onctl up -n claw -a zeroclaw/zeroclaw.sh
```

The script downloads the release, checks it against the release's `SHA256SUMS`, and installs `/usr/local/bin/zeroclaw`.
It then asks each port in `LLM_PORTS` on `LLM_HOST` which model it serves (`GET /v1/models`) and writes one provider and
one agent per answer to `~/.zeroclaw/config.toml`. An agent is named after its model's leading letters: a server
with `gemma-4-26B-A4B-it-Q8_0` becomes the agent `gemma`.

```
zeroclaw agent -a gemma                      # interactive
zeroclaw agent -a gemma -m "what is in /etc/os-release?"
```

To use another model, start the other agent: there is no switching inside a session, and each agent keeps its own
workspace and memory. Small models (a few billion parameters) answer, but handle ZeroClaw's tool list poorly.

`LLM_HOST` defaults to the VM's default gateway. For a Firecracker VM that is the host, so a `llama-server` listening
on the host's bridge address (or `0.0.0.0`) is found as is. On a cloud VM, set `LLM_HOST` to wherever the model runs.
If nothing answers, ZeroClaw is still installed and the script says which ports it tried.

### The agents are unrestricted

The risk profile this writes allows any command on any path, with no approval prompts: the VM is the sandbox. Use a
VM you can throw away, and keep credentials you care about off it. To tighten it, edit `[risk_profiles.default]` in
`~/.zeroclaw/config.toml`; ZeroClaw's own default is `level = "supervised"` with a command allowlist.

Running the script again overwrites `config.toml`.

### Options

```
onctl up -n claw -a zeroclaw/zeroclaw.sh \
  -e ZEROCLAW_VERSION=v0.8.5 \
  -e LLM_HOST=192.168.1.20 \
  -e LLM_PORTS="8080 11434"
```

The version is pinned by default because the config format is tied to it (`schema_version = 3`). x86_64 and aarch64
Linux with glibc.
