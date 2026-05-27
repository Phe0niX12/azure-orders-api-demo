#!/usr/bin/env bash
set -euo pipefail

RG="${RG:-rg-orders-demo}"

echo "This deletes the whole resource group: $RG"
read -r -p "Type the resource group name to confirm: " CONFIRM

if [[ "$CONFIRM" != "$RG" ]]; then
  echo "Cancelled."
  exit 1
fi

az group delete --name "$RG" --yes --no-wait
echo "Delete started."
