#!/bin/bash

# Disable UFW if not already disabled
if ufw status | grep -q "active"; then
    ufw disable
fi

# Check if K3s is already installed
if ! command -v k3s &> /dev/null; then
    TOKEN=$(echo $RANDOM | md5sum | head -c 32)
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --disable-network-policy --write-kubeconfig-mode=644 --token $TOKEN
else
    echo "K3s is already installed. Skipping installation."
fi

# Ensure KUBECONFIG is set in ~/.bashrc
if ! grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc; then
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
fi

# Ensure alias for kubectl is set in ~/.bashrc
if ! grep -qxF 'alias k=kubectl' ~/.bashrc; then
    echo 'alias k=kubectl' >> ~/.bashrc
fi

# Update kubeconfig file with public IP if not already updated
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    cp /etc/rancher/k3s/k3s.yaml /tmp/k3s.yaml
    if ! grep -q "${PUBLIC_IP}" /tmp/k3s.yaml; then
        sed -i "s/127.0.0.1/${PUBLIC_IP}/g" /tmp/k3s.yaml
    fi
fi

# Write token to /tmp/token if not already written
if [ ! -f /tmp/token ]; then
    echo $TOKEN > /tmp/token
fi