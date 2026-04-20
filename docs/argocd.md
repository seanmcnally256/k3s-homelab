# Argo CD

GitOps continuous delivery tool. Watches a Git repo and syncs the cluster to match what's in it.

## Install

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Watch pods come up:

```bash
kubectl get pods -n argocd -w
```

## Configure for Cloudflare Tunnel

Argo CD serves HTTPS by default which conflicts with Cloudflare's tunnel (which handles TLS at the edge).
Patch the server to run in insecure (plain HTTP) mode:

```bash
kubectl patch deployment argocd-server -n argocd \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--insecure"}]'
```

## Access

URL: `https://argo.seancloud.org`

Get the initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

Login with username `admin` and the password above.

## How it works

Once logged in, you define **Applications** that point to a Git repo and a path within it.
Argo CD watches that path and syncs any changes to the cluster automatically.

Instead of running `kubectl apply` by hand, you commit manifests to Git and Argo CD does the rest.
