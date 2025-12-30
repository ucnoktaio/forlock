# Docker Swarm HA Deployment Guide

Deploy Forlock with high availability using Docker Swarm.

## Architecture

```
                    ┌─────────────────┐
                    │   Load Balancer │
                    │   (Nginx x N)   │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
┌────────┴────────┐ ┌────────┴────────┐ ┌────────┴────────┐
│  Manager Node   │ │  Worker Node 1  │ │  Worker Node 2  │
│  - Postgres     │ │  - API x1       │ │  - API x1       │
│  - Redis        │ │  - Frontend x1  │ │  - Frontend x1  │
│  - RabbitMQ     │ │  - Nginx        │ │  - Nginx        │
│  - API x1       │ │                 │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## Prerequisites

- Minimum 3 nodes (1 manager + 2 workers)
- Each node: 2 vCPU, 2 GB RAM
- Docker 24+ on all nodes
- Network connectivity between nodes
- Ports 2377, 7946, 4789 open between nodes

---

## Setup

### 1. Initialize Swarm (Manager Node)

```bash
# On manager node
docker swarm init --advertise-addr <MANAGER_IP>

# Save the join token
docker swarm join-token worker
```

### 2. Join Workers

```bash
# On each worker node
docker swarm join --token <TOKEN> <MANAGER_IP>:2377
```

### 3. Verify Cluster

```bash
# On manager
docker node ls
```

### 4. Clone Repository

```bash
# On manager
git clone https://github.com/ucnoktaio/forlock.git /opt/forlock
cd /opt/forlock
```

### 5. Create Secrets

```bash
./scripts/generate-secrets.sh --swarm
```

### 6. Create Domain Config

```bash
# Create .env for domain config (not secrets)
cat > .env << EOF
CORS_ALLOWED_ORIGINS=https://vault.yourcompany.com
FIDO2_DOMAIN=vault.yourcompany.com
FIDO2_SERVER_NAME=Forlock
FIDO2_ORIGIN=https://vault.yourcompany.com
JWT_ISSUER=forlock-api
JWT_AUDIENCE=forlock-clients
JWT_EXPIRATION_MINUTES=480
IMAGE_TAG=latest
EOF
```

### 7. Deploy Stack

```bash
docker stack deploy -c docker-compose.swarm.yml forlock
```

---

## Scaling Guide by User Count

### 5,000 Users (3 Nodes)

| Node | Role | Specs | Services |
|------|------|-------|----------|
| Node 1 | Manager | 8 vCPU, 32 GB | PostgreSQL, Redis, RabbitMQ |
| Node 2 | Worker | 8 vCPU, 16 GB | API x2, Frontend, Nginx |
| Node 3 | Worker | 8 vCPU, 16 GB | API x2, Frontend, Nginx |

**Total: 24 vCPU, 64 GB RAM**

```bash
# Scale services for 5K users
docker service scale forlock_api=4
docker service scale forlock_frontend=2
```

### 10,000 Users (5 Nodes)

| Node | Role | Specs | Services |
|------|------|-------|----------|
| Node 1 | Manager | 16 vCPU, 64 GB | PostgreSQL Primary |
| Node 2 | Manager | 8 vCPU, 16 GB | PostgreSQL Replica, Redis |
| Node 3 | Manager | 8 vCPU, 8 GB | RabbitMQ Cluster |
| Node 4 | Worker | 16 vCPU, 32 GB | API x3, Frontend x2, Nginx |
| Node 5 | Worker | 16 vCPU, 32 GB | API x3, Frontend x2, Nginx |

**Total: 64 vCPU, 152 GB RAM**

```bash
# Scale services for 10K users
docker service scale forlock_api=6
docker service scale forlock_frontend=4
```

### 20,000+ Users (7+ Nodes)

| Component | Nodes | Specs per Node |
|-----------|-------|----------------|
| PostgreSQL (Primary + Replicas) | 2 | 16 vCPU, 64 GB |
| Redis Cluster | 3 | 4 vCPU, 16 GB |
| RabbitMQ Cluster | 3 | 4 vCPU, 8 GB |
| API Workers | 4+ | 16 vCPU, 32 GB |

```bash
docker service scale forlock_api=12
docker service scale forlock_frontend=6
```

---

## Scaling Commands

### Scale API

```bash
# Scale to 6 replicas
docker service scale forlock_api=6

# Check status
docker service ls
```

### Scale Frontend

```bash
docker service scale forlock_frontend=4
```

---

## Management

### View Services

```bash
docker service ls
docker service ps forlock_api
```

### View Logs

```bash
# All API logs
docker service logs forlock_api -f

# From specific container
docker logs <container_id> --tail 100
```

### Rolling Update

```bash
# Update API image
docker service update --image ucnokta/forlock-api:v2.0 forlock_api

# Check rollout status
docker service inspect --pretty forlock_api
```

### Rollback

```bash
docker service rollback forlock_api
```

---

## Secrets Management

### List Secrets

```bash
docker secret ls
```

### Rotate a Secret

```bash
# Create new secret
echo "new-password" | docker secret create postgres_password_v2 -

# Update service
docker service update \
  --secret-rm postgres_password \
  --secret-add source=postgres_password_v2,target=postgres_password \
  forlock_api
```

---

## Networking

### Internal Network

- `backend` - Database services (internal only)
- `frontend` - Web services

### Ingress Mode

Nginx uses ingress mode for automatic load balancing:

```yaml
ports:
  - target: 80
    published: 80
    protocol: tcp
    mode: ingress
```

---

## Node Maintenance

### Drain Node

```bash
# Prevent new tasks
docker node update --availability drain <NODE>

# Perform maintenance...

# Re-enable
docker node update --availability active <NODE>
```

### Remove Node

```bash
# On worker
docker swarm leave

# On manager
docker node rm <NODE>
```

---

## Monitoring

### Health Check

```bash
./scripts/health-check.sh
```

### Resource Usage

```bash
# Per service
docker service inspect forlock_api --format '{{.Spec.Resources}}'

# Per container
docker stats
```

---

## Troubleshooting

### Service Not Starting

```bash
docker service ps forlock_api --no-trunc
docker service logs forlock_api --tail 100
```

### Secret Not Found

```bash
docker secret ls
docker secret inspect <secret_name>
```

### Network Issues

```bash
docker network ls
docker network inspect forlock_backend
```

### Manager Node Failure

If the only manager fails:
1. Promote a worker: `docker node promote <worker>`
2. Or reinitialize: `docker swarm init --force-new-cluster`

---

## Backup & Recovery

### Backup Swarm Config

```bash
# On manager
tar -cvf swarm-backup.tar /var/lib/docker/swarm
```

### Backup Database

```bash
docker exec $(docker ps -q -f name=forlock_postgres) \
  pg_dump -U forlock forlock | gzip > backup.sql.gz
```
