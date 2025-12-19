#!/bin/bash

set -e

echo "=============================================="
echo "  Mobile Banking Platform - GKE Cluster Setup"
echo "=============================================="

PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-mobile-banking-dev}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-medium}"
NUM_NODES="${NUM_NODES:-2}"
MIN_NODES="${MIN_NODES:-1}"
MAX_NODES="${MAX_NODES:-5}"
DISK_SIZE="${DISK_SIZE:-50}"
NETWORK="${NETWORK:-default}"

print_usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required Environment Variables:"
    echo "  GCP_PROJECT_ID    Your GCP Project ID"
    echo ""
    echo "Optional Environment Variables:"
    echo "  GCP_REGION        GCP Region (default: us-central1)"
    echo "  CLUSTER_NAME      Cluster name (default: mobile-banking-dev)"
    echo "  MACHINE_TYPE      Node machine type (default: e2-medium)"
    echo "  NUM_NODES         Initial number of nodes (default: 2)"
    echo "  MIN_NODES         Minimum nodes for autoscaling (default: 1)"
    echo "  MAX_NODES         Maximum nodes for autoscaling (default: 5)"
    echo "  DISK_SIZE         Boot disk size in GB (default: 50)"
    echo ""
    echo "Example:"
    echo "  GCP_PROJECT_ID=my-project ./create-gke-cluster.sh"
    echo ""
}

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: GCP_PROJECT_ID environment variable is required"
    print_usage
    exit 1
fi

check_prerequisites() {
    echo ""
    echo "[1/7] Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        echo "ERROR: gcloud CLI is not installed"
        echo "Install from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo "ERROR: kubectl is not installed"
        echo "Install from: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        echo "ERROR: helm is not installed"
        echo "Install from: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    echo "All prerequisites are installed"
}

configure_gcloud() {
    echo ""
    echo "[2/7] Configuring gcloud..."
    
    gcloud config set project "$PROJECT_ID"
    gcloud config set compute/region "$REGION"
    
    echo "Enabling required APIs..."
    gcloud services enable container.googleapis.com
    gcloud services enable compute.googleapis.com
    gcloud services enable cloudresourcemanager.googleapis.com
    
    echo "GCP project configured: $PROJECT_ID"
}

create_vpc_network() {
    echo ""
    echo "[3/7] Creating VPC network..."
    
    if gcloud compute networks describe "${CLUSTER_NAME}-vpc" --project="$PROJECT_ID" &> /dev/null; then
        echo "VPC network ${CLUSTER_NAME}-vpc already exists, skipping..."
    else
        gcloud compute networks create "${CLUSTER_NAME}-vpc" \
            --project="$PROJECT_ID" \
            --subnet-mode=auto \
            --mtu=1460 \
            --bgp-routing-mode=regional
        
        echo "VPC network created: ${CLUSTER_NAME}-vpc"
    fi
}

create_gke_cluster() {
    echo ""
    echo "[4/7] Creating GKE cluster..."
    echo "  Cluster Name: $CLUSTER_NAME"
    echo "  Region: $REGION"
    echo "  Machine Type: $MACHINE_TYPE"
    echo "  Nodes: $NUM_NODES (min: $MIN_NODES, max: $MAX_NODES)"
    echo ""
    
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
        echo "Cluster $CLUSTER_NAME already exists, skipping creation..."
    else
        gcloud container clusters create "$CLUSTER_NAME" \
            --project="$PROJECT_ID" \
            --region="$REGION" \
            --machine-type="$MACHINE_TYPE" \
            --num-nodes="$NUM_NODES" \
            --min-nodes="$MIN_NODES" \
            --max-nodes="$MAX_NODES" \
            --enable-autoscaling \
            --disk-size="$DISK_SIZE" \
            --disk-type=pd-standard \
            --enable-ip-alias \
            --network="${CLUSTER_NAME}-vpc" \
            --workload-pool="${PROJECT_ID}.svc.id.goog" \
            --enable-shielded-nodes \
            --shielded-secure-boot \
            --shielded-integrity-monitoring \
            --logging=SYSTEM,WORKLOAD \
            --monitoring=SYSTEM \
            --addons=HttpLoadBalancing,HorizontalPodAutoscaling \
            --release-channel=regular
        
        echo "GKE cluster created successfully!"
    fi
}

configure_kubectl() {
    echo ""
    echo "[5/7] Configuring kubectl..."
    
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"
    
    echo "kubectl configured for cluster: $CLUSTER_NAME"
    kubectl cluster-info
}

create_namespaces() {
    echo ""
    echo "[6/7] Creating Kubernetes namespaces..."
    
    kubectl create namespace mobile-banking-dev --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace mobile-banking-staging --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace mobile-banking-prod --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    echo "Namespaces created: mobile-banking-dev, mobile-banking-staging, mobile-banking-prod, monitoring"
}

install_ingress_controller() {
    echo ""
    echo "[7/7] Installing NGINX Ingress Controller..."
    
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
    helm repo update
    
    if helm status ingress-nginx -n ingress-nginx &> /dev/null; then
        echo "NGINX Ingress Controller already installed, skipping..."
    else
        helm install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --set controller.service.type=LoadBalancer \
            --wait
        
        echo "NGINX Ingress Controller installed!"
    fi
}

print_summary() {
    echo ""
    echo "=============================================="
    echo "  GKE Cluster Setup Complete!"
    echo "=============================================="
    echo ""
    echo "Cluster Details:"
    echo "  Project:      $PROJECT_ID"
    echo "  Cluster:      $CLUSTER_NAME"
    echo "  Region:       $REGION"
    echo "  Machine Type: $MACHINE_TYPE"
    echo ""
    echo "Namespaces Created:"
    echo "  - mobile-banking-dev"
    echo "  - mobile-banking-staging"
    echo "  - mobile-banking-prod"
    echo "  - monitoring"
    echo ""
    echo "Next Steps:"
    echo "  1. Create secrets:"
    echo "     kubectl create secret generic db-credentials \\"
    echo "       --namespace mobile-banking-dev \\"
    echo "       --from-literal=username=postgres \\"
    echo "       --from-literal=password=YOUR_PASSWORD"
    echo ""
    echo "     kubectl create secret generic jwt-secret \\"
    echo "       --namespace mobile-banking-dev \\"
    echo "       --from-literal=secret=YOUR_JWT_SECRET"
    echo ""
    echo "  2. Deploy PostgreSQL:"
    echo "     helm repo add bitnami https://charts.bitnami.com/bitnami"
    echo "     helm install postgres-auth bitnami/postgresql -n mobile-banking-dev"
    echo "     helm install postgres-user bitnami/postgresql -n mobile-banking-dev"
    echo ""
    echo "  3. Deploy services:"
    echo "     helm install auth-service ./auth-service/helm -n mobile-banking-dev -f values-dev.yaml"
    echo "     helm install user-service ./user-service/helm -n mobile-banking-dev -f values-dev.yaml"
    echo "     helm install api-gateway ./api-gateway/helm -n mobile-banking-dev -f values-dev.yaml"
    echo ""
    echo "  4. Get Ingress IP:"
    echo "     kubectl get svc -n ingress-nginx"
    echo ""
}

check_prerequisites
configure_gcloud
create_vpc_network
create_gke_cluster
configure_kubectl
create_namespaces
install_ingress_controller
print_summary
