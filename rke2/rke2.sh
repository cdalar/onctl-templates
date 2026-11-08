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

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
grep -qxF 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' ~/.bashrc || echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' >> ~/.bashrc
grep -qxF 'alias k=/var/lib/rancher/rke2/bin/kubectl' ~/.bashrc || echo 'alias k=/var/lib/rancher/rke2/bin/kubectl' >> ~/.bashrc
cp /etc/rancher/rke2/rke2.yaml /tmp/rke2.yaml
sed -i "s/127.0.0.1/${PUBLIC_IP}/g" /tmp/rke2.yaml
