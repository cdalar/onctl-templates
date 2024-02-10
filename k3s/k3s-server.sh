#!/bin/bash
ufw disable
TOKEN=$(echo $RANDOM | md5sum | head -c 32)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --disable-network-policy --write-kubeconfig-mode=644 --token $TOKEN

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc || echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
grep -qxF 'alias k=kubectl' ~/.bashrc || echo 'alias k=kubectl' >> ~/.bashrc
cp /etc/rancher/k3s/k3s.yaml /tmp/k3s.yaml
sed -i "s/127.0.0.1/${PUBLIC_IP}/g" /tmp/k3s.yaml
echo $TOKEN > /tmp/token