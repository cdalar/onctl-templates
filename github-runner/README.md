# GitHub Actions self-hosted runner

Registers an ephemeral self-hosted GitHub Actions runner on the VM. The runner
picks up exactly one job, then deregisters itself.

## run vm + install docker + register runner

```
TOKEN=$(gh api -X POST repos/<owner>/<repo>/actions/runners/registration-token -q .token)
onctl up -n runner -a docker/docker.sh -a github-runner/github-runner.sh \
  -e GH_REPO=<owner>/<repo> -e RUNNER_TOKEN=$TOKEN
```

Registration tokens expire after 1 hour — generate one right before `onctl up`.

## use it in a workflow

```yaml
jobs:
  build:
    runs-on: [self-hosted, onctl]
```

Set `RUNNER_LABELS` (default `onctl`) to add custom comma-separated labels.

## cleanup

The runner deregisters itself after one job. Destroy the VM once it's done:

```
onctl destroy runner
```
