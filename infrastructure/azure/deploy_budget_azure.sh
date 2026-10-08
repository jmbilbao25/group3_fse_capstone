#!/usr/bin/env bash
# ==============================================================================
# FSE CAPSTONE: Cost-Optimized Azure Infrastructure Deployment
# Budget Constraint: Total Azure Spend <= $10.00 USD
# Target Environment: Azure Cloud Shell (Bash) or Local Bash with Azure CLI
# ==============================================================================
set -euo pipefail

USE_MANAGED_POSTGRES="${USE_MANAGED_POSTGRES:-false}"

echo "===================================================================="
echo " Starting FSE Banking Capstone - Budget-Optimized Azure Deployment"
if [ "$USE_MANAGED_POSTGRES" = "true" ]; then
  echo " Architecture: Single B2s AKS + Basic SQL + Managed PostgreSQL B1ms"
  echo " Estimated Daily Run Cost: ~\$1.73/day (~5.7 days on \$10.00 budget)"
else
  echo " Architecture: Single B2s AKS + Basic SQL + In-Cluster PostgreSQL ($0.00)"
  echo " Estimated Daily Run Cost: ~\$1.33/day (~7.5 days on \$10.00 budget)"
  echo " Paused Cost (az aks stop): ~\$0.21/day (~47 days on \$10.00 budget)"
fi
echo "===================================================================="

# 1. Configuration & Random Identifier
LOCATION="${AZURE_LOCATION:-southeastasia}"
RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-banking-budget-$LOCATION}"
ACR_NAME="${ACR_NAME:-acrbanking$RANDOM_SUFFIX}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-banking-budget}"
SQL_SERVER_NAME="${SQL_SERVER_NAME:-sql-banking-$RANDOM_SUFFIX}"
SQL_DB_NAME="sqldb-master"
SQL_ADMIN_USER="sqladminuser"
SQL_ADMIN_PASS="Capst0ne!Secure${RANDOM_SUFFIX}#"

PG_SERVER_NAME="${PG_SERVER_NAME:-psql-banking-$RANDOM_SUFFIX}"
PG_DB_NAME="banking_audit"
PG_ADMIN_USER="audit_admin"
PG_ADMIN_PASS="Audit!Vault${RANDOM_SUFFIX}#"

JWT_SECRET="c3VwZXItc2VjcmV0LWtleS1mb3ItZnNlLWNhcHN0b25lLWJhbmtpbmctcGxhdGZvcm0tMjAyNi0xMjM0NTY3ODkwMTI="

echo ""
echo "[1/7] Creating Resource Group: $RESOURCE_GROUP ($LOCATION)..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o table

echo ""
echo "[2/7] Provisioning Azure SQL Logical Server & Basic 5 DTU Database (~$0.16/day)..."
az sql server create \
  --name "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASS" \
  -o table

# Open firewall to all Azure services (0.0.0.0 to 0.0.0.0)
az sql server firewall-rule create \
  --server "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name "AllowAzureInternal" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0 \
  -o table

az sql db create \
  --server "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$SQL_DB_NAME" \
  --edition Basic \
  --service-objective Basic \
  --capacity 5 \
  -o table

echo ""
if [ "$USE_MANAGED_POSTGRES" = "true" ]; then
  echo "[3/7] Provisioning Azure Database for PostgreSQL Flexible Server (Burstable B1ms, ~$0.40/day)..."
  az postgres flexible-server create \
    --name "$PG_SERVER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --admin-user "$PG_ADMIN_USER" \
    --admin-password "$PG_ADMIN_PASS" \
    --sku-name Standard_B1ms \
    --tier Burstable \
    --version 16 \
    --storage-size 32 \
    --yes \
    -o table

  az postgres flexible-server firewall-rule create \
    --name "$PG_SERVER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --rule-name "AllowAzureInternal" \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 \
    -o table

  az postgres flexible-server db create \
    --server-name "$PG_SERVER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --database-name "$PG_DB_NAME" \
    -o table

  PG_FQDN="${PG_SERVER_NAME}.postgres.database.azure.com"
  PG_JDBC_URL="jdbc:postgresql://${PG_FQDN}:5432/${PG_DB_NAME}?sslmode=require"
