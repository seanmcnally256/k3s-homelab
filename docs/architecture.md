# k3s Homelab Architecture

## Overview
A lightweight, production-minded k3s cluster running on Multipass VMs.
Primary goal: learning microservices security, container experimentation, and GitOps workflows.

## Cluster Topology

| Node          | Role          | CPUs | RAM  |
|---------------|---------------|------|------|
| k3s-control   | Control Plane | 2    | 2GB  |
| k3s-worker-1  | Worker        | 2    | 2GB  |
| k3s-worker-2  | Worker        | 2    | 2GB  |

## Stack

| Layer            | Choice                       | Notes                            |
|------------------|------------------------------|----------------------------------|
| Provisioner      | Multipass                    | Ubuntu 22.04 VMs                 |
| Kubernetes       | k3s                          | Bundled CNI and ingress disabled |
| CNI              | Calico                       | Network policy, microsvc security|
| Ingress          | Nginx                        | Industry standard                |
| Storage          | OpenEBS Local PV             | Lightweight, no Mayastor         |
| Observability    | Alloy + Prometheus + Grafana | Alloy as collection layer        |
| GitOps           | Flux                         | Repo-driven, declarative         |
| Certificates     | cert-manager                 | TLS for ingress                  |
| Runtime Security | Falco                        | Added after cluster is stable    |

## Repo Structure

- docs/                       Architecture and runbooks
- infrastructure/multipass/   VM provisioning scripts
- infrastructure/k3s/         k3s install configs
- manifests/networking/       Calico, Nginx, cert-manager
- manifests/storage/          OpenEBS
- manifests/observability/    Alloy, Prometheus, Grafana
- manifests/gitops/           Flux configs
- manifests/security/         Falco (phase 2)
- apps/                       Experimental deployments
