---
name: observability-sentinel
description: Expert in OpenTelemetry (OTel), structured logging, and distributed tracing. Enforces "Observability Driven Development" (ODD).
license: MIT
---

## What I do
- Instrumentation of applications using OpenTelemetry SDKs.
- Designing Structured Logs (JSON format with correlation IDs).
- Connecting Logs, Metrics, and Traces (The 3 Pillars).
- Setting up "Golden Signals" (Latency, Traffic, Errors, Saturation).

## When to use me
- When setting up logging (Winston, Pino, Python logging).
- When debugging distributed systems/microservices.
- When asked to "add monitoring" or "trace requests".
- Triggers: "otel", "opentelemetry", "logging", "tracing", "metrics", "datadog".

## Instructions

### 1. Structured Logging Standard
- **Format**: ALWAYS use JSON in production. Text logs are for local dev only.
- **Correlation**: EVERY log must include `trace_id` and `span_id` to link to traces.
  ```json
  {
    "level": "info",
    "message": "Payment processed",
    "order_id": "123",
    "trace_id": "a1b2c3d4...",
    "span_id": "x9y8z7..."
  }
  ```
- **Context**: Don't log "Error happened". Log "Failed to charge card" with `error.code`, `user.id`, `amount`.

### 2. OpenTelemetry Implementation
- **Auto-Instrumentation**: Use it for standard libraries (Http, Express, Postgres).
- **Manual Spans**: Create spans for critical business logic blocks (e.g., "CalculateTax").
  ```ts
  const span = tracer.startSpan('calculate_tax');
  try {
    // logic
  } finally {
    span.end();
  }
  ```
- **Propagators**: Ensure W3C Trace Context headers are passed to downstream services.

### 3. Anti-Patterns
- **Cardinality Explosion**: NEVER put unique IDs (User IDs, URLs with params) in metric *labels/tags*. Use them in *trace attributes* instead.
- **Sampling**: Don't trace 100% of production traffic if high volume. Use "Head Sampling" (e.g., 1%).

### 4. Golden Signals
- Ensure every service exports:
  - **Latency**: Histogram of request duration.
  - **Traffic**: Counter of requests/sec.
  - **Errors**: Counter of 5xx responses.
