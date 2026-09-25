#!/bin/bash
# Rancher management ("local") cluster on a single k3s node: k3s + cert-manager + Rancher.
#
#   onctl up -n rancher -a rancher/rancher-local.sh
#
# Optional variables (onctl -e KEY=VALUE):
#   RANCHER_HOSTNAME      default: rancher.<public-ip-with-dashes>.sslip.io (resolves to the VM, no DNS needed)
#   RANCHER_VERSION       Rancher chart version from rancher-stable (default: latest)
#   RANCHER_REPLICAS      default: 1
#   BOOTSTRAP_PASSWORD    first admin login (default: random, saved to /root/rancher-bootstrap-password)
#   CERT_MANAGER_VERSION  cert-manager chart version (default: latest)
#   K3S_VERSION           e.g. v1.35.4+k3s1 (default: k3s stable channel). Must be supported by the Rancher version.
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
IP="${PUBLIC_IP:-$(hostname -I | awk '{print $1}')}"
RANCHER_HOSTNAME="${RANCHER_HOSTNAME:-rancher.${IP//./-}.sslip.io}"
RANCHER_REPLICAS="${RANCHER_REPLICAS:-1}"
PASSWORD_FILE=/root/rancher-bootstrap-password

wait_for() {  # wait_for <seconds> <description> <command...>
    local timeout=$1 what=$2; shift 2
    for _ in $(seq 1 $((timeout / 5))); do
        if "$@" >/dev/null 2>&1; then return 0; fi
        sleep 5
    done
    echo "Timed out waiting for ${what}" >&2
    return 1
}

# Disable UFW if active (same as k3s/k3s-server.sh)
if ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw disable
fi

# k3s
if ! command -v k3s &>/dev/null; then
    TOKEN=$(openssl rand -hex 16)
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION:-}" INSTALL_K3S_EXEC="server" \
        sh -s - --disable-network-policy --write-kubeconfig-mode=600 --token "$TOKEN"
    echo "$TOKEN" > /tmp/token
else
    echo "k3s is already installed. Skipping installation."
fi
grep -qxF "export KUBECONFIG=$KUBECONFIG" ~/.bashrc || echo "export KUBECONFIG=$KUBECONFIG" >> ~/.bashrc
grep -qxF 'alias k=kubectl' ~/.bashrc || echo 'alias k=kubectl' >> ~/.bashrc

# Kubeconfig with the public IP, for `onctl up ... --download /tmp/k3s.yaml`
sed "s/127.0.0.1/${IP}/g" "$KUBECONFIG" > /tmp/k3s.yaml
chmod 600 /tmp/k3s.yaml

wait_for 300 "node Ready" sh -c 'kubectl get nodes --no-headers | grep -qw Ready'
wait_for 300 "Traefik deployment" kubectl -n kube-system get deploy traefik
kubectl -n kube-system rollout status deploy/traefik --timeout=300s

# Helm
if ! command -v helm &>/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable --force-update
helm repo update

# cert-manager (issues Rancher's self-signed certificate)
helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
    ${CERT_MANAGER_VERSION:+--version "$CERT_MANAGER_VERSION"} \
    --set crds.enabled=true --wait --timeout 10m

# Rancher
if [ -n "${BOOTSTRAP_PASSWORD:-}" ]; then
    printf '%s\n' "$BOOTSTRAP_PASSWORD" > "$PASSWORD_FILE"
elif [ ! -s "$PASSWORD_FILE" ]; then
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20 > "$PASSWORD_FILE"
    echo >> "$PASSWORD_FILE"
fi
chmod 600 "$PASSWORD_FILE"

if ! helm upgrade --install rancher rancher-stable/rancher -n cattle-system --create-namespace \
    ${RANCHER_VERSION:+--version "$RANCHER_VERSION"} \
    --set hostname="$RANCHER_HOSTNAME" \
    --set bootstrapPassword="$(head -n1 "$PASSWORD_FILE")" \
    --set replicas="$RANCHER_REPLICAS" \
    --wait --timeout 15m; then
    echo "Rancher install failed. If helm reports an incompatible kubeVersion, set K3S_VERSION to a" >&2
    echo "version supported by the Rancher release (see the Rancher support matrix)." >&2
    exit 1
fi
kubectl -n cattle-system rollout status deploy/rancher --timeout=15m
wait_for 300 "Rancher /ping" sh -c "curl -skf --resolve ${RANCHER_HOSTNAME}:443:127.0.0.1 https://${RANCHER_HOSTNAME}/ping | grep -q pong"

cat > /root/rancher-info.txt <<EOF
Rancher URL:        https://${RANCHER_HOSTNAME}/
Bootstrap password: $(head -n1 "$PASSWORD_FILE")   (also in ${PASSWORD_FILE}; change it at first login)
Rancher version:    $(helm -n cattle-system list -f '^rancher$' -o json | sed -n 's/.*"app_version":"\([^"]*\)".*/\1/p')
Kubeconfig:         /tmp/k3s.yaml (server = ${IP})
The certificate is self-signed (cert-manager); accept the browser warning.
EOF
chmod 600 /root/rancher-info.txt
cat /root/rancher-info.txt
