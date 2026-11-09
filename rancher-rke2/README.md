## Rancher on RKE2, behind a TLS proxy (boxctl.io)

Installs single-node RKE2 and Rancher on it, for a VM that is reached through a proxy that terminates TLS and
sends plain HTTP to port 80, such as a [boxctl.io](https://boxctl.io) public URL. Rancher answers on port 80 for
any hostname, so the address doesn't have to exist yet when the VM boots. For a VM with its own public IP, use
[`rancher`](../rancher/README.md) instead, which serves HTTPS itself.

### On boxctl.io

1. Boot a **large** box with this template. Rancher needs the memory, and the smaller sizes' 10 GiB disk fills
   up with its images. The install takes about 5-10 minutes; the box shows the template as still applying until
   it is done.
2. Make **port 80** public: the dashboard's **Public URLs** tab, or `boxctl expose <box> 80`. It is the only port
   to expose: 443 and 6443 speak TLS themselves and can't go through a public URL.
3. Get the bootstrap password in the box's terminal:

   ```
   cat /root/rancher-info.txt
   ```

4. Open the public URL (`https://<label>.boxctl.app`), sign in with the bootstrap password, set a new one, and
   check that the **Server URL** Rancher offers is that public URL. Downstream clusters register against it.

To add a downstream cluster on another box, install `iptables` there first (`apt-get install -y iptables`;
RKE2's CNI needs it), then run the registration command Rancher shows. The node connects out to Rancher through
the public URL, so its own ports don't need to be public.

Anyone with the link reaches the sign-in page, so the password is what protects Rancher. Keep the public URL:
removing it retires the hostname, and Rancher's Server URL with it. For `kubectl` from your own machine, use
`boxctl port-forward <box> 6443` with `/tmp/rke2.yaml` from the box.

### Elsewhere

```
onctl up -n rancher -a rancher-rke2/rancher-rke2.sh -e RANCHER_HOSTNAME=rancher.example.com
```

Point the proxy or load balancer at the VM's port 80, and have it set `X-Forwarded-Proto: https`. Its certificate
must be publicly trusted: downstream nodes check it against their system trust store.

| Variable | Default | Description |
|---|---|---|
| `RANCHER_HOSTNAME` | unset | The address users open. Unset, Rancher is served on every hostname |
| `RANCHER_VERSION` | latest stable | Rancher chart version |
| `BOOTSTRAP_PASSWORD` | random | Password for the first admin login, saved to `/root/rancher-bootstrap-password` |
| `RKE2_VERSION` | RKE2 stable channel | RKE2 version; must be supported by the Rancher version |

### What the script does

- Installs `iptables` if it's missing (RKE2's CNI needs it), then RKE2.
- Sets RKE2's ingress controller (Traefik, or ingress-nginx on older RKE2) to trust the proxy's
  `X-Forwarded-Proto` header, so Rancher knows it is reached over HTTPS.
- Installs Rancher with `tls=external` (no cert-manager) and `agentTLSMode=system-store`, so downstream nodes
  check the proxy's certificate against their system trust store instead of a Rancher CA that doesn't exist.
- Without `RANCHER_HOSTNAME`, adds an Ingress `rancher-any-host` that sends every hostname to Rancher.

If the install fails with an incompatible `kubeVersion`, the RKE2 stable channel is newer than the Rancher
release supports. Set `RKE2_VERSION` to a supported version.
