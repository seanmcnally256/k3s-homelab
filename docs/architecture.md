# k3s Homelab — Architecture

## Overview

A lightweight k3s cluster running on AWS EC2, provisioned with Terraform and bootstrapped
with k3sup. Goals: learning Kubernetes internals, CNI, GitOps, and observability.

## Cluster Topology

| Node         | Role          | Instance  | vCPU | RAM  |
|--------------|---------------|-----------|------|------|
| k3s-control  | Control Plane | t3.small  | 2    | 2 GB |
| k3s-worker-1 | Worker        | t3.small  | 2    | 2 GB |
| k3s-worker-2 | Worker        | t3.small  | 2    | 2 GB |

Public IPs are assigned by AWS and used for SSH and kubectl from the host.
Cluster-internal traffic (node-to-node, pod-to-pod) uses private IPs within the VPC.

Run `terraform -chdir=infrastructure/terraform output` to see current IPs.

## Network Design

```
Your laptop
│
├── SSH / kubectl (public IPs, ports 22 + 6443)
│
└── AWS VPC  10.0.0.0/16
    └── Subnet  10.0.0.0/24  (us-east-1a)
        ├── k3s-control   (public + private IP)
        ├── k3s-worker-1  (public + private IP)
        └── k3s-worker-2  (public + private IP)
            │
            └── Internet Gateway → outbound internet
```

## Security

| Layer   | Control |
|---------|---------|
| Network | AWS security group — SSH (22), kubectl API (6443), all internal VPC traffic |
| SSH     | Key-only auth (`ssh_pwauth: false`), root login disabled |

## Planned Stack

| Layer         | Choice                       |
|---------------|------------------------------|
| Infra         | Terraform + AWS              |
| Kubernetes    | k3s (Flannel + Traefik disabled) |
| CNI           | Calico                       |
| Ingress       | Nginx + cert-manager         |
| Storage       | OpenEBS Local PV             |
| Observability | Alloy + Prometheus + Grafana |
| GitOps        | Flux                         |

## Bring-up Sequence

```bash
# 1. Provision AWS infrastructure
terraform -chdir=infrastructure/terraform apply

# 2. Install k3s + Calico across all nodes
./scripts/k3s-install.sh

# 3. Connect
export KUBECONFIG=infrastructure/k3s/kubeconfig
kubectl get nodes

# 4. Apply manifests in order
#    networking → storage → observability → gitops
```
