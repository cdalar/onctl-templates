#!/bin/bash
ufw disable
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --cloud-provider=external --disable=servicelb --disable-cloud-controller --disable=traefik --disable-network-policy --write-kubeconfig-mode=644 --disable-kube-proxy --flannel-backend none --token 123456
# Check for Ready node, takes ~30 seconds 
#sudo k3s kubectl get node 

# install cilium cli 
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc || echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
grep -qxF 'alias k=kubectl' ~/.bashrc || echo 'alias k=kubectl' >> ~/.bashrc
cp /etc/rancher/k3s/k3s.yaml /tmp/k3s.yaml
sed -i "s/127.0.0.1/${PUBLIC_IP}/g" /tmp/k3s.yaml

# install cilium
CILIUM_STABLE_VERSION=$(cilium version --client | grep stable | awk '{print $4}')
cilium install --version $CILIUM_STABLE_VERSION
cilium status --wait
