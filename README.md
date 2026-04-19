# k3s Homelab

A k3s cluster running on AWS EC2, provisioned with Terraform and bootstrapped with k3sup.

Designed for learning: Kubernetes internals, CNI, GitOps workflows, and observability.

---

## Prerequisites

Install the following tools before starting:

**Terraform**
```bash
winget install Hashicorp.Terraform
```

**kubectl**
```bash
winget install Kubernetes.kubectl
```

**AWS CLI**
```bash
winget install Amazon.AWSCLI
```

**k3sup** — download the binary and place it on your PATH:
```bash
# Download k3sup.exe from https://github.com/alexellis/k3sup/releases/latest
# Then move it to ~/bin (or any directory on your PATH)
mv ~/Downloads/k3sup.exe ~/bin/k3sup.exe
```

**SSH key pair** — skip if you already have one at `~/.ssh/id_rsa`:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

---

## 1. Create an AWS Account

1. Go to [aws.amazon.com](https://aws.amazon.com) and create a free account
2. Once logged in, go to **IAM → Users → Create user**
3. Give the user **AdministratorAccess** (or a scoped policy with EC2/VPC permissions)
4. Under the user, go to **Security credentials → Create access key** — choose "CLI"
5. Save the **Access Key ID** and **Secret Access Key**

Then configure the AWS CLI with those credentials:

```bash
aws configure
# AWS Access Key ID: <your access key>
# AWS Secret Access Key: <your secret key>
# Default region name: us-east-1
# Default output format: json
```

This writes credentials to `~/.aws/credentials` — Terraform reads them automatically.

---

## 2. Provision Infrastructure

Clone the repo and initialise Terraform:

```bash
git clone https://github.com/your-username/k3s-homelab.git
cd k3s-homelab

terraform -chdir=infrastructure/terraform init
```

Preview what will be created:

```bash
terraform -chdir=infrastructure/terraform plan
```

Apply — this creates the VPC, subnet, security group, and 3 EC2 instances:

```bash
terraform -chdir=infrastructure/terraform apply
```

Type `yes` when prompted. Takes ~1 minute. When complete, Terraform prints the node IPs:

```
control_public_ip  = "x.x.x.x"
worker_public_ips  = ["x.x.x.x", "x.x.x.x"]
```

---

## 3. Bootstrap k3s

Run the install script — it reads the IPs from Terraform, installs k3s on all nodes via k3sup, then installs Calico CNI:

```bash
./scripts/k3s-install.sh
```

When complete, all nodes should show `Ready`.

---

## 4. Connect with kubectl

```bash
export KUBECONFIG=infrastructure/k3s/kubeconfig
kubectl get nodes
```

Expected output:

```
NAME           STATUS   ROLES           AGE   VERSION
k3s-control    Ready    control-plane   2m    v1.34.x+k3s1
k3s-worker-1   Ready    <none>          2m    v1.34.x+k3s1
k3s-worker-2   Ready    <none>          2m    v1.34.x+k3s1
```

---

## 5. Tear Down

To destroy all AWS resources:

```bash
terraform -chdir=infrastructure/terraform destroy
```

Type `yes` when prompted. All EC2 instances, networking, and security groups are removed.

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
region       = "us-west-2"
```

---

## Repository Structure

```
k3s-homelab/
├── infrastructure/
│   ├── cloud-init/
│   │   └── cloud-init.yaml    Guest OS bootstrap — kernel config, swap off
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
Ensure your private key is at `~/.ssh/id_rsa`, or set `SSH_KEY=/path/to/key` before running:
```bash
SSH_KEY=~/.ssh/my_key ./scripts/k3s-install.sh
```

**Nodes stuck `NotReady`**
Calico is applied automatically by `k3s-install.sh`. If it times out, check pod status:
```bash
export KUBECONFIG=infrastructure/k3s/kubeconfig
kubectl get pods -n kube-system
```
