#!/bin/bash

set -e

echo "=============================================="
echo "  Mobile Banking Platform - Build & Push Images"
echo "=============================================="

GCP_PROJECT_ID="${GCP_PROJECT_ID:-}"
GCP_REGION="${GCP_REGION:-us-central1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
WORK_DIR="${WORK_DIR:-/tmp/mobile-banking}"
USE_CLOUD_BUILD="${USE_CLOUD_BUILD:-true}"
SKIP_CLONE="${SKIP_CLONE:-false}"

REGISTRY="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/mobile-banking"

print_usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required Environment Variables:"
    echo "  GCP_PROJECT_ID    Your GCP Project ID"
    echo ""
    echo "Optional Environment Variables:"
    echo "  GCP_REGION        GCP Region (default: us-central1)"
    echo "  IMAGE_TAG         Image tag (default: latest)"
    echo "  WORK_DIR          Working directory for cloned repos (default: /tmp/mobile-banking)"
    echo "  USE_CLOUD_BUILD   Use Cloud Build instead of local Docker (default: true)"
    echo "  SKIP_CLONE        Skip cloning repos if already cloned (default: false)"
    echo ""
    echo "Example:"
    echo "  GCP_PROJECT_ID=my-project ./build-and-push-images.sh"
    echo "  GCP_PROJECT_ID=my-project IMAGE_TAG=v1.0.0 ./build-and-push-images.sh"
    echo ""
}

if [ -z "$GCP_PROJECT_ID" ]; then
    echo "ERROR: GCP_PROJECT_ID environment variable is required"
    print_usage
    exit 1
fi

check_prerequisites() {
    echo ""
    echo "[1/6] Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        echo "ERROR: gcloud CLI is not installed"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        echo "ERROR: git is not installed"
        exit 1
    fi
    
    if [ "$USE_CLOUD_BUILD" = "false" ]; then
        if ! command -v docker &> /dev/null; then
            echo "ERROR: docker is not installed (required when USE_CLOUD_BUILD=false)"
            exit 1
        fi
    fi
    
    echo "All prerequisites met"
}

configure_gcp() {
    echo ""
    echo "[2/6] Configuring GCP..."
    
    gcloud config set project "$GCP_PROJECT_ID"
    
    echo "Enabling required APIs..."
    gcloud services enable artifactregistry.googleapis.com
    gcloud services enable cloudbuild.googleapis.com
    
    echo "GCP project configured: $GCP_PROJECT_ID"
}

create_artifact_registry() {
    echo ""
    echo "[3/6] Creating Artifact Registry repository..."
    
    if gcloud artifacts repositories describe mobile-banking \
        --location="$GCP_REGION" \
        --project="$GCP_PROJECT_ID" &> /dev/null; then
        echo "Artifact Registry repository 'mobile-banking' already exists"
    else
        gcloud artifacts repositories create mobile-banking \
            --repository-format=docker \
            --location="$GCP_REGION" \
            --description="Mobile Banking Platform Docker images" \
            --project="$GCP_PROJECT_ID"
        echo "Artifact Registry repository created: mobile-banking"
    fi
    
    if [ "$USE_CLOUD_BUILD" = "false" ]; then
        echo "Configuring Docker authentication..."
        gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet
    fi
}

clone_repositories() {
    echo ""
    echo "[4/6] Cloning service repositories..."
    
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

build_and_push_image() {
    local service_name=$1
    local service_dir=$2
    local image_name="${REGISTRY}/${service_name}:${IMAGE_TAG}"
    
    echo ""
    echo "Building and pushing $service_name..."
    echo "  Image: $image_name"
    
    cd "$service_dir"
    
    if [ ! -f "Dockerfile" ]; then
        echo "ERROR: Dockerfile not found in $service_dir"
        exit 1
    fi
    
    if [ "$USE_CLOUD_BUILD" = "true" ]; then
        echo "Using Cloud Build..."
        gcloud builds submit \
            --tag "$image_name" \
            --project "$GCP_PROJECT_ID" \
            --quiet
    else
        echo "Using local Docker..."
        docker build -t "$image_name" .
        docker push "$image_name"
    fi
    
    echo "$service_name image pushed successfully: $image_name"
}

build_all_images() {
    echo ""
    echo "[5/6] Building and pushing Docker images..."
    
    build_and_push_image "auth-service" "$WORK_DIR/auth-service"
    build_and_push_image "user-service" "$WORK_DIR/user-service"
    build_and_push_image "api-gateway" "$WORK_DIR/api-gateway"
}

print_summary() {
    echo ""
    echo "=============================================="
    echo "  Build & Push Complete!"
    echo "=============================================="
    echo ""
    echo "[6/6] Summary"
    echo ""
    echo "Images pushed to Artifact Registry:"
    echo "  - ${REGISTRY}/auth-service:${IMAGE_TAG}"
    echo "  - ${REGISTRY}/user-service:${IMAGE_TAG}"
    echo "  - ${REGISTRY}/api-gateway:${IMAGE_TAG}"
    echo ""
    echo "Registry: ${REGISTRY}"
    echo "Tag: ${IMAGE_TAG}"
    echo ""
    echo "Next Steps - Deploy services:"
    echo ""
    echo "  DB_PASSWORD=yourpassword \\"
    echo "  JWT_SECRET=your-jwt-secret-min-32-chars \\"
    echo "  IMAGE_REGISTRY=${REGISTRY} \\"
    echo "  IMAGE_TAG=${IMAGE_TAG} \\"
    echo "  ./deploy-services.sh"
    echo ""
    echo "Or view images in GCP Console:"
    echo "  https://console.cloud.google.com/artifacts/docker/${GCP_PROJECT_ID}/${GCP_REGION}/mobile-banking"
    echo ""
}

check_prerequisites
configure_gcp
create_artifact_registry
clone_repositories
build_all_images
print_summary
