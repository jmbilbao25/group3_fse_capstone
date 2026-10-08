#!/usr/bin/env bash
# ==============================================================================
# FSE CAPSTONE: Build and Push Microservice Images to Azure Container Registry
# Uses self-contained multi-stage Dockerfiles.
# Works natively in Azure Cloud Shell Bash (using serverless az acr build)
# or Local Docker environment with zero host Maven/Node dependencies.
# ==============================================================================
set -euo pipefail

ACR_NAME="${1:-}"

if [ -z "$ACR_NAME" ]; then
  echo "Usage: ./build_and_push_images.sh <ACR_NAME>"
  echo "Example: ./build_and_push_images.sh acrbanking47722"
  exit 1
fi

ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
echo "Target Azure Container Registry: $ACR_LOGIN_SERVER"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

USE_AZ_ACR_BUILD=false
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
  echo "Docker daemon not running locally (Cloud Shell detected). Using serverless 'az acr build'..."
  USE_AZ_ACR_BUILD=true
else
  echo "Local Docker detected. Logging in to $ACR_LOGIN_SERVER..."
  az acr login --name "$ACR_NAME"
fi

# 1. Java Microservices (Multi-stage build using parent backend/ context)
JAVA_SERVICES=(
  "gateway-service"
  "account-service"
  "ledger-mutation-engine"
  "notification-service"
)

for svc in "${JAVA_SERVICES[@]}"; do
  echo "------------------------------------------------------------"
  echo "Building and pushing Java service: $svc to $ACR_LOGIN_SERVER..."
  echo "------------------------------------------------------------"
  DOCKERFILE_PATH="${ROOT_DIR}/backend/${svc}/Dockerfile"
  if [ "$USE_AZ_ACR_BUILD" = "true" ]; then
    az acr build \
      --registry "$ACR_NAME" \
      --image "${svc}:latest" \
      --file "$DOCKERFILE_PATH" \
      "${ROOT_DIR}/backend"
  else
    IMAGE_TAG="${ACR_LOGIN_SERVER}/${svc}:latest"
    docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_TAG" "${ROOT_DIR}/backend"
    docker push "$IMAGE_TAG"
  fi
done

# 2. Python Risk Service
echo "------------------------------------------------------------"
echo "Building and pushing Python service: risk-service to $ACR_LOGIN_SERVER..."
echo "------------------------------------------------------------"
if [ "$USE_AZ_ACR_BUILD" = "true" ]; then
  az acr build \
    --registry "$ACR_NAME" \
    --image "risk-service:latest" \
    --file "${ROOT_DIR}/backend/risk-service/Dockerfile" \
    "${ROOT_DIR}/backend/risk-service"
else
  RISK_TAG="${ACR_LOGIN_SERVER}/risk-service:latest"
  docker build -f "${ROOT_DIR}/backend/risk-service/Dockerfile" -t "$RISK_TAG" "${ROOT_DIR}/backend/risk-service"
  docker push "$RISK_TAG"
fi

# 3. React Frontend SPA (Multi-stage build)
echo "------------------------------------------------------------"
echo "Building and pushing Frontend SPA: banking-frontend to $ACR_LOGIN_SERVER..."
echo "------------------------------------------------------------"
if [ "$USE_AZ_ACR_BUILD" = "true" ]; then
  az acr build \
    --registry "$ACR_NAME" \
    --image "banking-frontend:latest" \
    --file "${ROOT_DIR}/frontend/Dockerfile" \
    "${ROOT_DIR}/frontend"
else
  FRONTEND_TAG="${ACR_LOGIN_SERVER}/banking-frontend:latest"
  docker build -f "${ROOT_DIR}/frontend/Dockerfile" -t "$FRONTEND_TAG" "${ROOT_DIR}/frontend"
  docker push "$FRONTEND_TAG"
fi

echo "============================================================"
echo "All images built and pushed successfully to $ACR_LOGIN_SERVER."
echo "============================================================"
