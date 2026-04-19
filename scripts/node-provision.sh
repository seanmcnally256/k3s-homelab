#!/usr/bin/env bash
# node-provision.sh — Preflight checks and VM bring-up via Vagrant

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[→]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[~]${NC} $*"; }
err()     { echo -e "${RED}[✗]${NC} $*"; exit 1; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        k3s Homelab Node Bring-up     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# ── Preflight ─────────────────────────────────────────────────────────────────

info "Running preflight checks..."

command -v vagrant &>/dev/null \
  || err "vagrant not found. Install from https://developer.hashicorp.com/vagrant/downloads"
success "vagrant found: $(vagrant --version)"

command -v VBoxManage &>/dev/null \
  || err "VBoxManage not found. Install VirtualBox from https://www.virtualbox.org/wiki/Downloads"
success "VirtualBox found: $(VBoxManage --version)"

[[ -f "Vagrantfile" ]] \
  || err "Vagrantfile not found. Run this script from the repo root."
success "Vagrantfile present."

if ! { command -v oscdimg &>/dev/null || oscdimg 2>&1 | grep -q "OSCDIMG"; }; then
  err "oscdimg.exe not found (required for cloud-init ISO). Install the Windows ADK Deployment Tools and add its directory (not the .exe) to PATH: https://go.microsoft.com/fwlink/?linkid=2196127"
fi
success "oscdimg found."

echo ""

# ── Bring up VMs ──────────────────────────────────────────────────────────────

info "Bringing up all nodes..."
vagrant up --no-parallel
echo ""

# ── Status ────────────────────────────────────────────────────────────────────

success "All nodes are up. VM status:"
echo ""
vagrant status
echo ""
info "Next step: run scripts/k3s-install.sh to install k3s across the cluster."
