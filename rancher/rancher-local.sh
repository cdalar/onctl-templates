#!/bin/bash
# Rancher management ("local") cluster on a single node: Kubernetes + Rancher.
#
#   onctl up -n rancher -a rancher/rancher-local.sh
#
# Kubernetes: an RKE2 or k3s cluster already on the VM is used as is (for
# example one from rke2/rke2.sh); otherwise k3s is installed.
#
# Optional variables (onctl -e KEY=VALUE):
#   RANCHER_HOSTNAME      default: rancher.<public-ip-with-dashes>.sslip.io (resolves to the VM, no DNS needed)
#   RANCHER_TLS           ingress (default): Rancher serves HTTPS on 443 with a cert-manager self-signed certificate.
#                         external: TLS ends in front of the VM (a load balancer, or a boxctl public URL) and
#                         Rancher serves plain HTTP on 80; cert-manager is not installed.
#   RANCHER_VERSION       Rancher chart version from rancher-stable (default: latest)
#   RANCHER_REPLICAS      default: 1
#   BOOTSTRAP_PASSWORD    first admin login (default: random, saved to /root/rancher-bootstrap-password)
#   CERT_MANAGER_VERSION  cert-manager chart version (default: latest; RANCHER_TLS=ingress only)
#   K3S_VERSION           e.g. v1.35.4+k3s1 (default: k3s stable channel). Must be supported by the Rancher version.
#                         Only used when k3s is installed here.
set -euo pipefail

LOCAL_IP="$(hostname -I | awk '{print $1}')"  # what the ingress listens on; PUBLIC_IP may be NATed
IP="${PUBLIC_IP:-$LOCAL_IP}"
RANCHER_HOSTNAME="${RANCHER_HOSTNAME:-rancher.${IP//./-}.sslip.io}"
RANCHER_REPLICAS="${RANCHER_REPLICAS:-1}"
RANCHER_TLS="${RANCHER_TLS:-ingress}"
PASSWORD_FILE=/root/rancher-bootstrap-password

case "$RANCHER_TLS" in
    ingress|external) ;;
    *) echo "RANCHER_TLS must be 'ingress' or 'external', not '${RANCHER_TLS}'" >&2; exit 1 ;;
esac

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

# Kubernetes: reuse RKE2 or k3s if present, else install k3s.
if [ -f /etc/rancher/rke2/rke2.yaml ]; then
    DISTRO=rke2
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    export PATH="$PATH:/var/lib/rancher/rke2/bin"
    grep -qxF 'export PATH=$PATH:/var/lib/rancher/rke2/bin' ~/.bashrc || echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc
    echo "RKE2 is already installed. Using it."
else
    DISTRO=k3s
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    if ! command -v k3s &>/dev/null; then
        TOKEN=$(openssl rand -hex 16)
        curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION:-}" INSTALL_K3S_EXEC="server" \
            sh -s - --disable-network-policy --write-kubeconfig-mode=600 --token "$TOKEN"
        echo "$TOKEN" > /tmp/token
    else
        echo "k3s is already installed. Skipping installation."
    fi
fi
MANIFESTS="/var/lib/rancher/${DISTRO}/server/manifests"
grep -qxF "export KUBECONFIG=$KUBECONFIG" ~/.bashrc || echo "export KUBECONFIG=$KUBECONFIG" >> ~/.bashrc
grep -qxF 'alias k=kubectl' ~/.bashrc || echo 'alias k=kubectl' >> ~/.bashrc

# Kubeconfig with the public IP, for `onctl up ... --download /tmp/<distro>.yaml`
KUBECONFIG_COPY="/tmp/${DISTRO}.yaml"
sed "s/127.0.0.1/${IP}/g" "$KUBECONFIG" > "$KUBECONFIG_COPY"
chmod 600 "$KUBECONFIG_COPY"

wait_for 300 "node Ready" sh -c 'kubectl get nodes --no-headers | grep -qw Ready'

# The ingress controller the distribution ships: Traefik (k3s, recent RKE2) or
# ingress-nginx (older RKE2). Ready once something answers HTTP on port 80.
ingress_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' "http://${LOCAL_IP}/")" != "000" ]; }
wait_for 300 "an IngressClass" sh -c 'kubectl get ingressclass --no-headers | grep -q .'
INGRESS_CLASS=$(kubectl get ingressclass -o jsonpath='{.items[0].metadata.name}')
wait_for 300 "the ingress controller on port 80" ingress_up

