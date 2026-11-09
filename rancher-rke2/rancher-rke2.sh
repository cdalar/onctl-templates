#!/bin/bash
# Rancher on single-node RKE2, behind a proxy that terminates TLS -- such as a
# boxctl.io public URL, which sends plain HTTP to the box's port 80.
#
#   onctl up -n rancher -a rancher-rke2/rancher-rke2.sh
#
# Rancher is installed with tls=external and answers on port 80 for any
# hostname, so it works before the public address is known: make port 80
# public afterwards, open that address, and confirm it as the Server URL at
# first login.
#
# Optional variables (onctl -e KEY=VALUE):
#   RANCHER_HOSTNAME    the address users open, if known up front (default: unset -- any hostname is served)
#   RANCHER_VERSION     Rancher chart version from rancher-stable (default: latest)
#   BOOTSTRAP_PASSWORD  first admin login (default: random, saved to /root/rancher-bootstrap-password)
#   RKE2_VERSION        e.g. v1.35.4+rke2r1 (default: RKE2 stable channel). Must be supported by the Rancher version.
set -euo pipefail

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH="$PATH:/var/lib/rancher/rke2/bin"
LOCAL_IP="$(hostname -I | awk '{print $1}')"
PASSWORD_FILE=/root/rancher-bootstrap-password
# Used only for the chart's own Ingress rule; the catch-all Ingress below
# serves every other hostname.
CHART_HOSTNAME="${RANCHER_HOSTNAME:-rancher.localhost}"

wait_for() {  # wait_for <seconds> <description> <command...>
    local timeout=$1 what=$2; shift 2
    for _ in $(seq 1 $((timeout / 5))); do
        if "$@" >/dev/null 2>&1; then return 0; fi
        sleep 5
    done
    echo "Timed out waiting for ${what}" >&2
    return 1
}

if ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw disable
fi

# RKE2's CNI plugins (portmap) run iptables from the host's PATH.
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

# RKE2
if [ ! -f "$KUBECONFIG" ]; then
    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="${RKE2_VERSION:-}" sh -
    systemctl enable --now rke2-server.service
else
    echo "RKE2 is already installed. Skipping installation."
fi
grep -qxF "export KUBECONFIG=$KUBECONFIG" ~/.bashrc || echo "export KUBECONFIG=$KUBECONFIG" >> ~/.bashrc
grep -qxF 'export PATH=$PATH:/var/lib/rancher/rke2/bin' ~/.bashrc || echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc
grep -qxF 'alias k=kubectl' ~/.bashrc || echo 'alias k=kubectl' >> ~/.bashrc

wait_for 600 "the RKE2 kubeconfig" test -f "$KUBECONFIG"
cp "$KUBECONFIG" /tmp/rke2.yaml
chmod 600 /tmp/rke2.yaml
wait_for 600 "node Ready" sh -c 'kubectl get nodes --no-headers | grep -qw Ready'

# Ingress controller: Traefik on recent RKE2, ingress-nginx on older ones.
ingress_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' "http://${LOCAL_IP}/")" != "000" ]; }
wait_for 600 "an IngressClass" sh -c 'kubectl get ingressclass --no-headers | grep -q .'
INGRESS_CLASS=$(kubectl get ingressclass -o jsonpath='{.items[0].metadata.name}')
wait_for 600 "the ingress controller on port 80" ingress_up

# Pass on the proxy's X-Forwarded-Proto: https instead of replacing it with
# "http", so Rancher knows it is reached over HTTPS.
case "$INGRESS_CLASS" in
    traefik)
        CHART=rke2-traefik
        VALUES=$'    ports:\n      web:\n        forwardedHeaders:\n          insecure: true'
        TRUSTED='forwardedHeaders.insecure' ;;
    nginx)
        CHART=rke2-ingress-nginx
        VALUES=$'    controller:\n      config:\n        use-forwarded-headers: "true"'
        TRUSTED='use-forwarded-headers' ;;
    *)
        echo "Unexpected IngressClass '${INGRESS_CLASS}'; don't know how to make it trust X-Forwarded-Proto." >&2
        exit 1 ;;
