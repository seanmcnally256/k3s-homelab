#!/usr/bin/env bash
# Check and install all prerequisites for k3s-homelab on Windows (Git Bash)

set -euo pipefail

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
missing() { echo -e "${RED}[✗]${NC} $*"; }
header()  { echo -e "\n${BOLD}$*${NC}"; }

BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"

# ── Check functions ───────────────────────────────────────────────────────────

check_winget() {
  command -v winget &>/dev/null || err "winget not found. Please install App Installer from the Microsoft Store."
}

check_tool() {
  local name="$1"
  if command -v "$name" &>/dev/null; then
    success "$name — $(command -v "$name")"
    return 0
  else
    missing "$name — not found"
    return 1
  fi
}

check_aws_credentials() {
  if aws sts get-caller-identity &>/dev/null; then
    success "AWS credentials — configured"
    return 0
  else
    missing "AWS credentials — not configured"
    return 1
  fi
}

check_ssh_key() {
  if [[ -f "$HOME/.ssh/id_rsa" && -f "$HOME/.ssh/id_rsa.pub" ]]; then
    success "SSH key pair — found at ~/.ssh/id_rsa"
    return 0
  else
    missing "SSH key pair — not found at ~/.ssh/id_rsa"
    return 1
  fi
}

# ── Scan ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}k3s Homelab — Prerequisites Check${NC}"
echo -e "────────────────────────────────────────"
echo ""

check_winget

MISSING=()

header "Checking tools..."

check_tool terraform  || MISSING+=("terraform")
check_tool kubectl    || MISSING+=("kubectl")
check_tool helm       || MISSING+=("helm")
check_tool k3sup      || MISSING+=("k3sup")
check_tool cloudflared || MISSING+=("cloudflared")
check_tool aws        || MISSING+=("aws")
check_tool git        || MISSING+=("git")

header "Checking credentials..."

check_aws_credentials || MISSING+=("aws-credentials")
check_ssh_key         || MISSING+=("ssh-key")

# ── All good ──────────────────────────────────────────────────────────────────

if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo ""
  success "All prerequisites satisfied. You're ready to go."
  echo ""
  exit 0
fi

# ── Missing items found ───────────────────────────────────────────────────────

echo ""
warn "${#MISSING[@]} item(s) need attention:"
for item in "${MISSING[@]}"; do
  echo "    - $item"
done
echo ""
read -rp "Install/configure missing items now? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && exit 0
echo ""

# ── Install ───────────────────────────────────────────────────────────────────

for item in "${MISSING[@]}"; do
  case "$item" in

    terraform)
      header "Installing Terraform..."
      winget install --id Hashicorp.Terraform -e --silent
      success "Terraform installed. Restart your terminal to use it."
      ;;

    kubectl)
      header "Installing kubectl..."
      winget install --id Kubernetes.kubectl -e --silent
      # winget may install to a location not on Git Bash PATH — copy to ~/bin
      KUBECTL_PATH=$(find "/c/Users/$USERNAME" -name "kubectl.exe" 2>/dev/null | head -1)
      if [[ -n "$KUBECTL_PATH" ]]; then
        cp "$KUBECTL_PATH" "$BIN_DIR/kubectl.exe"
        success "kubectl installed to ~/bin."
      else
        warn "kubectl installed but not found in expected location. You may need to add it to PATH manually."
      fi
      ;;

    helm)
      header "Installing Helm..."
      winget install --id Helm.Helm -e --silent
      HELM_PATH=$(find "/c/Users/$USERNAME" -name "helm.exe" 2>/dev/null | head -1)
      if [[ -n "$HELM_PATH" ]]; then
        cp "$HELM_PATH" "$BIN_DIR/helm.exe"
        success "Helm installed to ~/bin."
      else
        warn "Helm installed but not found in expected location. You may need to add it to PATH manually."
      fi
      ;;

    k3sup)
      header "Installing k3sup..."
      info "Downloading k3sup.exe from GitHub..."
      powershell -Command "Invoke-WebRequest -Uri 'https://github.com/alexellis/k3sup/releases/latest/download/k3sup.exe' -OutFile \"\$env:USERPROFILE\bin\k3sup.exe\""
      success "k3sup installed to ~/bin."
      ;;

    cloudflared)
      header "Installing cloudflared..."
      info "Downloading cloudflared.exe from GitHub..."
      powershell -Command "Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile \"\$env:USERPROFILE\bin\cloudflared.exe\""
      success "cloudflared installed to ~/bin."
      ;;

    aws)
      header "Installing AWS CLI..."
      winget install --id Amazon.AWSCLI -e --silent
      success "AWS CLI installed. Restart your terminal to use it."
      ;;

    aws-credentials)
      header "Configuring AWS credentials..."
      echo ""
      echo "You'll need your AWS Access Key ID and Secret Access Key."
      echo "Get them from: AWS Console → IAM → Users → Your user → Security credentials → Create access key"
      echo ""
      aws configure
      success "AWS credentials configured."
      ;;

    ssh-key)
      header "Generating SSH key pair..."
      echo ""
      read -rp "Generate SSH key at ~/.ssh/id_rsa? (y/n): " SSH_CONFIRM
      if [[ "$SSH_CONFIRM" == "y" ]]; then
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        success "SSH key pair generated at ~/.ssh/id_rsa"
      else
        warn "Skipped. Ensure you have a key at ~/.ssh/id_rsa before running k3s-bootstrap.sh"
      fi
      ;;

  esac
done

# ── Final check ───────────────────────────────────────────────────────────────

echo ""
header "Re-checking..."
echo ""

ALL_GOOD=true
check_tool terraform   || ALL_GOOD=false
check_tool kubectl     || ALL_GOOD=false
check_tool helm        || ALL_GOOD=false
check_tool k3sup       || ALL_GOOD=false
check_tool cloudflared || ALL_GOOD=false
check_tool aws         || ALL_GOOD=false
check_tool git         || ALL_GOOD=false
check_aws_credentials  || ALL_GOOD=false
check_ssh_key          || ALL_GOOD=false

echo ""
if [[ "$ALL_GOOD" == true ]]; then
  success "All prerequisites satisfied. You're ready to go."
else
  warn "Some items still need attention. You may need to restart your terminal for PATH changes to take effect."
fi
echo ""
