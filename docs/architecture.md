# k3s Homelab — Architecture

## Overview

A lightweight k3s cluster running on AWS EC2, provisioned with Terraform and bootstrapped
with k3sup. All cluster apps are managed by Argo CD via GitOps.

## Repositories

| Repo | Purpose |
|------|---------|
| [k3s-homelab](https://github.com/seanmcnally256/k3s-homelab) | Infrastructure — Terraform, cloud-init, bootstrap scripts |
| [k3s-apps](https://github.com/seanmcnally256/k3s-apps) | Cluster apps — manifests and Helm values managed by Argo CD |
| [www-seancloud](https://github.com/seanmcnally256/www-seancloud) | Website — HTML/CSS, Dockerfile, GitHub Actions |

## Cluster Topology

| Node         | Role          | Instance  | vCPU | RAM  |
|--------------|---------------|-----------|------|------|
| k3s-control  | Control Plane | t3.small  | 2    | 2 GB |
| k3s-worker-1 | Worker        | t3.small  | 2    | 2 GB |
| k3s-worker-2 | Worker        | t3.small  | 2    | 2 GB |
| k3s-worker-3 | Worker        | t3.small  | 2    | 2 GB |

Worker count is configurable via `worker_count` in `terraform.tfvars`.
Public IPs are assigned by AWS and used for SSH and kubectl.
Cluster-internal traffic uses private IPs within the VPC.

## Network Design

```
Browser
  │
  └── Cloudflare Edge (TLS termination)
        │
        └── Cloudflare Tunnel (outbound from cluster, no open ports)
              │
              └── cloudflared pod
                    │
                    └── Nginx Ingress Controller
                          │
                          ├── argo.seancloud.org     → argocd-server
                          ├── www.seancloud.org      → www deployment
                          ├── headlamp.seancloud.org → headlamp
                          ├── falco.seancloud.org    → falcosidekick UI
                          └── *.seancloud.org        → any service with an Ingress

Your laptop
  │
  ├── SSH (port 22)        → node access
  └── kubectl (port 6443)  → k3s API server
```

## Security

| Layer   | Control |
|---------|---------|
| Network | AWS security group — SSH (22), kubectl (6443), all internal VPC traffic only |
| SSH     | Key-only auth (`ssh_pwauth: false`), root login disabled |
| Ingress | Ports 80/443 closed — all web traffic flows through Cloudflare Tunnel |
| TLS     | Handled by Cloudflare at the edge — no cert management needed in cluster |
| Runtime | Falco watches syscalls on every node, alerts via falcosidekick UI |

## Current Stack

| Layer         | Choice                          |
|---------------|---------------------------------|
| Infra         | Terraform + AWS EC2             |
| Kubernetes    | k3s                             |
| CNI           | Calico                          |
| Ingress       | Nginx Ingress Controller        |
| Tunnel        | Cloudflare Tunnel (cloudflared) |
| GitOps        | Argo CD                         |
| Cluster UI    | Headlamp                        |
| Runtime Security | Falco + falcosidekick UI     |

## GitOps Model

Argo CD uses an App of Apps pattern. One root application watches `argoapps/` in k3s-apps.
Every yaml file in that folder is an Argo CD Application. Adding a new app to the cluster
means adding a yaml to `argoapps/` and pushing to git — no UI interaction needed.

```
root-app (watches argoapps/)
  ├── ingress-nginx.yaml
  ├── cloudflared.yaml
  ├── headlamp.yaml
  ├── falco.yaml
  └── www.yaml
```

## k3s-apps Structure

```
k3s-apps/
├── argoapps/        Argo CD Application definitions (one per app)
├── bootstrap/       root-app.yaml — applied once after cluster bootstrap
├── cloudflared/     Cloudflare Tunnel deployment manifest
├── falco/           Falco Helm values
├── headlamp/        Headlamp Helm values
├── ingress-nginx/   Nginx Ingress Helm values
├── prometheus/      Prometheus + Grafana values (parked — not deployed)
└── www/             Website Kubernetes manifests
```

## Bootstrap Sequence

```bash
# 1. Provision AWS infrastructure
terraform -chdir=infrastructure/terraform apply

# 2. Install k3s + Calico across all nodes
./scripts/k3s-bootstrap.sh

# 3. Verify cluster
export KUBECONFIG=infrastructure/k3s/kubeconfig
kubectl get nodes

# 4. Install Argo CD, Nginx Ingress, Cloudflare Tunnel + deploy all apps
./scripts/apps-bootstrap.sh
# (prompts for Cloudflare token, Argo CD hostname, and k3s-apps repo path)
```

## Teardown and Rebuild

The cluster is fully reproducible. On teardown:
- AWS resources are destroyed (`terraform destroy`)
- Cloudflare tunnel, DNS records, and public hostnames persist
- All app definitions persist in `k3s-apps` repo

On rebuild, run the same 4 commands above and Argo CD restores all apps automatically.

## Planned

- Prometheus + Grafana — cluster observability (requires upsizing to t3.medium)
- OpenEBS — persistent storage
