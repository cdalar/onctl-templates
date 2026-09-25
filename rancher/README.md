## Rancher management (local) cluster on k3s

Creates a single-node k3s cluster and installs cert-manager and Rancher on it, so the VM becomes a Rancher
management ("local") cluster that you can import or provision downstream clusters from.

```
onctl up -n rancher -a rancher/rancher-local.sh --download /root/rancher-info.txt
cat rancher-info.txt
```

`rancher-info.txt` contains the Rancher URL and the bootstrap password for the first login. You can also see it
later with `onctl ssh rancher` and `cat /root/rancher-info.txt`.

With no variables set, the template uses these defaults:

- **URL:** `https://rancher.<public-ip-with-dashes>.sslip.io/`. [sslip.io](https://sslip.io) resolves that name to
  the VM's IP, so you don't need a DNS record. Rancher requires a hostname and always serves its UI over HTTPS.
- **Certificate:** self-signed, issued by cert-manager. Accept the browser warning.
- **Rancher:** the latest version from the `rancher-stable` chart repo, with 1 replica.
- **Bootstrap password:** random, saved to `/root/rancher-bootstrap-password`. Rancher asks you to change it at
  first login.

Use a VM with at least 2 vCPU and 4 GB of RAM (tested on Hetzner `ccx13`, 2 vCPU / 8 GB; ready in about 3 minutes).

### Options

```
onctl up -n rancher -a rancher/rancher-local.sh \
  -e RANCHER_HOSTNAME=rancher.example.com \
  -e RANCHER_VERSION=2.15.2 \
  -e BOOTSTRAP_PASSWORD=change-me-now \
  -e K3S_VERSION=v1.35.4+k3s1
```

| Variable | Default | Description |
|---|---|---|
| `RANCHER_HOSTNAME` | `rancher.<ip>.sslip.io` | Hostname for the Rancher UI; point its DNS record at the VM if you change it |
| `RANCHER_VERSION` | latest stable | Rancher chart version |
| `RANCHER_REPLICAS` | `1` | Rancher server replicas |
| `BOOTSTRAP_PASSWORD` | random | Password for the first admin login |
| `CERT_MANAGER_VERSION` | latest | cert-manager chart version |
| `K3S_VERSION` | k3s stable channel | k3s version; must be supported by the Rancher version |

If the Rancher install fails with an incompatible `kubeVersion`, the latest k3s is newer than the Rancher release
supports. Set `K3S_VERSION` to a supported version.

### Kubeconfig

```
onctl up -n rancher -a rancher/rancher-local.sh --download /tmp/k3s.yaml
kubectl --kubeconfig k3s.yaml get po -A
```

The k3s token for adding nodes is in `/tmp/token`. Join nodes with `k3s/k3s-agent.sh`, as described in the
[k3s README](../k3s/README.md).
