# Nginx Ingress Controller

Routes external HTTP/HTTPS traffic into the cluster. Required before any in-cluster UI can be reached from a browser.

## Install

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

## Verify

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

The `ingress-nginx-controller` service will have an `EXTERNAL-IP` — this is the public address traffic enters through.

## How it works

Once installed, any `Ingress` resource you create in the cluster is picked up by the Nginx controller and translated into routing rules. For example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: my-app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

Requests to `my-app.example.com` hit the Nginx controller, which forwards them to the `my-app` service inside the cluster.