else
  echo "[3/7] PostgreSQL Mode: IN-CLUSTER POD ($0.00 extra cost / saves ~$12/month)..."
  echo "      PostgreSQL 16 Alpine will deploy automatically inside AKS alongside Redis & Kafka."
  PG_FQDN="postgres.banking.svc.cluster.local"
  PG_JDBC_URL="jdbc:postgresql://${PG_FQDN}:5432/${PG_DB_NAME}?sslmode=disable"
fi

echo ""
echo "[4/7] Provisioning Azure Container Registry (Basic SKU, ~$0.17/day)..."
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Basic \
  --admin-enabled true \
  -o table

echo ""
echo "[5/7] Provisioning Single-Node AKS Cluster (Standard_B2s, Free Control Plane, ~$1.00/day)..."
az aks create \
  --name "$AKS_CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --tier free \
  --attach-acr "$ACR_NAME" \
  --generate-ssh-keys \
  -o table

echo ""
echo "[6/7] Configuring Kubernetes Cluster Credentials & Secrets..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --overwrite-existing

kubectl create namespace banking --dry-run=client -o yaml | kubectl apply -f -

SQL_FQDN="${SQL_SERVER_NAME}.database.windows.net"
SQL_JDBC_URL="jdbc:sqlserver://${SQL_FQDN}:1433;databaseName=${SQL_DB_NAME};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"

kubectl create secret generic banking-secrets \
  --namespace banking \
  --from-literal=azure-sql-url="$SQL_JDBC_URL" \
  --from-literal=azure-sql-username="$SQL_ADMIN_USER" \
  --from-literal=azure-sql-password="$SQL_ADMIN_PASS" \
  --from-literal=azure-postgres-url="$PG_JDBC_URL" \
  --from-literal=azure-postgres-username="$PG_ADMIN_USER" \
  --from-literal=azure-postgres-password="$PG_ADMIN_PASS" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "[7/7] Applying Kubernetes Manifests with in-cluster dependencies..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/../k8s"

kubectl apply -f "${K8S_DIR}/00_namespace.yaml"
kubectl apply -f "${K8S_DIR}/00_in_cluster_dependencies.yaml"

# Replace ACR placeholder and apply service deployments
for file in "${K8S_DIR}"/0[1-6]*.yaml; do
  if [ -f "$file" ]; then
    sed "s/__ACR_NAME__/${ACR_NAME}/g" "$file" | kubectl apply -f -
  fi
done

echo ""
echo "===================================================================="
echo " DEPLOYMENT COMPLETE! Save These Credentials:"
echo "===================================================================="
echo " Resource Group:       $RESOURCE_GROUP"
echo " AKS Cluster:          $AKS_CLUSTER_NAME"
echo " ACR Registry:         $ACR_NAME.azurecr.io"
echo " Azure SQL Host:       $SQL_FQDN"
echo " Azure SQL DB:         $SQL_DB_NAME (User: $SQL_ADMIN_USER, Pass: $SQL_ADMIN_PASS)"
echo " PostgreSQL Host:      $PG_FQDN"
echo " PostgreSQL DB:        $PG_DB_NAME (User: $PG_ADMIN_USER, Pass: $PG_ADMIN_PASS)"
echo " PostgreSQL Type:      $(if [ "$USE_MANAGED_POSTGRES" = "true" ]; then echo "Azure Managed Flexible Server (~$0.40/day)"; else echo "In-Cluster Pod ($0.00 / Free)"; fi)"
echo "===================================================================="
echo ""
echo "To check the public IP of your Gateway service (run in a few moments):"
echo "  kubectl get svc gateway-service -n banking"
echo ""
echo "To preserve your \$10.00 budget when not presenting, run:"
echo "  bash ${SCRIPT_DIR}/pause_budget_azure.sh $RESOURCE_GROUP $AKS_CLUSTER_NAME $(if [ "$USE_MANAGED_POSTGRES" = "true" ]; then echo "$PG_SERVER_NAME"; fi)"
echo "===================================================================="
