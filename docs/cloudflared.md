# Cloudflare Tunnel

Routes external traffic into the cluster without opening any ports or exposing public IPs.
Cloudflare handles TLS at the edge — everything inside the cluster runs plain HTTP.

## Prerequisites

- Domain registered and managed by Cloudflare
- `cloudflared` binary installed locally (used once to register DNS)

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe -o ~/bin/cloudflared.exe
```

## Create the Tunnel

1. Go to **Cloudflare → Zero Trust → Networks → Tunnels → Create a tunnel**
2. Name it `k3s-homelab` and save
3. Copy the token shown on the next screen

## Deploy to Kubernetes

```bash
kubectl create namespace cloudflared

kubectl create secret generic cloudflared-token \
  --namespace cloudflared \
  --from-literal=token=<your-token>

kubectl apply -f manifests/networking/cloudflared/deployment.yaml
```

Verify the tunnel is connected:

```bash
kubectl logs -n cloudflared deployment/cloudflared | tail -20
```

Look for `Registered tunnel connection` — should show 4 connections.

## Register DNS

```bash
cloudflared tunnel login
cloudflared tunnel route dns k3s-homelab <subdomain.yourdomain.com>
```

This creates the CNAME record in Cloudflare DNS pointing to your tunnel.

## Add a Public Hostname

For each service you want to expose, go to:
**Zero Trust → Networks → Tunnels → k3s-homelab → Configure → Public Hostnames → Add**

- **Subdomain**: `argo`
- **Domain**: `seancloud.org`
- **Service Type**: `HTTP`
- **URL**: `argocd-server.argocd.svc.cluster.local:80`

## Expose Additional Services

To expose a new service, just add another public hostname in the Cloudflare dashboard and register its DNS:

```bash
cloudflared tunnel route dns k3s-homelab newservice.seancloud.org
```

No redeployment needed — the tunnel picks up new routes automatically.
