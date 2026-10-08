#!/usr/bin/env bash
# ==============================================================================
# FSE CAPSTONE: Apply Schemas to Azure SQL and Azure Database for PostgreSQL
# Can be run directly in Azure Cloud Shell
# ==============================================================================
set -euo pipefail

SQL_SERVER_NAME="${1:-}"
SQL_ADMIN_PASS="${2:-}"
PG_SERVER_NAME="${3:-}"
PG_ADMIN_PASS="${4:-}"

if [ -z "$SQL_SERVER_NAME" ] || [ -z "$SQL_ADMIN_PASS" ]; then
  echo "Usage: ./apply_schemas_azure.sh <SQL_SERVER_NAME> <SQL_ADMIN_PASS> [PG_SERVER_NAME] [PG_ADMIN_PASS]"
  echo "Example: ./apply_schemas_azure.sh sql-banking-xyz Password123# psql-banking-xyz Password123#"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FQDN="${SQL_SERVER_NAME}.database.windows.net"
SQL_USER="sqladminuser"
SQL_DB="sqldb-master"

echo "------------------------------------------------------------"
echo "Applying Master Schema to Azure SQL: $SQL_FQDN..."
echo "------------------------------------------------------------"
if command -v sqlcmd &> /dev/null; then
  sqlcmd -S "$SQL_FQDN" -d "$SQL_DB" -U "$SQL_USER" -P "$SQL_ADMIN_PASS" -i "${SCRIPT_DIR}/01_azure_sql_master_schema.sql"
  echo "Azure SQL schema applied successfully."
else
  echo "sqlcmd not found in PATH. Please run the schema via Azure Portal Query Editor or sqlcmd."
fi

if [ -n "$PG_SERVER_NAME" ] && [ -n "$PG_ADMIN_PASS" ]; then
  PG_FQDN="${PG_SERVER_NAME}.postgres.database.azure.com"
  PG_USER="pgadminuser"
  PG_DB="banking_audit"
  echo "------------------------------------------------------------"
  echo "Applying Audit Vault Schema to Azure PostgreSQL: $PG_FQDN..."
  echo "------------------------------------------------------------"
  if command -v psql &> /dev/null; then
    PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_FQDN" -U "$PG_USER" -d "$PG_DB" -f "${SCRIPT_DIR}/02_azure_postgres_audit_schema.sql"
    echo "Azure PostgreSQL schema applied successfully."
  else
    echo "psql not found in PATH. Please run the schema via Azure Portal or psql."
  fi
fi

echo "Database schemas applied successfully."
