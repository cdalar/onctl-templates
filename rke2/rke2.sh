#!/bin/bash
set -eo pipefail

# RKE2's CNI plugins (portmap) run iptables from the host's PATH. Images
# without it, such as boxctl's, leave every pod stuck in
# FailedCreatePodSandBox: 'exec: "iptables": executable file not found'.
if ! command -v iptables &>/dev/null; then
    if command -v apt-get &>/dev/null; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y iptables
    elif command -v dnf &>/dev/null; then
        dnf install -y iptables
    elif command -v yum &>/dev/null; then
        yum install -y iptables
    elif command -v apk &>/dev/null; then
        apk add --no-cache iptables
    else
        echo "iptables is missing and no known package manager was found; install it first." >&2
        exit 1
    fi
fi

curl -sfL https://get.rke2.io | sh -

systemctl enable rke2-server.service
systemctl start rke2-server.service

# Make crictl (containerd's CLI -- RKE2 has no docker), kubectl and ctr work in
# any shell: on the default PATH, and with RKE2's containerd socket in the
# config file crictl reads by default.
for bin in crictl kubectl ctr; do
    ln -sf "/var/lib/rancher/rke2/bin/$bin" "/usr/local/bin/$bin"
done
ln -sf /var/lib/rancher/rke2/agent/etc/crictl.yaml /etc/crictl.yaml

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
grep -qxF 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' ~/.bashrc || echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' >> ~/.bashrc
grep -qxF 'alias k=kubectl' ~/.bashrc || echo 'alias k=kubectl' >> ~/.bashrc
cp /etc/rancher/rke2/rke2.yaml /tmp/rke2.yaml
sed -i "s/127.0.0.1/${PUBLIC_IP}/g" /tmp/rke2.yaml
