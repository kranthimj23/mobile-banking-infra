#!/bin/bash

set -e

echo "=============================================="
echo "  Mobile Banking Platform - Service Deployment"
echo "=============================================="

NAMESPACE="${NAMESPACE:-mobile-banking-dev}"
DB_PASSWORD="${DB_PASSWORD:-}"
JWT_SECRET="${JWT_SECRET:-}"
SKIP_DB="${SKIP_DB:-false}"
SKIP_CLONE="${SKIP_CLONE:-false}"
WORK_DIR="${WORK_DIR:-/tmp/mobile-banking}"

print_usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required Environment Variables:"
    echo "  DB_PASSWORD       Password for PostgreSQL databases"
    echo "  JWT_SECRET        Secret key for JWT signing (min 32 chars)"
    echo ""
    echo "Optional Environment Variables:"
    echo "  NAMESPACE         Kubernetes namespace (default: mobile-banking-dev)"
    echo "  WORK_DIR          Working directory for cloned repos (default: /tmp/mobile-banking)"
    echo "  SKIP_DB           Skip database deployment (default: false)"
    echo "  SKIP_CLONE        Skip cloning repos if already cloned (default: false)"
    echo ""
    echo "Prerequisites:"
    echo "  - GKE cluster created and kubectl configured"
    echo "  - Helm 3.12+ installed"
    echo "  - Git installed"
    echo ""
    echo "Example:"
    echo "  DB_PASSWORD=mypassword JWT_SECRET=my-32-char-secret-key-for-jwt ./deploy-services.sh"
    echo ""
}

if [ -z "$DB_PASSWORD" ]; then
    echo "ERROR: DB_PASSWORD environment variable is required"
    print_usage
    exit 1
fi

if [ -z "$JWT_SECRET" ]; then
    echo "ERROR: JWT_SECRET environment variable is required"
    print_usage
    exit 1
fi

