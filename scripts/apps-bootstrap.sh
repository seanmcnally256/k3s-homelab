#!/usr/bin/env bash
# Bootstrap core cluster services: Argo CD, Nginx Ingress, Cloudflare Tunnel
#
# Prerequisites: kubectl, helm, KUBECONFIG set

set -euo pipefail

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[~]${NC} $*"; }
err()     { echo -e "${RED}[✗]${NC} $*"; exit 1; }
header()  { echo -e "\n${BOLD}$*${NC}"; }

# ── Preflight ─────────────────────────────────────────────────────────────────

command -v kubectl &>/dev/null || err "kubectl not found."
command -v helm    &>/dev/null || err "helm not found."

KUBECONFIG="${KUBECONFIG:-infrastructure/k3s/kubeconfig}"
export KUBECONFIG

kubectl cluster-info &>/dev/null || err "Cannot reach cluster. Is KUBECONFIG set correctly?"

# ── Interactive prompts ───────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}k3s Homelab — Apps Bootstrap${NC}"
echo -e "────────────────────────────────────────"
echo ""
echo "This script will install:"
echo "  • Argo CD"
echo "  • Nginx Ingress"
echo "  • Cloudflare Tunnel"
echo ""

read -rp "Cloudflare tunnel token: " CLOUDFLARE_TOKEN
[[ -z "$CLOUDFLARE_TOKEN" ]] && err "Cloudflare token is required."

read -rp "Argo CD hostname (e.g. argo.yourdomain.com): " ARGOCD_HOSTNAME
[[ -z "$ARGOCD_HOSTNAME" ]] && err "Argo CD hostname is required."

echo ""
echo -e "  Cloudflare token : ${GREEN}provided${NC}"
echo -e "  Argo CD hostname : ${GREEN}${ARGOCD_HOSTNAME}${NC}"
echo ""
read -rp "Proceed? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && exit 0
echo ""

# ── Argo CD ───────────────────────────────────────────────────────────────────

header "Installing Argo CD..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

info "Waiting for Argo CD server..."
kubectl wait deployment argocd-server -n argocd \
  --for=condition=Available --timeout=180s

info "Patching to insecure mode (TLS handled by Cloudflare)..."
kubectl patch deployment argocd-server -n argocd \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--insecure"}]'

info "Removing network policies..."
kubectl delete networkpolicy -n argocd --all --ignore-not-found

success "Argo CD installed."

# ── Nginx Ingress ─────────────────────────────────────────────────────────────

header "Installing Nginx Ingress..."

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx &>/dev/null
helm repo update &>/dev/null

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --wait

info "Waiting for Nginx Ingress to be ready..."
kubectl wait deployment ingress-nginx-controller -n ingress-nginx \
  --for=condition=Available --timeout=120s

success "Nginx Ingress installed."

# ── Cloudflare Tunnel ─────────────────────────────────────────────────────────

header "Deploying Cloudflare Tunnel..."

kubectl create namespace cloudflared --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic cloudflared-token \
  --namespace cloudflared \
  --from-literal=token="${CLOUDFLARE_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          args:
            - tunnel
            - --no-autoupdate
            - run
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflared-token
                  key: token
EOF

info "Waiting for cloudflared to be ready..."
kubectl wait deployment cloudflared -n cloudflared \
  --for=condition=Available --timeout=60s

success "Cloudflare Tunnel deployed."

# ── Argo CD Ingress ───────────────────────────────────────────────────────────

header "Applying Argo CD Ingress..."

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  rules:
    - host: ${ARGOCD_HOSTNAME}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
EOF

success "Argo CD ingress applied."

# ── Done ──────────────────────────────────────────────────────────────────────

ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo -e "${BOLD}────────────────────────────────────────${NC}"
echo -e "${GREEN}Bootstrap complete.${NC}"
echo ""
echo -e "  Argo CD URL      : ${CYAN}https://${ARGOCD_HOSTNAME}${NC}"
echo -e "  Argo CD username : ${CYAN}admin${NC}"
echo -e "  Argo CD password : ${CYAN}${ARGOCD_PASSWORD}${NC}"
echo ""
warn "Connect Argo CD to your apps repo and add your applications."
echo -e "${BOLD}────────────────────────────────────────${NC}"
echo ""
