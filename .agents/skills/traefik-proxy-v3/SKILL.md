---
name: traefik-proxy-v3
description: Modern Traefik v3 configuration mastery. Focuses on Middleware chains, Docker Labels, File Providers, and Let's Encrypt best practices in 2025.
license: MIT
---

## What I do
- Configure Traefik v3 Static (entrypoints, certs) and Dynamic (routers, services) config.
- Write robust **Middleware Chains** (RateLimit -> Auth -> Compress).
- Secure dashboards and API endpoints.
- Debug "404 Not Found" and Certificate issues.

## When to use me
- When setting up a Reverse Proxy.
- When configuring Docker labels for auto-discovery.
- When asking for "traefik config" or "routing rules".
- Triggers: "traefik", "reverse proxy", "labels", "middleware".

## Instructions

### 1. Static vs Dynamic
- **Static (`traefik.yml`)**: Entrypoints, Log levels, Providers (Docker/File). Set once, restart to change.
- **Dynamic (`file` or `labels`)**: Routers, Middlewares, Services. Hot-reloaded.

### 2. The Docker Label Standard
- **Enable**: `traefik.enable=true` (Always explicit).
- **Router**:
  - `traefik.http.routers.my-app.rule=Host('app.example.com')`
  - `traefik.http.routers.my-app.entrypoints=websecure`
  - `traefik.http.routers.my-app.tls.certresolver=myresolver`
- **Service**:
  - `traefik.http.services.my-app.loadbalancer.server.port=8080` (CRITICAL: Tell Traefik the *internal* container port).

### 3. Middleware Chains
- **Don't Repeat Yourself**: Define a "default-secure" chain in a File Provider.
  ```yaml
  # dynamic.yml
  http:
    middlewares:
      default-secure:
        chain:
          middlewares:
            - "rate-limit"
            - "secure-headers"
            - "compress"
  ```
- **Apply**: `traefik.http.routers.my-app.middlewares=default-secure@file`

### 4. V3 Specifics
- **Tailscale**: Traefik v3 has native Tailscale cert integration. Use it if applicable.
- **WASM**: Traefik v3 supports WebAssembly plugins.
