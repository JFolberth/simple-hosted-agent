#!/usr/bin/env bash
# azd-select.sh — Choose an IaC provider (Bicep or Terraform) and write
# deployment/azure.yaml accordingly. Run this once before `azd env new` / `azd up`.
#
# Usage (from the repo root):
#   ./deployment/azd-select.sh
#
# Usage (from the deployment/ directory):
#   ./azd-select.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Select an IaC provider for azd:"
echo "  [1] Bicep  (deployment/infra-azd/main.bicepparam → infra/bicep/main.bicep)"
echo "  [2] Terraform  (infra/terraform/)"
echo ""
read -rp "Enter 1 or 2: " choice

case "$choice" in
  1)
    cp "$SCRIPT_DIR/azure-bicep.yaml" "$SCRIPT_DIR/azure.yaml"
    echo ""
    echo "✓ Wrote deployment/azure.yaml (Bicep)"
    echo ""
    echo "Next steps:"
    echo "  cd deployment"
    echo "  azd env new <env-name>"
    echo "  azd env set AZURE_LOCATION <region>                    # e.g. swedencentral"
    echo "  azd env set AZURE_AI_DEPLOYMENTS_LOCATION <region>     # may differ from AZURE_LOCATION"
    echo "  azd up"
    ;;
  2)
    cp "$SCRIPT_DIR/azure-terraform.yaml" "$SCRIPT_DIR/azure.yaml"
    echo ""
    echo "✓ Wrote deployment/azure.yaml (Terraform)"
    echo ""
    echo "Next steps:"
    echo "  cd deployment"
    echo "  azd env new <env-name>"
    echo "  azd env set AZURE_LOCATION <region>                    # e.g. swedencentral"
    echo "  azd env set AI_DEPLOYMENTS_LOCATION <region>           # → TF_VAR_ai_deployments_location"
    echo "  azd up"
    ;;
  *)
    echo "Invalid choice: '$choice'. Run the script again and enter 1 or 2." >&2
    exit 1
    ;;
esac