if [ ${#JWT_SECRET} -lt 32 ]; then
    echo "ERROR: JWT_SECRET must be at least 32 characters"
    exit 1
fi

check_prerequisites() {
    echo ""
    echo "[1/8] Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        echo "ERROR: kubectl is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        echo "ERROR: helm is not installed"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        echo "ERROR: git is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo "ERROR: Cannot connect to Kubernetes cluster"
        echo "Make sure kubectl is configured correctly"
        exit 1
    fi
    
    echo "All prerequisites met"
    echo "Connected to cluster: $(kubectl config current-context)"
}

clone_repositories() {
    echo ""
    echo "[2/8] Cloning service repositories..."
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    if [ "$SKIP_CLONE" = "true" ] && [ -d "auth-service" ] && [ -d "user-service" ] && [ -d "api-gateway" ]; then
        echo "Repositories already exist, skipping clone..."
        return
    fi
    
    rm -rf auth-service user-service api-gateway
    
    echo "Cloning auth-service..."
    git clone https://github.com/kranthimj23/auth-service.git
    
    echo "Cloning user-service..."
    git clone https://github.com/kranthimj23/user-service.git
    
    echo "Cloning api-gateway..."
    git clone https://github.com/kranthimj23/api-gateway.git
    
    echo "Repositories cloned to $WORK_DIR"
}

create_namespace() {
    echo ""
    echo "[3/8] Creating namespace..."
    
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    echo "Namespace $NAMESPACE ready"
}

create_secrets() {
    echo ""
    echo "[4/8] Creating Kubernetes secrets..."
    
    kubectl create secret generic db-credentials \
        --namespace "$NAMESPACE" \
        --from-literal=username=postgres \
        --from-literal=password="$DB_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl create secret generic jwt-secret \
        --namespace "$NAMESPACE" \
        --from-literal=secret="$JWT_SECRET" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo "Secrets created in namespace $NAMESPACE"
}

deploy_databases() {
    echo ""
    echo "[5/8] Deploying PostgreSQL databases..."
    
    if [ "$SKIP_DB" = "true" ]; then
        echo "Skipping database deployment (SKIP_DB=true)"
        return
    fi
    
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo update
    
    if helm status postgres-auth -n "$NAMESPACE" &> /dev/null; then
        echo "postgres-auth already installed, upgrading..."
    fi
    helm upgrade --install postgres-auth bitnami/postgresql \
        --namespace "$NAMESPACE" \
        --set auth.database=auth_db \
        --set auth.username=postgres \
        --set auth.password="$DB_PASSWORD" \
        --set primary.persistence.size=1Gi \
        --wait --timeout=5m
    
    if helm status postgres-user -n "$NAMESPACE" &> /dev/null; then
        echo "postgres-user already installed, upgrading..."
    fi
    helm upgrade --install postgres-user bitnami/postgresql \
        --namespace "$NAMESPACE" \
        --set auth.database=user_db \
        --set auth.username=postgres \
        --set auth.password="$DB_PASSWORD" \
        --set primary.persistence.size=1Gi \
        --wait --timeout=5m
    
    echo "PostgreSQL databases deployed"
    
    echo "Waiting for databases to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n "$NAMESPACE" --timeout=300s
}

deploy_auth_service() {
    echo ""
    echo "[6/8] Deploying Auth Service..."
    
    cd "$WORK_DIR/auth-service"
    
    if [ ! -f "helm/Chart.yaml" ]; then
        echo "ERROR: Helm chart not found at helm/Chart.yaml"
        echo "Make sure the repository has the correct branch checked out"
        exit 1
    fi
    
    helm upgrade --install auth-service ./helm \
        --namespace "$NAMESPACE" \
        --set image.repository=openjdk \
        --set image.tag=17-slim \
        --set env.SPRING_PROFILES_ACTIVE=dev \
        --set env.DB_HOST=postgres-auth-postgresql \
        --set env.DB_PORT=5432 \
        --set env.DB_NAME=auth_db \
        --set env.DB_USERNAME=postgres \
        --set env.DB_PASSWORD="$DB_PASSWORD" \
        --set env.JWT_SECRET="$JWT_SECRET" \
        --set replicaCount=1 \
        --set resources.requests.memory=256Mi \
        --set resources.requests.cpu=100m \
        --set resources.limits.memory=512Mi \
        --set resources.limits.cpu=500m \
        --timeout=5m
    
    echo "Auth Service deployed"
}

deploy_user_service() {
    echo ""
    echo "[7/8] Deploying User Service..."
    
    cd "$WORK_DIR/user-service"
    
    if [ ! -f "helm/Chart.yaml" ]; then
        echo "ERROR: Helm chart not found at helm/Chart.yaml"
        exit 1
    fi
    
    helm upgrade --install user-service ./helm \
        --namespace "$NAMESPACE" \
        --set image.repository=openjdk \
        --set image.tag=17-slim \
        --set env.SPRING_PROFILES_ACTIVE=dev \
        --set env.DB_HOST=postgres-user-postgresql \
        --set env.DB_PORT=5432 \
        --set env.DB_NAME=user_db \
        --set env.DB_USERNAME=postgres \
        --set env.DB_PASSWORD="$DB_PASSWORD" \
        --set replicaCount=1 \
        --set resources.requests.memory=256Mi \
        --set resources.requests.cpu=100m \
        --set resources.limits.memory=512Mi \
        --set resources.limits.cpu=500m \
        --timeout=5m
    
    echo "User Service deployed"
}

deploy_api_gateway() {
    echo ""
    echo "[8/8] Deploying API Gateway..."
    
    cd "$WORK_DIR/api-gateway"
    
    if [ ! -f "helm/Chart.yaml" ]; then
        echo "ERROR: Helm chart not found at helm/Chart.yaml"
        exit 1
    fi
    
    helm upgrade --install api-gateway ./helm \
        --namespace "$NAMESPACE" \
        --set image.repository=openjdk \
        --set image.tag=17-slim \
        --set env.SPRING_PROFILES_ACTIVE=dev \
        --set env.AUTH_SERVICE_URL=http://auth-service:8081 \
        --set env.USER_SERVICE_URL=http://user-service:8082 \
        --set env.JWT_SECRET="$JWT_SECRET" \
        --set replicaCount=1 \
        --set service.type=LoadBalancer \
        --set resources.requests.memory=256Mi \
        --set resources.requests.cpu=100m \
        --set resources.limits.memory=512Mi \
        --set resources.limits.cpu=500m \
        --timeout=5m
    
    echo "API Gateway deployed"
}

print_summary() {
    echo ""
    echo "=============================================="
    echo "  Deployment Complete!"
    echo "=============================================="
    echo ""
    echo "Deployed Services:"
    kubectl get pods -n "$NAMESPACE"
    echo ""
    echo "Services:"
    kubectl get svc -n "$NAMESPACE"
    echo ""
    echo "To get the API Gateway external IP:"
    echo "  kubectl get svc api-gateway -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
    echo ""
    echo "To view logs:"
    echo "  kubectl logs -f deployment/auth-service -n $NAMESPACE"
    echo "  kubectl logs -f deployment/user-service -n $NAMESPACE"
    echo "  kubectl logs -f deployment/api-gateway -n $NAMESPACE"
    echo ""
    echo "To check health:"
    echo "  kubectl port-forward svc/api-gateway 8080:8080 -n $NAMESPACE"
    echo "  curl http://localhost:8080/health"
    echo ""
}

check_prerequisites
clone_repositories
create_namespace
create_secrets
deploy_databases
deploy_auth_service
deploy_user_service
deploy_api_gateway
print_summary
