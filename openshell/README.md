## OpenShell gateway

Runs an [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) gateway on the VM. OpenShell is a runtime for AI
agents: each agent runs in a sandbox, and a policy decides which files, syscalls and network destinations it can
reach. Outbound connections are denied by default, and provider credentials never enter the sandbox.

```
onctl up -n openshell --image ubuntu-24.04 -a openshell/openshell.sh
```

The gateway runs from its published image (`ghcr.io/nvidia/openshell/gateway`) with Docker Compose, using the Docker
compute driver: each sandbox is a workload container with no network plus a supervisor container that makes the
approved connections for it. No KVM is needed, so any cloud VM works.

### Linux 6.2 or newer

`openshell-sandbox` needs Landlock ABI v3, which arrived in Linux 6.2. On an older kernel (Ubuntu 22.04 ships 5.15)
the gateway would start but every sandbox would fail, so the script stops early instead. Use Ubuntu 24.04 or another
image with a 6.2+ kernel.

### Connecting

The gateway listens on port 8080 and requires mTLS: only a client with the certificate the script generates can use
it. The script prints the commands to fetch that bundle and register the gateway with the
[`openshell` CLI](https://docs.nvidia.com/openshell/latest/about/installation):

```
vm=openshell
d=~/.config/openshell/gateways/$vm/mtls; mkdir -p "$d"
for f in ca.crt client/tls.crt client/tls.key; do
  onctl ssh $vm -- sudo cat /var/lib/openshell/tls/$f > "$d/$(basename $f)"
done
chmod 600 "$d"/*
openshell gateway add https://<public-ip>:8080 --remote root@<public-ip> --name $vm
openshell -g $vm sandbox create --name hello
openshell -g $vm sandbox exec -n hello -- uname -a
```

`gateway add` makes the new gateway the active one; `openshell gateway select` switches back.

Anyone with the client key can create sandboxes on the VM, so treat it like an SSH key. To keep the port closed
altogether, set `OPENSHELL_LISTEN=127.0.0.1` and reach the gateway through `onctl port-forward`.

### Options

```
onctl up -n openshell --image ubuntu-24.04 -a openshell/openshell.sh \
  -e OPENSHELL_VERSION=0.1.6 \
  -e OPENSHELL_PORT=8080 \
  -e OPENSHELL_SERVER_SAN=openshell.example.com,203.0.113.10
```

The image version is pinned; keep it the same as your CLI (`openshell --version`). Running the script again rewrites
`/opt/openshell/docker-compose.yml` and `gateway.toml` and restarts the gateway if they changed. The certificates, the
database and running sandboxes are kept, so `OPENSHELL_SERVER_SAN` only applies to the first run: to change it, delete
`/var/lib/openshell/tls` and fetch the new client bundle.
