#!/usr/bin/env bash
# Bootstrap k3s across AWS nodes using k3sup + Terraform outputs
#
# Prerequisites: terraform, k3sup, kubectl

set -euo pipefail

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[~]${NC} $*"; }
err()     { echo -e "${RED}[✗]${NC} $*"; exit 1; }

TERRAFORM_DIR="infrastructure/terraform"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
SSH_KEY_WIN=$(cygpath -w "$SSH_KEY")
SSH_USER="ubuntu"
KUBECONFIG_OUT="infrastructure/k3s/kubeconfig"
CALICO_VERSION="v3.29.3"

[[ -d "$TERRAFORM_DIR" ]] || err "Run this script from the repo root."
command -v terraform &>/dev/null || err "terraform not found — install it first."
command -v k3sup     &>/dev/null || err "k3sup not found — install it first."
command -v kubectl   &>/dev/null || err "kubectl not found — install it first."

# ── Read IPs from Terraform ───────────────────────────────────────────────────

info "Reading node IPs from Terraform..."

CONTROL_PUBLIC_IP=$(terraform -chdir="$TERRAFORM_DIR" output -raw control_public_ip)
CONTROL_PRIVATE_IP=$(terraform -chdir="$TERRAFORM_DIR" output -raw control_private_ip)

mapfile -t WORKER_PUBLIC_IPS  < <(terraform -chdir="$TERRAFORM_DIR" output -json worker_public_ips  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
mapfile -t WORKER_PRIVATE_IPS < <(terraform -chdir="$TERRAFORM_DIR" output -json worker_private_ips | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

success "Control:  ${CONTROL_PUBLIC_IP} (private: ${CONTROL_PRIVATE_IP})"
for i in "${!WORKER_PUBLIC_IPS[@]}"; do
  success "Worker $((i+1)): ${WORKER_PUBLIC_IPS[$i]} (private: ${WORKER_PRIVATE_IPS[$i]})"
done

# ── Install k3s on control plane ──────────────────────────────────────────────

info "Installing k3s on control plane..."
mkdir -p "$(dirname "$KUBECONFIG_OUT")"

k3sup install \
  --ip           "$CONTROL_PUBLIC_IP" \
  --user         "$SSH_USER" \
  --ssh-key      "$SSH_KEY_WIN" \
  --local-path   "$KUBECONFIG_OUT" \
  --context      "k3s-homelab" \
  --k3s-extra-args "--flannel-backend=none --disable-network-policy --disable=traefik --disable=servicelb --node-ip=${CONTROL_PRIVATE_IP}"

success "Control plane ready. Kubeconfig saved to ${KUBECONFIG_OUT}"

# ── Join workers ──────────────────────────────────────────────────────────────

for i in "${!WORKER_PUBLIC_IPS[@]}"; do
  public_ip="${WORKER_PUBLIC_IPS[$i]}"
  private_ip="${WORKER_PRIVATE_IPS[$i]}"
  info "Joining worker $((i+1))..."

  k3sup join \
    --ip         "$public_ip" \
    --server-ip  "$CONTROL_PUBLIC_IP" \
    --user       "$SSH_USER" \
    --ssh-key    "$SSH_KEY_WIN" \
    --k3s-extra-args "--node-ip=${private_ip}"

  success "Worker $((i+1)) joined."
done

# ── Install Calico CNI ────────────────────────────────────────────────────────

info "Installing Calico CNI..."
KUBECONFIG="$KUBECONFIG_OUT" kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

info "Waiting for nodes to become Ready..."
KUBECONFIG="$KUBECONFIG_OUT" kubectl wait --for=condition=Ready nodes --all --timeout=120s

success "All nodes Ready."

echo ""
echo "  export KUBECONFIG=${KUBECONFIG_OUT}"
echo "  kubectl get nodes"
