# k3s Homelab — Architecture

## Overview

A lightweight k3s cluster running on AWS EC2, provisioned with Terraform and bootstrapped
with k3sup. Goals: learning Kubernetes internals, CNI, GitOps, and observability.

## Repositories

| Repo | Purpose |
|------|---------|
| [k3s-homelab](https://github.com/seanmcnally256/k3s-homelab) | Infrastructure — Terraform, cloud-init, bootstrap script |
| [k3s-apps](https://github.com/seanmcnally256/k3s-apps) | Cluster apps — all manifests managed by Argo CD |
| [www-seancloud](https://github.com/seanmcnally256/www-seancloud) | Website — HTML/CSS, Dockerfile, GitHub Actions |

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
Browser → Cloudflare Edge (TLS) → cloudflared pod → Nginx Ingress → Service → Pod

Your laptop
│
├── SSH / kubectl (public IPs, ports 22 + 6443)
│
└── AWS VPC  10.0.0.0/16
    └── Subnet  10.0.0.0/24  (us-east-1a)
        ├── k3s-control   (public + private IP)
        ├── k3s-worker-1  (public + private IP)
        └── k3s-worker-2  (public + private IP)
```

## Security

| Layer   | Control |
|---------|---------|
| Network | AWS security group — SSH (22), kubectl API (6443), all internal VPC traffic only |
| SSH     | Key-only auth (`ssh_pwauth: false`), root login disabled |
| Ingress | No ports 80/443 open — all web traffic flows through Cloudflare Tunnel |

## Current Stack

| Layer         | Choice                          |
|---------------|---------------------------------|
| Infra         | Terraform + AWS                 |
| Kubernetes    | k3s                             |
| CNI           | Calico                          |
| Ingress       | Nginx                           |
| Tunnel        | Cloudflare Tunnel (cloudflared) |
| GitOps        | Argo CD                         |
| Cluster UI    | Headlamp                        |

## Bring-up Sequence

```bash
# 1. Provision AWS infrastructure
terraform -chdir=infrastructure/terraform apply

# 2. Install k3s + Calico across all nodes
./scripts/k3s-bootstrap.sh

# 3. Connect
export KUBECONFIG=infrastructure/k3s/kubeconfig
kubectl get nodes

# 4. Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 5. Create cloudflared secret and connect to Cloudflare tunnel
kubectl create namespace cloudflared
kubectl create secret generic cloudflared-token --namespace cloudflared --from-literal=token=<token>

# 6. Point Argo CD at k3s-apps repo — everything else syncs automatically
```
