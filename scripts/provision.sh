#!/usr/bin/env bash
# provision.sh — Launch k3s homelab VMs
# Run from the infrastructure/multipass/ directory

set -euo pipefail

REPO="https://raw.githubusercontent.com/seanmcnally256/k3s-homelab/main/infrastructure/multipass"

# Returns 0 (true) if a VM with the given name already exists
vm_exists() {
  local name="$1"
  multipass info "${name}" &>/dev/null
}

launch_vm() {
  local name="$1"
  local cloud_init_url="$2"

  if vm_exists "${name}"; then
    echo "VM '${name}' already exists — skipping."
    return
  fi

  echo "Launching ${name}..."
  multipass launch 22.04 \
    --name "${name}" \
    --cloud-init "${cloud_init_url}"
  echo "${name} ready."
}

launch_vm k3s-control  "${REPO}/cloud-init.yaml"
launch_vm k3s-worker-1 "${REPO}/cloud-init.yaml"
launch_vm k3s-worker-2 "${REPO}/cloud-init.yaml"

multipass list