# RANCHER_TLS=external: the ingress controller must pass on the
# X-Forwarded-Proto: https it receives instead of replacing it with "http",
# or Rancher believes it is being reached over plain HTTP.
if [ "$RANCHER_TLS" = external ]; then
    case "${DISTRO}/${INGRESS_CLASS}" in
        k3s/traefik)  CHART=traefik ;;
        rke2/traefik) CHART=rke2-traefik ;;
        rke2/nginx)   CHART=rke2-ingress-nginx ;;
        *) echo "Don't know how to make IngressClass '${INGRESS_CLASS}' on ${DISTRO} trust X-Forwarded-Proto." >&2
           echo "Configure it yourself, or use RANCHER_TLS=ingress." >&2
           exit 1 ;;
    esac
    if [ "$CHART" = rke2-ingress-nginx ]; then
        VALUES=$'    controller:\n      config:\n        use-forwarded-headers: "true"'
        TRUSTED='use-forwarded-headers'
    else
        VALUES=$'    ports:\n      web:\n        forwardedHeaders:\n          insecure: true'
        TRUSTED='forwardedHeaders.insecure'
    fi
    cat > "${MANIFESTS}/${CHART}-config.yaml" <<EOF
# Written by rancher/rancher-local.sh (RANCHER_TLS=external): TLS ends in front
# of this VM, so trust the X-Forwarded-* headers that arrive on port 80.
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: ${CHART}
  namespace: kube-system
spec:
  valuesContent: |-
${VALUES}
EOF
    # The chart is redeployed with the new values; wait until it has been.
    wait_for 300 "${CHART} to trust forwarded headers" \
        sh -c "kubectl get configmap,deploy,ds -n kube-system -o yaml | grep -q '${TRUSTED}'"
    for r in $(kubectl -n kube-system get deploy,ds -o name | grep -E 'traefik|ingress-nginx'); do
        kubectl -n kube-system rollout status "$r" --timeout=300s
    done
    wait_for 300 "the ingress controller on port 80" ingress_up
fi

# Helm
if ! command -v helm &>/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable --force-update

# cert-manager (issues Rancher's self-signed certificate)
if [ "$RANCHER_TLS" = ingress ]; then
    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update
    helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
        ${CERT_MANAGER_VERSION:+--version "$CERT_MANAGER_VERSION"} \
        --set crds.enabled=true --wait --timeout 10m
else
    helm repo update
fi

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
    --set tls="$RANCHER_TLS" \
    --set ingress.ingressClassName="$INGRESS_CLASS" \
    --set bootstrapPassword="$(head -n1 "$PASSWORD_FILE")" \
    --set replicas="$RANCHER_REPLICAS" \
    --wait --timeout 15m; then
    echo "Rancher install failed. If helm reports an incompatible kubeVersion, the ${DISTRO} version is newer" >&2
    echo "than the Rancher release supports (see the Rancher support matrix)." >&2
    exit 1
fi
kubectl -n cattle-system rollout status deploy/rancher --timeout=15m
if [ "$RANCHER_TLS" = ingress ]; then
    wait_for 300 "Rancher /ping" sh -c "curl -skf --resolve ${RANCHER_HOSTNAME}:443:127.0.0.1 https://${RANCHER_HOSTNAME}/ping | grep -q pong"
    CERT_NOTE="The certificate is self-signed (cert-manager); accept the browser warning."
else
    wait_for 300 "Rancher /ping" sh -c "curl -sf --resolve ${RANCHER_HOSTNAME}:80:${LOCAL_IP} http://${RANCHER_HOSTNAME}/ping | grep -q pong"
    CERT_NOTE="TLS is handled in front of this VM (RANCHER_TLS=external); Rancher itself serves HTTP on port 80."
fi

cat > /root/rancher-info.txt <<EOF
Rancher URL:        https://${RANCHER_HOSTNAME}/
Bootstrap password: $(head -n1 "$PASSWORD_FILE")   (also in ${PASSWORD_FILE}; change it at first login)
Rancher version:    $(helm -n cattle-system list -f '^rancher$' -o json | sed -n 's/.*"app_version":"\([^"]*\)".*/\1/p')
Kubernetes:         ${DISTRO}, ingress class ${INGRESS_CLASS}
Kubeconfig:         ${KUBECONFIG_COPY} (server = ${IP})
${CERT_NOTE}
EOF
chmod 600 /root/rancher-info.txt
cat /root/rancher-info.txt
