#!/bin/bash
kubectl -n kube-system create secret generic hcloud --from-literal=token="${HCLOUD_TOKEN}"
# helm repo add hcloud https://charts.hetzner.cloud
# helm repo update hcloud
# helm install hccm hcloud/hcloud-cloud-controller-manager -n kube-system
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/hcloud-cloud-controller-manager/refs/heads/main/deploy/ccm.yaml
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/v2.5.1/deploy/kubernetes/hcloud-csi.yml
