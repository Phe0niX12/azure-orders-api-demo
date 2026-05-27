# Demo Speaker Notes

## 1. Introduce the demo

"Now I will show a small practical demo that connects the three parts of the presentation: architecture, development, and diagnostics. The application is intentionally simple: an orders API. The important part is not the business logic, but the delivery and observability model around it."

## 2. Show the repository

Open the repo and point to these files:

- `src/server.js`
- `Dockerfile`
- `infra/foundation.bicep`
- `infra/app.bicep`
- `.github/workflows/deploy.yml`
- `scripts/queries.kql`

Say:

"The repo contains the app, the infrastructure, the pipeline, and the diagnostics queries. That means the environment is not created manually from memory. It is described and repeatable."

## 3. Run locally

Command:

```bash
./scripts/demo-local.sh
```

Say:

"First I run the application locally in a container. This proves that the API and Docker image work before I involve Azure. The API has a health endpoint, a normal orders endpoint, a dependency simulation, and an error simulation for diagnostics."

After logs appear, say:

"Notice that the app logs structured JSON. This is useful because logs become queryable later in Log Analytics."

## 4. Explain the infrastructure

Open `infra/foundation.bicep`.

Say:

"The foundation creates the shared platform pieces: Azure Container Registry, Log Analytics, a Container Apps environment, and a user-assigned managed identity. The ACR admin user is disabled, so the application does not depend on static registry credentials."

Open `infra/app.bicep`.

Say:

"The Container App uses the managed identity to pull the image from ACR. The app exposes port 8080, creates revisions, and scales based on HTTP traffic."

## 5. Explain the pipeline

Open `.github/workflows/deploy.yml`.

Say:

"The GitHub Actions workflow uses OIDC to authenticate to Azure. It deploys the foundation, builds an image tagged with the Git commit SHA, pushes it to ACR, deploys the Container App, and then runs a smoke test."

Key phrase:

"The commit SHA becomes the release identity. That gives us traceability from a running Azure revision back to a specific version of the code."

## 6. Deploy or show an existing deployment

Manual deployment command:

```bash
export RG=rg-orders-demo
export LOCATION=westeurope
export APP_NAME=orders-api
export ACR_NAME=<globally-unique-acr-name>
./scripts/deploy-from-terminal.sh
```

Say:

"The deployment follows the same order as the architecture: foundation first, image next, application revision after that."

## 7. Smoke test

Command:

```bash
FQDN=$(az containerapp show -g $RG -n $APP_NAME --query properties.configuration.ingress.fqdn -o tsv)
curl https://$FQDN/health
```

Say:

"A deployment is not finished when the command succeeds. It is finished when I can prove the running service is healthy. The health endpoint gives the current service status and revision."

## 8. Generate telemetry

Commands:

```bash
curl https://$FQDN/orders
curl https://$FQDN/dependency-demo
curl -i https://$FQDN/simulate-error
```

Say:

"Now I generate normal traffic, a slow dependency signal, and a simulated failure. This gives us useful telemetry to investigate."

## 9. Show logs and revisions

Commands:

```bash
az containerapp logs show -g $RG -n $APP_NAME --follow
az containerapp revision list -g $RG -n $APP_NAME -o table
```

Say:

"Here I can see the application logs and the active revisions. This connects diagnostics to deployment. If a problem appears after a release, I can correlate the error with the revision and therefore with the commit SHA."

## 10. Show KQL

Open `scripts/queries.kql`.

Say:

"In Log Analytics, I can query errors by revision and dependency latency over time. This is the diagnostics loop from the presentation: collect, analyze, act, and learn."

## 11. Close the demo

Say:

"This demo is small, but it contains production-shaped habits: Infrastructure as Code, no admin registry credentials, immutable image tags, automated smoke testing, revisions, logs, and KQL queries. That is the practical meaning of safe change with evidence."
