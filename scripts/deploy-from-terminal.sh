#!/usr/bin/env bash
set -euo pipefail

# Edit these values before running.
RG="${RG:-rg-orders-demo}"
LOCATION="${LOCATION:-westeurope}"
APP_NAME="${APP_NAME:-orders-api}"
ACR_NAME="${ACR_NAME:-CHANGE_ME_GLOBALLY_UNIQUE_ACR_NAME}"
IMAGE_TAG="${IMAGE_TAG:-local-$(date +%Y%m%d%H%M%S)}"

if [[ "$ACR_NAME" == "CHANGE_ME_GLOBALLY_UNIQUE_ACR_NAME" ]]; then
  echo "Set ACR_NAME to a globally unique lowercase value, for example:"
  echo "  export ACR_NAME=acrdemo$RANDOM$RANDOM"
  exit 1
fi

az group create --name "$RG" --location "$LOCATION"
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.ContainerRegistry --wait

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/foundation.bicep \
  --parameters location="$LOCATION" appName="$APP_NAME" acrName="$ACR_NAME"

az acr config authentication-as-arm update \
  --registry "$ACR_NAME" \
  --status enabled

az acr login --name "$ACR_NAME"
docker build -t "$ACR_NAME.azurecr.io/$APP_NAME:$IMAGE_TAG" .
docker push "$ACR_NAME.azurecr.io/$APP_NAME:$IMAGE_TAG"

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/app.bicep \
  --parameters location="$LOCATION" appName="$APP_NAME" acrName="$ACR_NAME" imageTag="$IMAGE_TAG"

FQDN=$(az containerapp show \
  --resource-group "$RG" \
  --name "$APP_NAME" \
  --query properties.configuration.ingress.fqdn \
  --output tsv)

echo "App URL: https://$FQDN"
curl -fsS "https://$FQDN/health"
