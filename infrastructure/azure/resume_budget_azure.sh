#!/usr/bin/env bash
# ==============================================================================
# FSE CAPSTONE: Cost Conservation Script - RESUME COMPUTE
# Resumes AKS nodes and PostgreSQL Flexible Server for testing/demo
# ==============================================================================
set -euo pipefail

RG_NAME="${1:-${RESOURCE_GROUP:-rg-banking-budget-southeastasia}}"
AKS_NAME="${2:-${AKS_CLUSTER_NAME:-aks-banking-budget}}"
PG_NAME="${3:-${PG_SERVER_NAME:-}}"

echo "===================================================================="
echo " RESUMING COMPUTE RESOURCES FOR LIVE DEMO / TESTING"
echo " Resource Group: $RG_NAME"
echo " AKS Cluster:    $AKS_NAME"
echo "===================================================================="

echo ""
echo "[1/2] Starting AKS Cluster Nodes..."
az aks start --name "$AKS_NAME" --resource-group "$RG_NAME" --no-wait
echo "AKS start initiated."

if [ -n "$PG_NAME" ]; then
  echo ""
  echo "[2/2] Starting PostgreSQL Flexible Server ($PG_NAME)..."
  az postgres flexible-server start --name "$PG_NAME" --resource-group "$RG_NAME" --no-wait || true
  echo "PostgreSQL Flexible Server start initiated."
else
  echo "[2/2] Skipping PostgreSQL start (no server name provided)."
fi

echo ""
echo "Resume commands dispatched. Pods will reconcile in approximately 60-90 seconds."
