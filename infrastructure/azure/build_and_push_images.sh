#!/usr/bin/env bash
# ==============================================================================
# FSE CAPSTONE: Build and Push Microservice Images to Azure Container Registry
# Works natively in Azure Cloud Shell Bash (using serverless az acr build)
# or Local Docker environment.
# ==============================================================================
set -euo pipefail

ACR_NAME="${1:-}"

if [ -z "$ACR_NAME" ]; then
  echo "Usage: ./build_and_push_images.sh <ACR_NAME>"
  echo "Example: ./build_and_push_images.sh acrbanking12345"
  exit 1
fi

ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
echo "Target Azure Container Registry: $ACR_LOGIN_SERVER"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Step 0: Ensure Java Spring Boot binaries exist (build if fresh clone)
if [ ! -f "${ROOT_DIR}/backend/gateway-service/target/gateway-service-1.0.0-SNAPSHOT.jar" ]; then
  echo "Compiled Java artifacts not found. Building with Maven..."
  if command -v mvn &> /dev/null; then
    (cd "${ROOT_DIR}/backend" && mvn clean package -DskipTests)
  else
    echo "Warning: mvn not found. Assuming pre-built jars or container builds."
  fi
fi

# Step 0b: Ensure Frontend dist exists (build if fresh clone)
if [ ! -d "${ROOT_DIR}/frontend/dist" ]; then
  echo "Frontend distribution bundle not found. Building with npm..."
  if command -v npm &> /dev/null; then
    (cd "${ROOT_DIR}/frontend" && npm install && npm run build)
  else
    echo "Warning: npm not found. Assuming pre-built dist."
  fi
fi

SERVICES=(
  "gateway-service"
  "account-service"
  "ledger-mutation-engine"
  "notification-service"
  "risk-service"
)

USE_AZ_ACR_BUILD=false
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
  echo "Docker daemon not running locally (Cloud Shell detected). Using serverless 'az acr build'..."
  USE_AZ_ACR_BUILD=true
else
  echo "Local Docker detected. Logging in to $ACR_LOGIN_SERVER..."
  az acr login --name "$ACR_NAME"
fi

for svc in "${SERVICES[@]}"; do
  echo "------------------------------------------------------------"
  echo "Building and pushing $svc to $ACR_LOGIN_SERVER..."
  echo "------------------------------------------------------------"
  if [ "$USE_AZ_ACR_BUILD" = "true" ]; then
    az acr build --registry "$ACR_NAME" --image "${svc}:latest" "${ROOT_DIR}/backend/${svc}"
  else
    IMAGE_TAG="${ACR_LOGIN_SERVER}/${svc}:latest"
    docker build -t "$IMAGE_TAG" "${ROOT_DIR}/backend/${svc}"
    docker push "$IMAGE_TAG"
  fi
done

echo "------------------------------------------------------------"
echo "Building and pushing frontend image..."
echo "------------------------------------------------------------"
if [ "$USE_AZ_ACR_BUILD" = "true" ]; then
  az acr build --registry "$ACR_NAME" --image "banking-frontend:latest" "${ROOT_DIR}/frontend"
else
  FRONTEND_TAG="${ACR_LOGIN_SERVER}/banking-frontend:latest"
  docker build -t "$FRONTEND_TAG" "${ROOT_DIR}/frontend"
  docker push "$FRONTEND_TAG"
fi

echo "============================================================"
echo "All images built and pushed successfully to $ACR_LOGIN_SERVER."
echo "============================================================"
