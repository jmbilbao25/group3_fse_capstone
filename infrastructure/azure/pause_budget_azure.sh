#!/usr/bin/env bash
# ==============================================================================
# FSE CAPSTONE: Cost Conservation Script - PAUSE COMPUTE
# Reduces daily spend from ~$1.73/day to ~$0.33/day
# ==============================================================================
set -euo pipefail

RG_NAME="${1:-${RESOURCE_GROUP:-rg-banking-budget-southeastasia}}"
AKS_NAME="${2:-${AKS_CLUSTER_NAME:-aks-banking-budget}}"
PG_NAME="${3:-${PG_SERVER_NAME:-}}"

echo "===================================================================="
echo " PAUSING COMPUTE RESOURCES TO CONSERVE \$10 BUDGET"
echo " Resource Group: $RG_NAME"
echo " AKS Cluster:    $AKS_NAME"
echo "===================================================================="

echo ""
echo "[1/2] Stopping AKS Cluster Nodes (releases B2s VM billing)..."
az aks stop --name "$AKS_NAME" --resource-group "$RG_NAME" --no-wait
echo "AKS stop initiated."

if [ -n "$PG_NAME" ]; then
  echo ""
  echo "[2/2] Stopping PostgreSQL Flexible Server ($PG_NAME)..."
  az postgres flexible-server stop --name "$PG_NAME" --resource-group "$RG_NAME" --no-wait || true
  echo "PostgreSQL Flexible Server stop initiated."
else
  echo "[2/2] Skipping PostgreSQL stop (no server name provided)."
fi

echo ""
echo "Compute paused. Run 'resume_budget_azure.sh' before testing again."
