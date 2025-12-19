# Deployment Guide

This guide provides step-by-step instructions for deploying the Mobile Banking Platform to both Google Kubernetes Engine (GKE) and Amazon Elastic Kubernetes Service (EKS).

## Prerequisites

### Tools Required

| Tool | Version | Purpose |
|------|---------|---------|
| kubectl | 1.28+ | Kubernetes CLI |
| Helm | 3.12+ | Kubernetes package manager |
| Terraform | 1.5+ | Infrastructure as Code |
| gcloud CLI | Latest | GCP management (for GKE) |
| AWS CLI | 2.x | AWS management (for EKS) |
| Docker | 24+ | Container builds |

### Access Requirements

**For GKE:**
- GCP Project with billing enabled
- IAM permissions: Kubernetes Engine Admin, Compute Admin, Service Account Admin
- Service account key for Terraform

**For EKS:**
- AWS Account with appropriate permissions
- IAM user/role with EKS, EC2, VPC, and IAM permissions
- AWS credentials configured

## Infrastructure Provisioning

### GKE Cluster Setup

1. **Configure GCP credentials:**
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
```

2. **Initialize Terraform:**
```bash
cd terraform/environments/dev
terraform init
```

3. **Review the plan:**
```bash
terraform plan \
  -var="gcp_project_id=YOUR_PROJECT_ID" \
  -var="gcp_region=us-central1"
```

4. **Apply infrastructure:**
```bash
terraform apply \
  -var="gcp_project_id=YOUR_PROJECT_ID" \
  -var="gcp_region=us-central1"
```

5. **Configure kubectl:**
```bash
gcloud container clusters get-credentials mobile-banking-dev \
  --region us-central1 \
  --project YOUR_PROJECT_ID
```

### EKS Cluster Setup

1. **Configure AWS credentials:**
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region
```

2. **Modify Terraform configuration:**

Edit `terraform/environments/dev/main.tf` to use EKS module:
```hcl
module "vpc" {
  source = "../../modules/vpc-aws"
  
  vpc_name     = "mobile-banking-dev-vpc"
  vpc_cidr     = "10.0.0.0/16"
  cluster_name = "mobile-banking-dev"
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

module "eks" {
  source = "../../modules/eks"
  
  cluster_name       = "mobile-banking-dev"
  kubernetes_version = "1.28"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  
  desired_size   = 2
  min_size       = 1
  max_size       = 5
  instance_types = ["t3.medium"]
}
```

3. **Initialize and apply:**
```bash
terraform init
terraform plan
terraform apply
```

4. **Configure kubectl:**
```bash
aws eks update-kubeconfig \
  --name mobile-banking-dev \
  --region us-east-1
```

## Database Setup

### Option 1: In-Cluster PostgreSQL (Development)

Deploy PostgreSQL using Helm:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

# Auth Service Database
helm install postgres-auth bitnami/postgresql \
  --namespace mobile-banking-dev \
  --set auth.database=auth_db \
  --set auth.username=postgres \
  --set auth.password=postgres

# User Service Database
helm install postgres-user bitnami/postgresql \
  --namespace mobile-banking-dev \
  --set auth.database=user_db \
  --set auth.username=postgres \
  --set auth.password=postgres
```

### Option 2: Cloud SQL / RDS (Production)

**For GKE (Cloud SQL):**
```bash
gcloud sql instances create mobile-banking-db \
  --database-version=POSTGRES_15 \
  --tier=db-custom-2-4096 \
  --region=us-central1

gcloud sql databases create auth_db --instance=mobile-banking-db
gcloud sql databases create user_db --instance=mobile-banking-db
```

**For EKS (RDS):**
```bash
aws rds create-db-instance \
  --db-instance-identifier mobile-banking-db \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --master-username postgres \
  --master-user-password YOUR_PASSWORD \
  --allocated-storage 20
```

## Kubernetes Namespace Setup

```bash
# Create namespace
kubectl create namespace mobile-banking-dev

# Create secrets for database credentials
kubectl create secret generic db-credentials \
  --namespace mobile-banking-dev \
  --from-literal=username=postgres \
  --from-literal=password=postgres

