# Ready to Use Templates for onctl 

[**onctl**](https://github.com/cdalar/onctl) is a unified CLI tool for provisioning and managing virtual machines across multiple cloud providers and local environments — six ways to boot a VM, one command.

Check 🌍 https://onctl.sh for detailed documentation, or install it directly:

```bash
curl -fsSL https://onctl.sh/get.sh | bash
```

[![Github All Releases](https://img.shields.io/github/downloads/cdalar/onctl/total.svg)]()
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/cdalar/onctl?sort=semver)
<!-- [![Known Vulnerabilities](https://snyk.io/test/github/cdalar/onctl/main/badge.svg)](https://snyk.io/test/github/cdalar/onctl/main) -->

## What onctl brings 

- 🌍 Simple intuitive CLI to run VMs in seconds.  
- ⛅️ Supports multi cloud providers (aws, azure, gcp, hetzner, more coming soon...) plus local microVMs via Firecracker
- 🚀 Sets your public key and Gives you SSH access with `onctl ssh <vm-name>`
- ✨ Cloud-init support. Set your own cloud-init file `onctl up -n qwe --cloud-init <cloud.init.file>`
- 🤖 Use ready to use templates to configure your vm. Check [onctl-templates](https://github.com/cdalar/onctl-templates) `onctl up -n qwe -a k3s/k3s-server.sh`
- 🗂️ Use your custom local or http accessible scripts to configure your vm. `onctl ssh qwe -a <my_local_script.sh>`

## Adding a template

1. Create a top-level directory with your script(s).
2. Add a `template.yaml` next to them:

   ```yaml
   description: Installs Foo on the VM.
   tags: [foo, database]
   entrypoint: foo.sh          # what `onctl up -a foo/foo.sh` runs
   env:                        # variables the script reads (PUBLIC_IP is always set by onctl)
     - name: FOO_PASSWORD
       required: true
       description: Admin password.
   usage:                      # optional: what to run on the VM once the script has finished
     - command: foo status
       description: Check that Foo is up.
   files:                      # every other script in the directory must be listed
     - path: foo-agent.sh
       description: Joins an existing Foo server.
   ```

   The full schema is in [`.github/scripts/manifest.py`](.github/scripts/manifest.py).
3. Open a PR. CI validates the manifest and builds the site. On merge, [`index.yaml`](https://templates.onctl.com/index.yaml) is generated and deployed; it isn't committed.

   To preview it locally: `python3 .github/scripts/generate_index.py && onctl templates list -f index.yaml`
