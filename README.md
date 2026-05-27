# Azure Orders API Demo

A small demo project for presenting Azure architecture, repeatable development, CI/CD, and diagnostics.

The demo contains:

- A Node.js Express `orders-api`
- A Dockerfile for containerization
- Bicep infrastructure for:
  - Azure Container Registry
  - Log Analytics workspace
  - Azure Container Apps environment
  - User-assigned managed identity
  - AcrPull role assignment
  - Azure Container App
- GitHub Actions deployment using Azure OIDC login
- Smoke test and revision validation commands
- KQL queries for runtime evidence

## Demo story

Use this demo to prove the message from the presentation:

> Architecture defines the target, development makes delivery repeatable, and diagnostics proves reality matches the design.

The live flow is:

1. Run the API locally.
2. Show that the API produces structured logs.
3. Deploy Azure foundation with Bicep.
4. Build and push the Docker image to Azure Container Registry.
5. Deploy the image to Azure Container Apps.
6. Smoke-test `/health`.
7. Generate traffic and errors.
8. Use logs/KQL/revisions to prove what is running and whether it is healthy.

## Prerequisites

Local demo:

- Docker
- Node.js 20+ if you want to run without Docker

Azure demo:

- Azure subscription
- Azure CLI
- Docker
- Permission to create resource groups, role assignments, Container Apps, ACR, and Log Analytics

For GitHub Actions deployment:

- A GitHub repository
- A Microsoft Entra application or managed identity configured for GitHub OIDC
- GitHub repository secrets:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
- GitHub repository variable:
  - `AZURE_ACR_NAME`

`AZURE_ACR_NAME` must be globally unique, lowercase, and contain only letters and numbers.

## Run locally

```bash
npm install
npm start
```

Then open:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/orders
curl http://localhost:8080/dependency-demo
curl -i http://localhost:8080/simulate-error
```

Or run the full local Docker demo:

```bash
./scripts/demo-local.sh
```

## Deploy manually from terminal

```bash
az login
az account set --subscription "<your-subscription-id>"

export RG=rg-orders-demo
export LOCATION=westeurope
export APP_NAME=orders-api
export ACR_NAME=<globally-unique-acr-name>

./scripts/deploy-from-terminal.sh
```

After deployment:

```bash
FQDN=$(az containerapp show \
  --resource-group "$RG" \
  --name "$APP_NAME" \
  --query properties.configuration.ingress.fqdn \
  --output tsv)

curl https://$FQDN/health
curl https://$FQDN/orders
curl https://$FQDN/dependency-demo
curl -i https://$FQDN/simulate-error
```

Show runtime evidence:

```bash
az containerapp logs show \
  --resource-group "$RG" \
  --name "$APP_NAME" \
  --follow

az containerapp revision list \
  --resource-group "$RG" \
  --name "$APP_NAME" \
  --output table
```

## Deploy with GitHub Actions


### Optional helper: create GitHub OIDC app registration

```bash
export GITHUB_OWNER=<github-owner-or-org>
export GITHUB_REPO=<repo-name>
export RG=rg-orders-demo
export LOCATION=westeurope
./scripts/setup-github-oidc.sh
```

The helper prints the GitHub secrets you need to add. For a classroom/demo setup it grants `Contributor`, `User Access Administrator`, and `AcrPush` at the demo resource-group scope. For production, reduce permissions and separate duties.

1. Push this project to a GitHub repository.
2. Configure Azure OIDC authentication for the repository.
3. Add the required GitHub secrets and variable.
4. Push to `main` or run the workflow manually.

The workflow does this:

1. Logs into Azure using OIDC.
2. Creates or updates the resource group and providers.
3. Deploys the foundation Bicep file.
4. Enables ARM audience tokens for ACR managed-identity pulls.
5. Builds and pushes a Docker image tagged with the Git commit SHA.
6. Deploys the Container App revision.
7. Runs a smoke test against `/health`.
8. Prints active revisions.

## KQL diagnostics

Open the Log Analytics workspace and run the queries from:

```text
scripts/queries.kql
```

There are two versions of the queries because Azure environments may use either resource-specific tables like `ContainerAppConsoleLogs` or legacy/custom tables like `ContainerAppConsoleLogs_CL`.

## Clean up

```bash
export RG=rg-orders-demo
./scripts/cleanup.sh
```

This deletes the whole demo resource group.
