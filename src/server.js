import express from "express";
import crypto from "crypto";

const app = express();
const port = Number(process.env.PORT || 8080);
const appName = process.env.APP_NAME || "orders-api";
const revision = process.env.CONTAINER_APP_REVISION || "local";

app.use(express.json());

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function logEvent(event) {
  console.log(JSON.stringify({
    app: appName,
    revision,
    timestamp: new Date().toISOString(),
    ...event
  }));
}

app.use((req, res, next) => {
  const start = Date.now();
  const requestId = req.headers["x-request-id"] || crypto.randomUUID();
  res.setHeader("x-request-id", requestId);

  res.on("finish", () => {
    logEvent({
      type: "request",
      request_id: requestId,
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration_ms: Date.now() - start
    });
  });

  next();
});

app.get("/", (_req, res) => {
  res.json({
    service: appName,
    message: "Azure Container Apps demo API",
    endpoints: ["/health", "/orders", "/orders/:id", "/dependency-demo", "/simulate-error"]
  });
});

app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    service: appName,
    revision,
    time: new Date().toISOString()
  });
});

app.get("/orders", async (_req, res) => {
  const dependencyMs = Math.floor(40 + Math.random() * 240);
  await sleep(dependencyMs);

  logEvent({
    type: "dependency",
    dependency: "orders-db",
    dependency_ms: dependencyMs,
    outcome: "success"
  });

  res.json({
    count: 3,
    orders: [
      { id: "ord-1001", customer: "Contoso", status: "paid", total: 129.9 },
      { id: "ord-1002", customer: "Fabrikam", status: "packed", total: 74.5 },
      { id: "ord-1003", customer: "Northwind", status: "shipped", total: 212.0 }
    ]
  });
});

app.get("/orders/:id", (req, res) => {
  res.json({
    id: req.params.id,
    status: "paid",
    total: 129.9,
    revision
  });
});

app.get("/dependency-demo", async (_req, res) => {
  const dependencyMs = Math.floor(200 + Math.random() * 1800);
  await sleep(dependencyMs);

  logEvent({
    type: "dependency",
    dependency: "payment-api",
    dependency_ms: dependencyMs,
    outcome: dependencyMs > 1400 ? "slow" : "success"
  });

  res.json({
    dependency: "payment-api",
    dependency_ms: dependencyMs,
    status: dependencyMs > 1400 ? "slow" : "ok"
  });
});

app.get("/simulate-error", (_req, res) => {
  const errorId = crypto.randomUUID();

  logEvent({
    type: "error",
    level: "ERROR",
    error_id: errorId,
    message: "Simulated checkout failure for diagnostics demo"
  });

  res.status(500).json({
    error: "Simulated checkout failure",
    error_id: errorId
  });
});

app.listen(port, () => {
  logEvent({
    type: "startup",
    message: `${appName} listening on port ${port}`
  });
});
