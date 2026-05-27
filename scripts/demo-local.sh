#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="orders-api:local"
CONTAINER_NAME="orders-api-demo"

printf '\n1) Building local container image...\n'
docker build -t "$IMAGE_NAME" .

printf '\n2) Starting local container on http://localhost:8080 ...\n'
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER_NAME" -p 8080:8080 "$IMAGE_NAME"

printf '\n3) Health check:\n'
curl -fsS http://localhost:8080/health | sed 's/,/,&\n/g'

printf '\n\n4) Normal request:\n'
curl -fsS http://localhost:8080/orders | sed 's/,/,&\n/g'

printf '\n\n5) Simulated slow dependency:\n'
curl -fsS http://localhost:8080/dependency-demo | sed 's/,/,&\n/g'

printf '\n\n6) Simulated failure, expected HTTP 500:\n'
curl -sS -o /tmp/orders-error.json -w 'status=%{http_code}\n' http://localhost:8080/simulate-error || true
cat /tmp/orders-error.json

printf '\n\n7) Recent container logs:\n'
docker logs --tail 20 "$CONTAINER_NAME"

printf '\n\nDone. Stop it with: docker rm -f %s\n' "$CONTAINER_NAME"
