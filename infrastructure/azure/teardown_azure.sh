#!/usr/bin/env bash
# ==============================================================================
# FSE CAPSTONE: Complete Teardown Script
# Deletes the entire resource group to stop 100% of billing
# ==============================================================================
set -euo pipefail

RG_NAME="${1:-${RESOURCE_GROUP:-rg-banking-budget-southeastasia}}"

echo "===================================================================="
echo " TEARING DOWN ALL AZURE RESOURCES IN: $RG_NAME"
echo " WARNING: This will permanently delete the AKS cluster, SQL database,"
echo " PostgreSQL audit vault, and container registry."
echo "===================================================================="

read -p "Are you sure you want to delete resource group '$RG_NAME'? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  echo "Deleting resource group $RG_NAME (this may take 5-10 minutes)..."
  az group delete --name "$RG_NAME" --yes --no-wait
  echo "Resource group deletion command issued. Azure billing has ceased."
else
  echo "Teardown aborted by user."
fi
