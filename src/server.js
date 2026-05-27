import http from "node:http";
import { randomUUID } from "node:crypto";

const port = process.env.PORT || 8080;
const revision = process.env.CONTAINER_APP_REVISION || process.env.GITHUB_SHA || "local";

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json"
  });
  res.end(JSON.stringify(body, null, 2));
}

function logEvent(event) {
  console.log(JSON.stringify({
    app: "orders-api",
    revision,
    time: new Date().toISOString(),
    ...event
  }));
}

const server = http.createServer(async (req, res) => {
  const start = Date.now();
  const url = new URL(req.url, `http://${req.headers.host}`);

  try {
    if (url.pathname === "/") {
      sendJson(res, 200, {
        service: "orders-api",
        message: "Azure Container Apps demo API",
        endpoints: ["/health", "/orders", "/dependency-demo", "/simulate-error"]
      });
    } else if (url.pathname === "/health") {
      sendJson(res, 200, {
        status: "ok",
        service: "orders-api",
        revision,
        time: new Date().toISOString()
      });
    } else if (url.pathname === "/orders") {
      sendJson(res, 200, {
        orders: [
          { id: 101, customer: "Contoso", status: "paid" },
          { id: 102, customer: "Fabrikam", status: "processing" }
        ]
      });
    } else if (url.pathname === "/dependency-demo") {
      const dependencyMs = Math.floor(Math.random() * 900) + 100;

      logEvent({
        type: "dependency",
        dependency: "payment-api",
        dependency_ms: dependencyMs,
        outcome: "success"
      });

      sendJson(res, 200, {
        dependency: "payment-api",
        dependency_ms: dependencyMs,
        outcome: "success"
      });
    } else if (url.pathname === "/simulate-error") {
      const errorId = randomUUID();

      logEvent({
        type: "error",
        level: "ERROR",
        error_id: errorId,
        message: "Simulated checkout failure for diagnostics demo"
      });

      sendJson(res, 500, {
        error: "Simulated checkout failure",
        error_id: errorId
      });
    } else {
      sendJson(res, 404, {
        error: "Not found"
      });
    }
  } finally {
    logEvent({
      type: "request",
      method: req.method,
      path: url.pathname,
      duration_ms: Date.now() - start
    });
  }
});

server.listen(port, "0.0.0.0", () => {
  logEvent({
    type: "startup",
    message: `orders-api listening on port ${port}`
  });
});
