# Mobile Banking Infrastructure

Shared infrastructure repository for the Mobile Banking Platform. Contains Terraform modules, observability stack configuration, Docker Compose for local development, and platform documentation.

## Contents

- **Terraform** - Infrastructure as Code for GKE and EKS clusters
- **Observability** - Prometheus, Grafana, and Jaeger configuration
- **Docker Compose** - Local development environment
- **Documentation** - Architecture, deployment, and security guides
- **Jenkins Shared Libraries** - Reusable CI/CD pipeline functions

## Repository Structure

```
mobile-banking-infra/
├── terraform/
│   ├── modules/
│   │   ├── gke/           # Google Kubernetes Engine module
│   │   ├── eks/           # AWS Elastic Kubernetes Service module
│   │   ├── vpc-gcp/       # GCP VPC module
│   │   └── vpc-aws/       # AWS VPC module
│   └── environments/
│       ├── dev/           # Development environment
│       └── prod/          # Production environment
├── observability/
│   ├── prometheus/        # Prometheus configuration
│   └── grafana/           # Grafana dashboards and datasources
├── docs/
│   ├── ARCHITECTURE.md    # C4 model architecture diagrams
│   ├── DEPLOYMENT_GUIDE.md # Step-by-step deployment guide
│   ├── SECURITY.md        # Security documentation
│   └── EXTENDING.md       # Guide for adding new services
├── shared-libraries/      # Jenkins shared library functions
├── docker-compose.yml     # Local development environment
└── README.md
```

## Terraform Modules

### GKE Module

Provisions a Google Kubernetes Engine cluster with:
- Regional cluster with multiple zones
- Node pools (on-demand and preemptible)
- VPC-native networking
- Workload identity
- Network policies

```bash
cd terraform/environments/dev
terraform init
terraform plan -var="cloud_provider=gcp"
terraform apply -var="cloud_provider=gcp"
```

### EKS Module

Provisions an AWS Elastic Kubernetes Service cluster with:
- Managed node groups
- VPC with public/private subnets
- IAM roles for service accounts
- AWS Load Balancer Controller

```bash
cd terraform/environments/dev
terraform init
terraform plan -var="cloud_provider=aws"
terraform apply -var="cloud_provider=aws"
```

## Local Development

### Prerequisites

- Docker and Docker Compose
- Java 17+ (for running services locally)
- Node.js 18+ (for mobile app development)

### Starting the Environment

```bash
docker-compose up -d
```

This starts:
- PostgreSQL databases (auth_db, user_db)
- Redis (for rate limiting)
- Prometheus (metrics collection)
- Grafana (dashboards)
- Jaeger (distributed tracing)

### Accessing Services

| Service | URL |
|---------|-----|
| API Gateway | http://localhost:8080 |
| Auth Service | http://localhost:8081 |
| User Service | http://localhost:8082 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |
| Jaeger | http://localhost:16686 |

### Default Credentials

- Grafana: admin / admin
- PostgreSQL Auth: auth_user / auth_password
- PostgreSQL User: user_user / user_password

## Observability Stack

### Prometheus

Scrapes metrics from all services at `/actuator/prometheus`:
- Request rates and latencies
- JVM metrics
- Custom business metrics

### Grafana

Pre-configured dashboards:
- Mobile Banking Overview
- Service Health
- Request Rates
- Error Rates
- Response Times

### Jaeger

Distributed tracing for:
- Cross-service request tracking
- Latency analysis
- Error debugging

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - C4 model diagrams and design decisions
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions
- [Security](docs/SECURITY.md) - Security implementation and checklist
- [Extending](docs/EXTENDING.md) - Guide for adding Loan and Notification services

## Jenkins Shared Libraries

Reusable pipeline functions in `shared-libraries/vars/`:

```groovy
@Library('mobile-banking-shared') _

buildMicroservice(
    serviceName: 'auth-service',
    dockerRegistry: 'your-registry',
    environment: 'dev'
)
```

## Multi-Cloud Deployment

Both GKE and EKS deployments use:
- Identical Helm charts
- Same application code
- Environment-specific values files
- Cloud-agnostic Kubernetes manifests

### GKE Deployment

```bash
# Configure kubectl for GKE
gcloud container clusters get-credentials mobile-banking-dev --region us-central1

# Deploy services
helm install auth-service ../auth-service/helm -f ../auth-service/helm/values-dev.yaml
helm install user-service ../user-service/helm -f ../user-service/helm/values-dev.yaml
helm install api-gateway ../api-gateway/helm -f ../api-gateway/helm/values-dev.yaml
```

### EKS Deployment

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig --name mobile-banking-dev --region us-east-1

# Deploy services (same commands as GKE)
helm install auth-service ../auth-service/helm -f ../auth-service/helm/values-dev.yaml
helm install user-service ../user-service/helm -f ../user-service/helm/values-dev.yaml
helm install api-gateway ../api-gateway/helm -f ../api-gateway/helm/values-dev.yaml
```

## Related Repositories

- [Auth Service](https://github.com/kranthimj23/auth-service) - Authentication microservice
- [User Service](https://github.com/kranthimj23/user-service) - User management microservice
- [API Gateway](https://github.com/kranthimj23/api-gateway) - API Gateway microservice
