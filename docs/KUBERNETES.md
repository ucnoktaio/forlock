# Kubernetes Deployment Guide

Deploy Forlock on Kubernetes for enterprise-scale deployments.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                     │
├──────────────────────────────────────────────────────────┤
│                                                          │
│   ┌────────────┐                                         │
│   │  Ingress   │ ← External traffic (HTTPS)              │
│   └─────┬──────┘                                         │
│         │                                                │
│   ┌─────┴──────┐                                         │
│   │   Nginx    │ (Optional - or use Ingress directly)   │
│   │ Deployment │                                         │
│   └─────┬──────┘                                         │
│         │                                                │
│   ┌─────┴──────────────────────┐                         │
│   │                            │                         │
│   │  ┌──────────┐  ┌──────────┐│                         │
│   │  │   API    │  │ Frontend ││                         │
│   │  │ Replicas │  │ Replicas ││                         │
│   │  │   (3)    │  │   (2)    ││                         │
│   │  └────┬─────┘  └──────────┘│                         │
│   │       │                    │                         │
│   │  ┌────┴───────────────────────────────┐              │
│   │  │     StatefulSets (Internal)        │              │
│   │  │  ┌──────────┐┌─────┐┌──────────┐   │              │
│   │  │  │PostgreSQL││Redis││ RabbitMQ │   │              │
│   │  │  └──────────┘└─────┘└──────────┘   │              │
│   │  └────────────────────────────────────┘              │
│   └────────────────────────────────────────┘             │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Prerequisites

| Component | Requirement |
|-----------|-------------|
| Kubernetes | 1.25+ |
| kubectl | Configured |
| Storage | Dynamic provisioner (e.g., AWS EBS, GCE PD) |
| Ingress | nginx-ingress or cloud provider |
| cert-manager | Optional (for Let's Encrypt) |

---

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/ucnoktaio/forlock.git
cd forlock
```

### 2. Create Namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

### 3. Create Docker Registry Secret

```bash
kubectl create secret docker-registry forlock-registry \
  --docker-server=docker.io \
  --docker-username=ucnokta \
  --docker-password=<ACCESS_TOKEN> \
  -n forlock
```

### 4. Create Secrets

```bash
./scripts/generate-secrets.sh --k8s
```

### 5. Update ConfigMap

Edit `k8s/configmap.yaml` with your domain:

```yaml
data:
  DOMAIN: "vault.yourcompany.com"
  CORS_ALLOWED_ORIGINS: "https://vault.yourcompany.com"
  FIDO2_DOMAIN: "vault.yourcompany.com"
  FIDO2_ORIGIN: "https://vault.yourcompany.com"
```

```bash
kubectl apply -f k8s/configmap.yaml
```

### 6. Update Ingress

Edit `k8s/ingress.yaml`:

```yaml
spec:
  tls:
    - hosts:
        - vault.yourcompany.com
      secretName: forlock-tls
  rules:
    - host: vault.yourcompany.com
```

### 7. Deploy

```bash
kubectl apply -f k8s/
```

### 8. Verify

```bash
kubectl get all -n forlock
kubectl get ingress -n forlock
```

---

## SSL/TLS with cert-manager

### Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### Create ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourcompany.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

```bash
kubectl apply -f cluster-issuer.yaml
```

The Ingress annotation `cert-manager.io/cluster-issuer: "letsencrypt-prod"` will auto-generate certificates.

---

## Scaling

### Manual Scaling

```bash
# Scale API
kubectl scale deployment api --replicas=6 -n forlock

# Scale Frontend
kubectl scale deployment frontend --replicas=4 -n forlock
```

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: forlock
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

```bash
kubectl apply -f api-hpa.yaml
```

---

## Monitoring

### Logs

```bash
# All API pods
kubectl logs -l app.kubernetes.io/component=api -n forlock -f

# Specific pod
kubectl logs api-xxxxx -n forlock
```

### Resource Usage

```bash
kubectl top pods -n forlock
kubectl top nodes
```

### Events

```bash
kubectl get events -n forlock --sort-by='.lastTimestamp'
```

---

## Troubleshooting

### Pod Not Starting

```bash
kubectl describe pod <pod-name> -n forlock
kubectl logs <pod-name> -n forlock --previous
```

### Service Not Reachable

```bash
kubectl get svc -n forlock
kubectl get endpoints -n forlock
```

### Ingress Issues

```bash
kubectl describe ingress forlock-ingress -n forlock
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Storage Issues

```bash
kubectl get pvc -n forlock
kubectl describe pvc postgres-data-postgres-0 -n forlock
```

---

## Backup & Restore

### Database Backup

```bash
# Create backup pod
kubectl run backup --rm -it --restart=Never \
  --image=postgres:15-alpine \
  -n forlock \
  -- pg_dump -h postgres -U forlock forlock > backup.sql
```

### Restore

```bash
kubectl run restore --rm -it --restart=Never \
  --image=postgres:15-alpine \
  -n forlock \
  -- psql -h postgres -U forlock forlock < backup.sql
```

---

## Cloud-Specific Notes

### AWS EKS

```yaml
# Use gp3 storage class
storageClassName: gp3

# Use ALB Ingress
annotations:
  kubernetes.io/ingress.class: alb
  alb.ingress.kubernetes.io/scheme: internet-facing
```

### GKE

```yaml
# Use standard storage
storageClassName: standard

# Use GKE Ingress
annotations:
  kubernetes.io/ingress.class: gce
```

### Azure AKS

```yaml
# Use managed-premium storage
storageClassName: managed-premium

# Use Azure Application Gateway
annotations:
  kubernetes.io/ingress.class: azure/application-gateway
```

---

## Cleanup

```bash
# Delete all resources
kubectl delete -f k8s/

# Delete namespace
kubectl delete namespace forlock

# Delete PVCs (data will be lost!)
kubectl delete pvc --all -n forlock
```
