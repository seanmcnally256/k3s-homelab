# Sean's k3s Lab

A k3s cluster running on AWS EC2, provisioned with Terraform and bootstrapped with k3sup. Serves as a playground for learning Kubernetes, Terraform, cloud-init, CNI, GitOps, observability, and more.

---

## Repositories

| Repo | Purpose |
|------|---------|
| [k3s-homelab](https://github.com/seanmcnally256/k3s-homelab) | Infrastructure — Terraform, cloud-init, bootstrap scripts |
| [k3s-apps](https://github.com/seanmcnally256/k3s-apps) | Cluster apps — manifests and Helm values managed by Argo CD |
| [www-seancloud](https://github.com/seanmcnally256/www-seancloud) | Website — HTML/CSS, Dockerfile, GitHub Actions |

---

## Prerequisites

Install the below tools before starting. Written for Git Bash on Windows — adjust paths for Mac/Linux.

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

**k3sup** — download from https://github.com/alexellis/k3sup/releases/latest and place on your PATH:
```bash
mv ~/Downloads/k3sup.exe ~/bin/k3sup.exe
```

**cloudflared** — download from https://github.com/cloudflare/cloudflared/releases/latest and place on your PATH:
```bash
mv ~/Downloads/cloudflared-windows-amd64.exe ~/bin/cloudflared.exe
```

**SSH key pair** — skip if you already have one at `~/.ssh/id_rsa`:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

You can check and install all prerequisites automatically:

```bash
./scripts/prereqs.sh
```

---

## 1. AWS Setup

1. Go to [aws.amazon.com](https://aws.amazon.com) and create an account
2. Go to **IAM → Users → Create user** and attach **AdministratorAccess**
3. Under the user go to **Security credentials → Create access key** and save the key ID and secret

Configure the AWS CLI:
```bash
aws configure
# AWS Access Key ID:     <your access key>
# AWS Secret Access Key: <your secret key>
# Default region name:   us-east-1
# Default output format: json
```

---

## 2. Cloudflare Setup

1. Register a domain at [cloudflare.com](https://cloudflare.com) — or transfer an existing one
2. Go to **Zero Trust → Networks → Tunnels → Create a tunnel**, name it and save
3. Copy the tunnel token shown on the next page
4. Run the following to register DNS entries for your subdomains:
```bash
cloudflared tunnel login
cloudflared tunnel route dns <tunnel-name> argo.yourdomain.com
cloudflared tunnel route dns <tunnel-name> www.yourdomain.com
cloudflared tunnel route dns <tunnel-name> headlamp.yourdomain.com
cloudflared tunnel route dns <tunnel-name> falco.yourdomain.com
```

Point each public hostname at:
```
http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
```

---

## 3. Provision Infrastructure

Clone this repo and initialise Terraform:

```bash
git clone https://github.com/seanmcnally256/k3s-homelab.git
cd k3s-homelab

terraform -chdir=infrastructure/terraform init
terraform -chdir=infrastructure/terraform apply
```

Type `yes` when prompted. Takes ~1 minute. Terraform prints the node IPs when complete.

---

## 4. Bootstrap k3s

Reads node IPs from Terraform, installs k3s via k3sup, joins all workers, and installs Calico CNI:

```bash
./scripts/k3s-bootstrap.sh
```

Verify the cluster:

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
k3s-worker-3   Ready    <none>          2m    v1.34.x+k3s1
```

---

## 5. Bootstrap Apps

Installs Argo CD, Nginx Ingress, and Cloudflare Tunnel. Then deploys all apps via the App of Apps pattern:

```bash
export KUBECONFIG=infrastructure/k3s/kubeconfig
./scripts/apps-bootstrap.sh
```

The script prompts for:
- Cloudflare tunnel token
- Argo CD hostname
- Path to your local k3s-apps repo

When complete the script prints your Argo CD URL and login credentials. Argo CD will automatically sync and deploy all apps defined in `k3s-apps/argoapps/`.

---

## 6. Headlamp Auth Token

Generate a token to log into Headlamp:

```bash
kubectl create serviceaccount headlamp-admin -n headlamp
kubectl create clusterrolebinding headlamp-user-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=headlamp:headlamp-admin
kubectl create token headlamp-admin -n headlamp --duration=8760h
```

---

## Tear Down

```bash
terraform -chdir=infrastructure/terraform destroy
rm infrastructure/k3s/kubeconfig
```

All AWS resources are removed. Cloudflare tunnel, DNS records, and app definitions in k3s-apps persist and will reconnect on the next rebuild.

---

## Customising

Override any variable by creating a `terraform.tfvars` file (gitignored):

```hcl
region                = "us-west-2"
worker_count          = 3
control_instance_type = "t3.small"
worker_instance_type  = "t3.small"
```

---

## Repository Structure

```
k3s-homelab/
├── infrastructure/
│   ├── cloud-init/
│   │   └── cloud-init.yaml       Guest OS bootstrap — kernel config, swap off
│   ├── terraform/
│   │   ├── main.tf               VPC, subnet, internet gateway, security group
│   │   ├── compute.tf            Control plane + worker EC2 instances
│   │   ├── variables.tf          Input variables with defaults
│   │   ├── outputs.tf            Public/private IPs
│   │   └── terraform.tfvars.example
│   └── k3s/                      kubeconfig written here after bootstrap (gitignored)
├── scripts/
│   ├── prereqs.sh                Check and install all prerequisites
│   ├── k3s-bootstrap.sh          Install k3s across all nodes + Calico CNI
│   └── apps-bootstrap.sh         Install Argo CD, Nginx Ingress, Cloudflare Tunnel + root app
└── docs/
    └── architecture.md
```

---

## Troubleshooting

**`k3s-bootstrap.sh` can't SSH into nodes**
```bash
SSH_KEY=~/.ssh/my_key ./scripts/k3s-bootstrap.sh
```

**Nodes stuck `NotReady`**
```bash
kubectl get pods -n kube-system
```

**Argo CD not reachable after bootstrap**
Check the cloudflared tunnel is connected:
```bash
kubectl logs -n cloudflared deployment/cloudflared | tail -10
```

**Headlamp shows no permissions**
The `headlamp-admin` clusterrolebinding may have been overwritten by Helm. Recreate it:
```bash
kubectl create clusterrolebinding headlamp-user-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=headlamp:headlamp-admin \
  --dry-run=client -o yaml | kubectl apply -f -
```
