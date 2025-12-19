#!/bin/bash

set -e

echo "=============================================="
echo "  Mobile Banking Platform - Cleanup Script"
echo "=============================================="

GCP_PROJECT_ID="${GCP_PROJECT_ID:-}"
GCP_REGION="${GCP_REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-mobile-banking-dev}"
NAMESPACE="${NAMESPACE:-mobile-banking-dev}"
DELETE_CLUSTER="${DELETE_CLUSTER:-false}"

print_usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options (via environment variables):"
    echo "  GCP_PROJECT_ID    Your GCP Project ID (required for cluster operations)"
    echo "  GCP_REGION        GCP Region (default: us-central1)"
    echo "  CLUSTER_NAME      GKE Cluster name (default: mobile-banking-dev)"
    echo "  NAMESPACE         Kubernetes namespace (default: mobile-banking-dev)"
    echo "  DELETE_CLUSTER    Set to 'true' to delete the entire GKE cluster (default: false)"
    echo ""
    echo "Examples:"
    echo ""
    echo "  # Delete only services (keep cluster running)"
    echo "  ./cleanup.sh"
    echo ""
    echo "  # Delete services AND the GKE cluster"
    echo "  GCP_PROJECT_ID=my-project DELETE_CLUSTER=true ./cleanup.sh"
    echo ""
}

delete_services() {
    echo ""
    echo "[1/4] Deleting Helm releases..."
    
    if ! command -v helm &> /dev/null; then
        echo "WARNING: helm not installed, skipping Helm cleanup"
        return
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo "WARNING: kubectl not installed, skipping service cleanup"
        return
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo "WARNING: Cannot connect to Kubernetes cluster, skipping service cleanup"
        return
    fi
    
    echo "Uninstalling api-gateway..."
    helm uninstall api-gateway -n "$NAMESPACE" 2>/dev/null || echo "  api-gateway not found or already deleted"
    
    echo "Uninstalling auth-service..."
    helm uninstall auth-service -n "$NAMESPACE" 2>/dev/null || echo "  auth-service not found or already deleted"
    
    echo "Uninstalling user-service..."
    helm uninstall user-service -n "$NAMESPACE" 2>/dev/null || echo "  user-service not found or already deleted"
    
    echo "Uninstalling postgres-auth..."
    helm uninstall postgres-auth -n "$NAMESPACE" 2>/dev/null || echo "  postgres-auth not found or already deleted"
    
    echo "Uninstalling postgres-user..."
    helm uninstall postgres-user -n "$NAMESPACE" 2>/dev/null || echo "  postgres-user not found or already deleted"
    
    echo "Services deleted"
}

delete_secrets() {
    echo ""
    echo "[2/4] Deleting Kubernetes secrets..."
    
    kubectl delete secret db-credentials -n "$NAMESPACE" 2>/dev/null || echo "  db-credentials not found"
    kubectl delete secret jwt-secret -n "$NAMESPACE" 2>/dev/null || echo "  jwt-secret not found"
    
    echo "Secrets deleted"
}

delete_namespace() {
    echo ""
    echo "[3/4] Deleting namespace..."
    
    kubectl delete namespace "$NAMESPACE" 2>/dev/null || echo "  Namespace $NAMESPACE not found or already deleted"
    
    echo "Namespace deleted"
}

delete_cluster() {
    echo ""
    echo "[4/4] Deleting GKE cluster..."
    
    if [ -z "$GCP_PROJECT_ID" ]; then
        echo "ERROR: GCP_PROJECT_ID is required to delete the cluster"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        echo "ERROR: gcloud CLI not installed"
        exit 1
    fi
    
    gcloud config set project "$GCP_PROJECT_ID"
    
    echo "Deleting cluster: $CLUSTER_NAME in region: $GCP_REGION"
    echo "This may take several minutes..."
    
    gcloud container clusters delete "$CLUSTER_NAME" \
        --region "$GCP_REGION" \
        --project "$GCP_PROJECT_ID" \
        --quiet
    
    echo "GKE cluster deleted"
}

delete_artifact_registry() {
    echo ""
    echo "Deleting Artifact Registry repository..."
    
    if [ -z "$GCP_PROJECT_ID" ]; then
        echo "Skipping Artifact Registry cleanup (GCP_PROJECT_ID not set)"
        return
    fi
    
    gcloud artifacts repositories delete mobile-banking \
        --location="$GCP_REGION" \
        --project="$GCP_PROJECT_ID" \
        --quiet 2>/dev/null || echo "  Artifact Registry repo not found or already deleted"
    
    echo "Artifact Registry cleaned up"
}

print_summary() {
    echo ""
    echo "=============================================="
    echo "  Cleanup Complete!"
    echo "=============================================="
    echo ""
    if [ "$DELETE_CLUSTER" = "true" ]; then
        echo "Deleted:"
        echo "  - All Helm releases (services, databases)"
        echo "  - Kubernetes secrets"
        echo "  - Namespace: $NAMESPACE"
        echo "  - GKE Cluster: $CLUSTER_NAME"
        echo "  - Artifact Registry repository"
    else
        echo "Deleted:"
        echo "  - All Helm releases (services, databases)"
        echo "  - Kubernetes secrets"
        echo "  - Namespace: $NAMESPACE"
        echo ""
        echo "Kept:"
        echo "  - GKE Cluster: $CLUSTER_NAME (still running)"
        echo ""
        echo "To delete the cluster later:"
        echo "  GCP_PROJECT_ID=$GCP_PROJECT_ID DELETE_CLUSTER=true ./cleanup.sh"
    fi
    echo ""
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_usage
    exit 0
fi

delete_services
delete_secrets
delete_namespace

if [ "$DELETE_CLUSTER" = "true" ]; then
    delete_cluster
    delete_artifact_registry
fi

print_summary
