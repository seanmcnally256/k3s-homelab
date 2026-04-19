# k3s Homelab

A k3s cluster running on AWS EC2, provisioned with Terraform and bootstrapped with k3sup.

Designed for learning: Kubernetes internals, CNI, GitOps workflows, and observability.

---

## Prerequisites

| Tool | Install |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | `winget install Hashicorp.Terraform` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | `winget install Kubernetes.kubectl` |
| [k3sup](https://github.com/alexellis/k3sup) | Download `k3sup.exe` and place in `~/bin` |
| AWS account + credentials | `aws configure` after installing the [AWS CLI](https://aws.amazon.com/cli/) |
| SSH key pair | `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa` |

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/your-username/k3s-homelab.git
cd k3s-homelab

# 2. Provision VMs
terraform -chdir=infrastructure/terraform init
terraform -chdir=infrastructure/terraform apply

# 3. Install k3s and Calico
./scripts/k3s-install.sh

# 4. Connect
export KUBECONFIG=infrastructure/k3s/kubeconfig
kubectl get nodes
```

No config files to edit — AWS credentials come from `~/.aws/credentials` (set via `aws configure`).

---

## Cluster Layout

3 EC2 instances (t3.small, Ubuntu 22.04, us-east-1):

| Node         | Role          | vCPU | RAM  |
|--------------|---------------|------|------|
| k3s-control  | Control Plane | 2    | 2 GB |
| k3s-worker-1 | Worker        | 2    | 2 GB |
| k3s-worker-2 | Worker        | 2    | 2 GB |

All nodes share a VPC (`10.0.0.0/16`) with public IPs for SSH/kubectl access.
Cluster-internal communication uses private IPs within the VPC.

---

## Customising

Sizing and region are controlled by variables in `infrastructure/terraform/variables.tf`:

```hcl
variable "region"                { default = "us-east-1" }
variable "control_instance_type" { default = "t3.small" }
variable "worker_instance_type"  { default = "t3.small" }
variable "worker_count"          { default = 2 }
```

Override any of them by creating a `terraform.tfvars` file (gitignored):

```hcl
worker_count = 1
```

---

## Repository Structure

```
k3s-homelab/
├── infrastructure/
│   ├── cloud-init.yaml        Guest OS bootstrap — kernel config, swap off
│   ├── terraform/
│   │   ├── main.tf            VPC, subnet, internet gateway, security group
│   │   ├── compute.tf         Control plane + worker EC2 instances
│   │   ├── variables.tf       All input variables with defaults
│   │   └── outputs.tf         Public/private IPs
│   └── k3s/                   kubeconfig written here after install (gitignored)
├── scripts/
│   └── k3s-install.sh         Bootstrap k3s across all nodes, then install Calico
├── manifests/
│   ├── networking/            Nginx ingress, cert-manager
│   ├── storage/               OpenEBS
│   ├── observability/         Alloy, Prometheus, Grafana
│   └── gitops/                Flux
└── docs/
    └── architecture.md
```

---

## Roadmap

- [x] Infrastructure provisioning (Terraform + AWS)
- [x] VM bootstrap (cloud-init)
- [x] k3s install — control plane + workers (k3sup)
- [x] CNI — Calico
- [ ] Ingress — Nginx + cert-manager
- [ ] Storage — OpenEBS
- [ ] Observability — Alloy + Prometheus + Grafana
- [ ] GitOps — Flux

---

## Troubleshooting

**`k3s-install.sh` can't SSH into nodes**
Ensure your private key is at `~/.ssh/id_rsa`, or set `SSH_KEY=/path/to/key` before running the script.

**Nodes stuck `NotReady`**
Calico is applied automatically by `k3s-install.sh`. If it times out, run:
```bash
export KUBECONFIG=infrastructure/k3s/kubeconfig
kubectl get pods -n kube-system
```
