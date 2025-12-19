#!/bin/bash

set -e

echo "=============================================="
echo "  Mobile Banking Platform - Service Deployment"
echo "=============================================="

NAMESPACE="${NAMESPACE:-mobile-banking-dev}"
DB_PASSWORD="${DB_PASSWORD:-yourpassword123}"
JWT_SECRET="${JWT_SECRET:-your-super-secret-jwt-key-minimum-32-characters}"
SKIP_DB="${SKIP_DB:-false}"
SKIP_CLONE="${SKIP_CLONE:-false}"
WORK_DIR="${WORK_DIR:-/tmp/mobile-banking}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-us-central1-docker.pkg.dev/mobile-banking-app-2/mobile-banking}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

print_usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required Environment Variables:"
    echo "  DB_PASSWORD       Password for PostgreSQL databases"
    echo "  JWT_SECRET        Secret key for JWT signing (min 32 chars)"
    echo "  IMAGE_REGISTRY    Container registry URL (e.g., us-central1-docker.pkg.dev/PROJECT/mobile-banking)"
    echo ""
    echo "Optional Environment Variables:"
    echo "  NAMESPACE         Kubernetes namespace (default: mobile-banking-dev)"
    echo "  WORK_DIR          Working directory for cloned repos (default: /tmp/mobile-banking)"
    echo "  SKIP_DB           Skip database deployment (default: false)"
    echo "  SKIP_CLONE        Skip cloning repos if already cloned (default: false)"
    echo "  IMAGE_TAG         Docker image tag (default: latest)"
    echo ""
    echo "Prerequisites:"
    echo "  - GKE cluster created and kubectl configured"
    echo "  - Helm 3.12+ installed"
    echo "  - Git installed"
    echo "  - Docker images built and pushed (use build-and-push-images.sh)"
    echo ""
    echo "Example:"
    echo "  DB_PASSWORD=mypassword \\"
    echo "  JWT_SECRET=my-32-char-secret-key-for-jwt \\"
    echo "  IMAGE_REGISTRY=us-central1-docker.pkg.dev/my-project/mobile-banking \\"
    echo "  ./deploy-services.sh"
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

if [ -z "$IMAGE_REGISTRY" ]; then
    echo "ERROR: IMAGE_REGISTRY environment variable is required"
    echo "Example: IMAGE_REGISTRY=us-central1-docker.pkg.dev/my-project/mobile-banking"
    print_usage
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
    
    # Create runtime values file with correct env array format
    cat > /tmp/auth-values.yaml <<EOF
replicaCount: 1
image:
  repository: ${IMAGE_REGISTRY}/auth-service
  tag: ${IMAGE_TAG}
  pullPolicy: IfNotPresent
autoscaling:
  enabled: false
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "dev"
  - name: SERVER_PORT
    value: "8081"
  - name: DB_HOST
    value: "postgres-auth-postgresql"
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: "auth_db"
  - name: DB_USERNAME
    value: "postgres"
  - name: DB_PASSWORD
    value: "$DB_PASSWORD"
  - name: JWT_SECRET
    value: "$JWT_SECRET"
envFrom: []
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi
    cpu: 500m
livenessProbe:
  httpGet:
    path: /health
    port: 8081
  initialDelaySeconds: 120
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /health
    port: 8081
  initialDelaySeconds: 60
  periodSeconds: 5
EOF
    
    helm upgrade --install auth-service ./helm \
        --namespace "$NAMESPACE" \
        -f /tmp/auth-values.yaml \
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
    
    # Create runtime values file with correct env array format
    cat > /tmp/user-values.yaml <<EOF
replicaCount: 1
image:
  repository: ${IMAGE_REGISTRY}/user-service
  tag: ${IMAGE_TAG}
  pullPolicy: IfNotPresent
autoscaling:
  enabled: false
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "dev"
  - name: SERVER_PORT
    value: "8082"
  - name: DB_HOST
    value: "postgres-user-postgresql"
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: "user_db"
  - name: DB_USERNAME
    value: "postgres"
  - name: DB_PASSWORD
    value: "$DB_PASSWORD"
envFrom: []
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi
    cpu: 500m
livenessProbe:
  httpGet:
    path: /health
    port: 8082
  initialDelaySeconds: 120
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /health
    port: 8082
  initialDelaySeconds: 60
  periodSeconds: 5
EOF
    
    helm upgrade --install user-service ./helm \
        --namespace "$NAMESPACE" \
        -f /tmp/user-values.yaml \
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
    
    # Create runtime values file with correct env array format
    cat > /tmp/gateway-values.yaml <<EOF
replicaCount: 1
image:
  repository: ${IMAGE_REGISTRY}/api-gateway
  tag: ${IMAGE_TAG}
  pullPolicy: IfNotPresent
autoscaling:
  enabled: false
service:
  type: LoadBalancer
  port: 8080
  targetPort: 8080
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "dev"
  - name: SERVER_PORT
    value: "8080"
  - name: AUTH_SERVICE_URL
    value: "http://auth-service:8081"
  - name: USER_SERVICE_URL
    value: "http://user-service:8082"
  - name: JWT_SECRET
    value: "$JWT_SECRET"
envFrom: []
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi
    cpu: 500m
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 120
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 5
EOF
    
    helm upgrade --install api-gateway ./helm \
        --namespace "$NAMESPACE" \
        -f /tmp/gateway-values.yaml \
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
