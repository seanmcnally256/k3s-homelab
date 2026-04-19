# k3s Homelab

A self-contained k3s cluster running on local VirtualBox VMs, provisioned with Vagrant.
Clone the repo, run one script, and have a 3-node Kubernetes cluster on your machine.

Designed for learning: microservices security, CNI internals, GitOps workflows, and observability.

---

## Prerequisites

| Tool | Version tested | Install |
|------|---------------|---------|
| [VirtualBox](https://www.virtualbox.org/wiki/Downloads) | 7.2 | — |
| [Vagrant](https://developer.hashicorp.com/vagrant/downloads) | 2.4 | — |
| [Windows ADK – Deployment Tools](https://go.microsoft.com/fwlink/?linkid=2196127) | any | Required for cloud-init ISO generation (`oscdimg.exe`). After installing, add the Deployment Tools directory to your `PATH` (not the `.exe` itself). |

> **Linux / macOS hosts:** `oscdimg` is Windows-only. Replace the cloud-init ISO step with `genisoimage` or use the `vagrant-cloud-init` plugin. Native support is on the roadmap.

---

## Quick Start

```bash
git clone https://github.com/your-username/k3s-homelab.git
cd k3s-homelab
./scripts/node-provision.sh
```

That's it. The script runs preflight checks and brings up all 3 VMs sequentially.
Expect ~5–10 minutes on first run (box download + boot).

### SSH into a node

```bash
vagrant ssh k3s-control
vagrant ssh k3s-worker-1
vagrant ssh k3s-worker-2
```

### Tear everything down

```bash
vagrant destroy -f
```

---

## Cluster Layout

| Node         | Role          | IP        | CPUs | RAM  |
|--------------|---------------|-----------|------|------|
| k3s-control  | Control Plane | 10.0.0.10 | 2    | 2 GB |
| k3s-worker-1 | Worker        | 10.0.0.20 | 1    | 1 GB |
| k3s-worker-2 | Worker        | 10.0.0.21 | 1    | 1 GB |

All nodes share a host-only network (`10.0.0.0/24`). NAT is added automatically by
Vagrant so each VM can reach the internet for package installs.

---

## Customising the Cluster

All tuneable parameters live in **`infrastructure/vagrant/params.rb`**:

```ruby
CLUSTER = {
  box:      "bento/ubuntu-22.04",   # Vagrant box for all nodes
  vb_group: "/k3s-homelab",         # VirtualBox GUI group name

  control: {
    count:    1,          # number of control-plane nodes
    cpus:     2,
    memory:   2048,       # MB
    ip_start: "10.0.0.10",
  },

  workers: {
    count:    2,          # number of worker nodes
    cpus:     1,
    memory:   1024,       # MB
    ip_start: "10.0.0.20",
  },
}
```

Edit this file before running `node-provision.sh`. No changes needed in the Vagrantfile itself.

---

## Repository Structure

```
k3s-homelab/
├── Vagrantfile                        VM definitions — reads from params.rb
├── infrastructure/
│   └── vagrant/
│       ├── params.rb                  Cluster topology and resource config
│       └── cloud-init.yaml            Guest OS bootstrap (packages, timezone)
├── scripts/
│   ├── node-provision.sh              Step 1 — preflight checks + vagrant up
│   └── k3s-install.sh                 Step 2 — k3s install across all nodes (coming soon)
├── manifests/
│   ├── networking/                    Calico, Nginx ingress, cert-manager
│   ├── storage/                       OpenEBS Local PV
│   ├── observability/                 Alloy, Prometheus, Grafana
│   ├── gitops/                        Flux configuration
│   └── security/                      Falco (phase 2)
├── apps/                              Experimental workloads
└── docs/
    └── architecture.md                Deeper architecture notes and network diagram
```

---

## Bring-up Roadmap

- [x] VM provisioning (`node-provision.sh`)
- [ ] k3s install — control plane + workers (`k3s-install.sh`)
- [ ] CNI — Calico
- [ ] Ingress — Nginx + cert-manager
- [ ] Storage — OpenEBS
- [ ] Observability — Alloy + Prometheus + Grafana
- [ ] GitOps — Flux
- [ ] Runtime security — Falco

---

## Troubleshooting

**VM times out on boot**
VMs are brought up sequentially (`--no-parallel`) to avoid resource contention.
If a timeout still occurs, try running `vagrant up <node-name>` for just the failed node.

**`oscdimg` not found**
Install the Windows ADK Deployment Tools and add the directory containing `oscdimg.exe` to
your `PATH` (e.g. `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg`).

**Guest Additions version mismatch warning**
Safe to ignore. Shared folders are not used by this setup.
