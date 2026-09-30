## OpenAI Agents API self-hosted environment

Prepares the VM to be the environment of [OpenAI Agents API](https://developers.openai.com/api/docs/guides/agents-api/environments/self-hosted)
sessions. OpenAI runs the agent; `codex exec-server` on the VM dials **out** to OpenAI to receive shell commands and
file edits. The VM needs no inbound port.

```
onctl up -n agent -a openai-agents/codex-executor.sh
```

The template installs Node.js and the Codex CLI (`@openai/codex@alpha`), creates `/workspace`, and adds two helpers
for the per-session part:

- **`codex-set-key`** saves the environment key to `/root/.codex-env` (mode 600). It reads the key from stdin, so the
  key never appears in a command line or a log. That's also why the key isn't a template variable.
- **`codex-connect <remote_url> <environment_id>`** starts the executor for one session as the systemd unit
  `codex-exec-server`. A new session replaces the previous one.

### Connect a session

1. Create an **environment key** on the [Agents tab](https://platform.openai.com/agents?tab=environments&environment_view=keys)
   of the OpenAI platform, in the same project as your application's key, with every other permission set to None.
   It can only connect environments.
2. On the VM, run `codex-set-key` and paste the key.
3. From your application, create a session with `environment: {type: "self_hosted", workspace_directory: "/workspace"}`
   using your application's key, which stays outside the VM.
4. On the VM, run `codex-connect` with the session's `environment.remote_url` and `environment.id`.
5. Send the session a task. The environment connects within seconds; follow the executor with
   `journalctl -u codex-exec-server -f`.

Debian and Ubuntu only. Use a separate VM per user or workload: agents that share a VM share its files and the key.

### Options

```
onctl up -n agent -a openai-agents/codex-executor.sh \
  -e CODEX_VERSION=0.161.0-alpha.4 \
  -e WORKSPACE=/srv/agent
```

`WORKSPACE` must match the session's `workspace_directory`.
