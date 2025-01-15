#!/bin/bash
curl -sfL https://get.rke2.io | sh -

systemctl enable rke2-server.service
systemctl start rke2-server.service

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
grep -qxF 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' ~/.bashrc || echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' >> ~/.bashrc
grep -qxF 'alias k=/var/lib/rancher/rke2/bin/kubectl' ~/.bashrc || echo 'alias k=/var/lib/rancher/rke2/bin/kubectl' >> ~/.bashrc
cp /etc/rancher/rke2/rke2.yaml /tmp/rke2.yaml
sed -i "s/127.0.0.1/${PUBLIC_IP}/g" /tmp/rke2.yaml
