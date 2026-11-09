## Rancher management (local) cluster on k3s or RKE2

Creates a single-node k3s cluster and installs cert-manager and Rancher on it, so the VM becomes a Rancher
management ("local") cluster that you can import or provision downstream clusters from. If the VM already runs
RKE2 or k3s (for example from [`rke2/rke2.sh`](../rke2/README.md)), that cluster is used instead of installing k3s.

### On boxctl.io

This template's defaults don't fit a boxctl box: it has no public IP, and its public URL
(`https://<label>.boxctl.app`) terminates TLS and sends plain HTTP to the port you make public. For a clean
install, boot the box with the **[`rancher-rke2`](../rancher-rke2/README.md)** template instead. It serves Rancher
on port 80 for whatever public URL you give it.

On a box that already runs RKE2 or k3s (for example one booted with this template, or with `rke2`), make
**port 80** public, then run this script again in the box's terminal, as root, with that URL's hostname:

```
curl -fsSLO https://templates.onctl.com/rancher/rancher-local.sh
RANCHER_HOSTNAME=<label>.boxctl.app RANCHER_TLS=external \
  BOOTSTRAP_PASSWORD='<a strong password>' bash rancher-local.sh
```

It reuses the cluster that's there and switches Rancher to the public URL. Then open
`https://<label>.boxctl.app` and sign in with the bootstrap password (also in `/root/rancher-info.txt`).

### On a VM with a public IP

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
| `RANCHER_TLS` | `ingress` | `ingress`: Rancher serves HTTPS on 443 with a self-signed certificate. `external`: TLS ends in front of the VM and Rancher serves HTTP on 80 (see below) |
| `CERT_MANAGER_VERSION` | latest | cert-manager chart version (`RANCHER_TLS=ingress` only) |
| `K3S_VERSION` | k3s stable channel | k3s version; must be supported by the Rancher version. Ignored when the VM already runs RKE2 or k3s |

If the Rancher install fails with an incompatible `kubeVersion`, the latest k3s is newer than the Rancher release
supports. Set `K3S_VERSION` to a supported version.

### TLS in front of the VM (`RANCHER_TLS=external`)

When a load balancer or proxy terminates TLS and forwards plain HTTP to the VM's port 80, set
`RANCHER_TLS=external` and `RANCHER_HOSTNAME` to the name users open. cert-manager is not installed, and the
cluster's ingress controller (Traefik, or RKE2's ingress-nginx) is set to trust the `X-Forwarded-Proto: https`
header the proxy sends, so Rancher knows it is reached over HTTPS. A boxctl public URL is this case; see
[On boxctl.io](#on-boxctlio).

### Kubeconfig

```
onctl up -n rancher -a rancher/rancher-local.sh --download /tmp/k3s.yaml
kubectl --kubeconfig k3s.yaml get po -A
```

On RKE2 the copy is `/tmp/rke2.yaml`.

The k3s token for adding nodes is in `/tmp/token`. Join nodes with `k3s/k3s-agent.sh`, as described in the
[k3s README](../k3s/README.md).
