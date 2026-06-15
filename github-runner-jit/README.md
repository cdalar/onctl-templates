# GitHub Actions self-hosted runner (JIT config)

Registers an ephemeral self-hosted GitHub Actions runner on the VM using a
just-in-time (JIT) runner config — a single-use, pre-scoped credential
generated *before* the VM exists, so no registration token or other reusable
credential ever touches the VM. The runner picks up exactly one job, then
exits.

## generate JIT config + run vm

```
JIT_CONFIG=$(gh api -X POST repos/<owner>/<repo>/actions/runners/generate-jitconfig \
  -f name=runner-jit -F runner_group_id=1 \
  -f 'labels[]=self-hosted' -f 'labels[]=onctl' \
  -q .encoded_jit_config)
onctl up -n runner-jit -a github-runner-jit/github-runner-jit.sh -e JIT_CONFIG=$JIT_CONFIG
```

Generating the JIT config requires a token with `administration:write` on the
repo (classic PAT with `repo` scope, or fine-grained PAT with
Administration: Read & write).

`SKIP_DOCKER=1` (via `-e`) skips the docker install step.

## use it in a workflow

```yaml
jobs:
  build:
    runs-on: [self-hosted, onctl]
```

## cleanup

The runner process exits after one job — no `config.sh`, no systemd service,
no reusable credential left on the VM. Destroy the VM once it's done:

```
onctl destroy runner-jit
```
