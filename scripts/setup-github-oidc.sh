#!/usr/bin/env bash
set -euo pipefail

# Creates a Microsoft Entra application and federated credential for GitHub Actions OIDC.
# You still need sufficient Azure permissions to create app registrations and role assignments.
# Usage:
#   export GITHUB_OWNER=<owner-or-org>
#   export GITHUB_REPO=<repo-name>
#   export RG=rg-orders-demo
#   export LOCATION=westeurope
#   ./scripts/setup-github-oidc.sh

GITHUB_OWNER="${GITHUB_OWNER:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
RG="${RG:-rg-orders-demo}"
LOCATION="${LOCATION:-westeurope}"
APP_REG_NAME="${APP_REG_NAME:-github-orders-api-demo}"
BRANCH="${BRANCH:-main}"

if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" ]]; then
  echo "Set GITHUB_OWNER and GITHUB_REPO first."
  exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG"

az group create --name "$RG" --location "$LOCATION" >/dev/null

CLIENT_ID=$(az ad app create --display-name "$APP_REG_NAME" --query appId -o tsv)
APP_OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)
SP_OBJECT_ID=$(az ad sp create --id "$CLIENT_ID" --query id -o tsv)

# For a small demo, these roles allow the workflow to create resources, create AcrPull role assignments,
# and push images to ACR. In production, reduce scope and split duties.
az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal --role Contributor --scope "$SCOPE" >/dev/null
az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal --role "User Access Administrator" --scope "$SCOPE" >/dev/null
az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal --role AcrPush --scope "$SCOPE" >/dev/null

PARAMS_FILE=$(mktemp)
cat > "$PARAMS_FILE" <<JSON
{
  "name": "github-${GITHUB_OWNER}-${GITHUB_REPO}-${BRANCH}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_OWNER}/${GITHUB_REPO}:ref:refs/heads/${BRANCH}",
  "description": "GitHub Actions OIDC for ${GITHUB_OWNER}/${GITHUB_REPO} ${BRANCH}",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON

az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters "$PARAMS_FILE" >/dev/null
rm "$PARAMS_FILE"

cat <<OUT

Add these GitHub repository secrets:
AZURE_CLIENT_ID=$CLIENT_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID

Add this GitHub repository variable:
AZURE_ACR_NAME=<globally-unique-lowercase-acr-name>

OUT
