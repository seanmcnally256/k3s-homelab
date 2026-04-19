# k3s Homelab — Architecture

## Overview

A lightweight, production-minded k3s cluster running on Vagrant-managed VirtualBox VMs.
Primary goals: learning microservices security, container experimentation, and GitOps workflows.

## Cluster Topology

| Node         | Role          | IP        | CPUs | RAM |
|--------------|---------------|-----------|------|-----|
| k3s-control  | Control Plane | 10.0.0.10 | 2    | 2 GB |
| k3s-worker-1 | Worker        | 10.0.0.20 | 1    | 1 GB |
| k3s-worker-2 | Worker        | 10.0.0.21 | 1    | 1 GB |

All nodes run on a host-only network (`10.0.0.0/24`) with static IPs.
The host machine can reach all nodes directly; nodes can reach each other.
NAT (adapter 1) provides outbound internet access for package installs.

Resource defaults are defined in `infrastructure/vagrant/params.rb` and can be
adjusted before running `scripts/node-provision.sh`.

## Planned Stack

| Layer            | Choice                        | Notes                                   |
|------------------|-------------------------------|-----------------------------------------|
| VM Provisioner   | Vagrant + VirtualBox          | bento/ubuntu-22.04                      |
| Kubernetes       | k3s                           | Flannel and Traefik disabled at install |
| CNI              | Calico                        | Network policy + microsvc security      |
| Ingress          | Nginx                         | Industry standard                       |
| Storage          | OpenEBS Local PV              | Lightweight, no Mayastor                |
| Observability    | Alloy + Prometheus + Grafana  | Alloy as the collection layer           |
| GitOps           | Flux                          | Repo-driven, declarative                |
| Certificates     | cert-manager                  | TLS for ingress routes                  |
| Runtime Security | Falco                         | Phase 2 — after cluster is stable       |

## Bring-up Sequence

```
# 1. Provision VMs
./scripts/node-provision.sh

# 2. Install k3s across the cluster
./scripts/k3s-install.sh        # coming soon

# 3. Apply manifests in dependency order
#    networking → storage → observability → gitops → (security)
```

## Network Design

```
Host machine (Windows)
│
├── VirtualBox host-only adapter  192.168.56.1
│   ├── k3s-control   10.0.0.10
│   ├── k3s-worker-1  10.0.0.20
│   └── k3s-worker-2  10.0.0.21
│
└── NAT (internet access for all VMs via VirtualBox)
```