# Create secret for JWT
kubectl create secret generic jwt-secret \
  --namespace mobile-banking-dev \
  --from-literal=secret=your-256-bit-secret-key-for-jwt-token-signing-minimum-32-chars
```

## Service Deployment

### Deploy Auth Service

```bash
cd helm/charts/auth-service

# Lint the chart
helm lint .

# Dry run to verify
helm upgrade --install auth-service . \
  --namespace mobile-banking-dev \
  -f values-dev.yaml \
  --dry-run

# Deploy
helm upgrade --install auth-service . \
  --namespace mobile-banking-dev \
  -f values-dev.yaml \
  --wait
```

### Deploy User Service

```bash
cd helm/charts/user-service

helm upgrade --install user-service . \
  --namespace mobile-banking-dev \
  -f values-dev.yaml \
  --wait
```

### Deploy API Gateway

```bash
cd helm/charts/api-gateway

helm upgrade --install api-gateway . \
  --namespace mobile-banking-dev \
  -f values-dev.yaml \
  --wait
```

## Verify Deployment

```bash
# Check pod status
kubectl get pods -n mobile-banking-dev

# Check services
kubectl get svc -n mobile-banking-dev

# Check ingress
kubectl get ingress -n mobile-banking-dev

# View logs
kubectl logs -f deployment/auth-service -n mobile-banking-dev
kubectl logs -f deployment/user-service -n mobile-banking-dev
kubectl logs -f deployment/api-gateway -n mobile-banking-dev
```

## Ingress Configuration

### NGINX Ingress Controller

```bash
# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

### TLS Certificate (cert-manager)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

## Observability Stack Deployment

### Prometheus

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace \
  --set server.persistentVolume.enabled=false
```

### Grafana

```bash
helm repo add grafana https://grafana.github.io/helm-charts

helm install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=admin \
  --set persistence.enabled=false
```

### Jaeger

```bash
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts

helm install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --set provisionDataStore.cassandra=false \
  --set allInOne.enabled=true \
  --set storage.type=memory
```

## Production Deployment

### Production Values

Use production values files for each service:
```bash
helm upgrade --install auth-service helm/charts/auth-service \
  --namespace mobile-banking-prod \
  -f helm/charts/auth-service/values-prod.yaml

helm upgrade --install user-service helm/charts/user-service \
  --namespace mobile-banking-prod \
  -f helm/charts/user-service/values-prod.yaml

helm upgrade --install api-gateway helm/charts/api-gateway \
  --namespace mobile-banking-prod \
  -f helm/charts/api-gateway/values-prod.yaml
```

### Production Checklist

- [ ] Use managed database (Cloud SQL / RDS)
- [ ] Enable TLS with valid certificates
- [ ] Configure proper resource limits
- [ ] Enable HPA for auto-scaling
- [ ] Set up network policies
- [ ] Configure pod disruption budgets
- [ ] Enable audit logging
- [ ] Set up backup procedures
- [ ] Configure monitoring alerts
- [ ] Document runbooks

## Rollback Procedures

### Helm Rollback

```bash
# List release history
helm history auth-service -n mobile-banking-dev

# Rollback to previous version
helm rollback auth-service 1 -n mobile-banking-dev
```

### Kubernetes Rollback

```bash
# View rollout history
kubectl rollout history deployment/auth-service -n mobile-banking-dev

# Rollback to previous revision
kubectl rollout undo deployment/auth-service -n mobile-banking-dev
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n mobile-banking-dev

# Check logs
kubectl logs <pod-name> -n mobile-banking-dev --previous
```

### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints -n mobile-banking-dev

# Test service connectivity
kubectl run test-pod --rm -it --image=busybox -- wget -qO- http://auth-service:8081/health
```

### Database Connection Issues

```bash
# Check database pod
kubectl get pods -l app=postgresql -n mobile-banking-dev

# Test database connectivity
kubectl run test-db --rm -it --image=postgres:15 -- psql -h postgres-auth-postgresql -U postgres -d auth_db
```

## Cleanup

### Remove Services

```bash
helm uninstall auth-service -n mobile-banking-dev
helm uninstall user-service -n mobile-banking-dev
helm uninstall api-gateway -n mobile-banking-dev
```

### Destroy Infrastructure

```bash
cd terraform/environments/dev
terraform destroy
```
