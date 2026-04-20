# Sean's k3s Lab

Follow along as I deploy a k3s cluster running on AWS EC2. This cluster serves as my playground for learning Kubernetes, Terraform, cloud-init, CNI, GitOps, Grafana, and more.

---

## Prerequisites

Install the below tools before starting. I personally am using a Git Bash terminal in VS Code from my Windows laptop. You may need to tailor to your current setup, but the overall prerequisites are the same:

**Terraform**:
```bash
winget install Hashicorp.Terraform
```

**kubectl**:
```bash
winget install Kubernetes.kubectl
```

**AWS CLI**:
```bash
winget install Amazon.AWSCLI
```

**Helm**:
```bash
winget install Helm.Helm
```

**k3sup** - download from https://github.com/alexellis/k3sup/releases/latest and place it on your PATH:
```bash
mv ~/Downloads/k3sup.exe ~/bin/k3sup.exe
```

**SSH key pair** - skip if you already have one at `~/.ssh/id_rsa`:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

---

## 1. Create an AWS Account

1. Go to [aws.amazon.com](https://aws.amazon.com) and create a free account.
4. Under the user, go to **Security credentials → Create access key**.
5. Save the **Access Key ID** and **Secret Access Key**.

Then configure the AWS CLI with those credentials:

```bash
aws configure
# AWS Access Key ID: <your access key>
# AWS Secret Access Key: <your secret key>
# Default region name: <your region (e.g. us-east-1)>
# Default output format: json
```

This writes credentials to `~/.aws/credentials`, Terraform reads them automatically.

---

## 2. Provision Infrastructure

Clone this repo and initialize Terraform:

```bash
git clone https://github.com/seanmcnally256/k3s-homelab.git
cd k3s-homelab

terraform -chdir=infrastructure/terraform init
```

Or, preview what will be created first:

```bash
terraform -chdir=infrastructure/terraform plan
```

Apply - this creates the VPC, subnet, security group, and 3 EC2 instances:

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

Run the install script - it reads the IPs from Terraform, installs k3s on all nodes via k3sup and installs Calico CNI:

```bash
./scripts/k3s-bootstrap.sh
```



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

## Customizing

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
│   └── k3s-bootstrap.sh         Bootstrap k3s across all nodes, then install Calico
├── manifests/
│   ├── networking/            Nginx ingress, cert-manager
│   ├── storage/               OpenEBS
│   ├── observability/         Alloy, Prometheus, Grafana
│   └── gitops/                Flux
└── docs/
    └── architecture.md
```

---

## Troubleshooting

**`k3s-bootstrap.sh` can't SSH into nodes**
Ensure your private key is at `~/.ssh/id_rsa`, or set `SSH_KEY=/path/to/key` before running:
```bash
SSH_KEY=~/.ssh/my_key ./scripts/k3s-bootstrap.sh
```

**Nodes stuck `NotReady`**
Calico is applied automatically by `k3s-bootstrap.sh`. If it times out, check pod status:
```bash
export KUBECONFIG=infrastructure/k3s/kubeconfig
kubectl get pods -n kube-system
```