esac
cat > "/var/lib/rancher/rke2/server/manifests/${CHART}-config.yaml" <<EOF
# Written by rancher-rke2/rancher-rke2.sh: TLS ends in front of this VM, so
# trust the X-Forwarded-* headers that arrive on port 80.
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: ${CHART}
  namespace: kube-system
spec:
  valuesContent: |-
${VALUES}
EOF
wait_for 600 "${CHART} to trust forwarded headers" \
    sh -c "kubectl get configmap,deploy,ds -n kube-system -o yaml | grep -q '${TRUSTED}'"
for r in $(kubectl -n kube-system get deploy,ds -o name | grep -E 'traefik|ingress-nginx'); do
    kubectl -n kube-system rollout status "$r" --timeout=300s
done
wait_for 300 "the ingress controller on port 80" ingress_up

# Helm
if ! command -v helm &>/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable --force-update
helm repo update

# Rancher. agentTLSMode=system-store: with TLS in front of Rancher it has no CA
# of its own to pin, so 2.9+'s default (strict) makes every downstream node's
# registration abort with "strict CA verification with no CA checksum". The
# proxy's certificate is publicly trusted (a boxctl public URL's is), so the
# system trust store is what agents should check it against.
if [ -n "${BOOTSTRAP_PASSWORD:-}" ]; then
    printf '%s\n' "$BOOTSTRAP_PASSWORD" > "$PASSWORD_FILE"
elif [ ! -s "$PASSWORD_FILE" ]; then
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20 > "$PASSWORD_FILE"
    echo >> "$PASSWORD_FILE"
fi
chmod 600 "$PASSWORD_FILE"

if ! helm upgrade --install rancher rancher-stable/rancher -n cattle-system --create-namespace \
    ${RANCHER_VERSION:+--version "$RANCHER_VERSION"} \
    --set hostname="$CHART_HOSTNAME" \
    --set tls=external \
    --set agentTLSMode=system-store \
    --set ingress.ingressClassName="$INGRESS_CLASS" \
    --set bootstrapPassword="$(head -n1 "$PASSWORD_FILE")" \
    --set replicas=1 \
    --wait --timeout 15m; then
    echo "Rancher install failed. If helm reports an incompatible kubeVersion, set RKE2_VERSION to a" >&2
    echo "version the Rancher release supports (see the Rancher support matrix)." >&2
    exit 1
fi
kubectl -n cattle-system rollout status deploy/rancher --timeout=15m

# Serve Rancher on every hostname, so the public address works whatever it
# turns out to be. A rule with a host (the chart's) still wins for that host.
if [ -z "${RANCHER_HOSTNAME:-}" ]; then
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rancher-any-host
  namespace: cattle-system
spec:
  ingressClassName: ${INGRESS_CLASS}
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rancher
            port:
              number: 80
EOF
fi
wait_for 300 "Rancher /ping" sh -c "curl -sf --resolve ${CHART_HOSTNAME}:80:${LOCAL_IP} http://${CHART_HOSTNAME}/ping | grep -q pong"

if [ -n "${RANCHER_HOSTNAME:-}" ]; then
    URL_LINE="Rancher URL:        https://${RANCHER_HOSTNAME}/"
else
    URL_LINE="Rancher URL:        the address that sends HTTPS traffic to this VM's port 80
                    (on boxctl.io: make port 80 public, then open its https://<label>.boxctl.app URL).
                    At first login, check that the Server URL Rancher offers is that address."
fi
cat > /root/rancher-info.txt <<EOF
${URL_LINE}
Bootstrap password: $(head -n1 "$PASSWORD_FILE")   (also in ${PASSWORD_FILE}; change it at first login)
Rancher version:    $(helm -n cattle-system list -f '^rancher$' -o json | sed -n 's/.*"app_version":"\([^"]*\)".*/\1/p')
Kubernetes:         RKE2 $(kubectl version -o json 2>/dev/null | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p' | tail -n1), ingress class ${INGRESS_CLASS}
Kubeconfig:         /tmp/rke2.yaml (server 127.0.0.1:6443)
EOF
chmod 600 /root/rancher-info.txt
cat /root/rancher-info.txt
