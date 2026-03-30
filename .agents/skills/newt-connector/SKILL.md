---
name: newt-connector
description: Expert configuration for Newt (Fossorial), the connector agent for Pangolin. Bridges private networks to the Pangolin server.
license: MIT
---

## What I do
- Configure `fosrl/newt` to connect private networks to Pangolin.
- Map local services (Docker, IP:Port) to public Pangolin endpoints.
- Handle NAT traversal and keep-alive settings.

## When to use me
- When connecting a Homelab/Private Network to a Pangolin Server.
- When asking to "install the agent" for Pangolin.
- Triggers: "newt", "pangolin client", "connector", "tunnel agent".

## Instructions

### 1. Setup
- **Token**: Newt requires an enrollment token generated from the Pangolin Dashboard.
- **Docker Command**:
  ```bash
  docker run -d --name newt \
    --restart unless-stopped \
    -e PANGOLIN_URL=https://pangolin.example.com \
    -e ENROLLMENT_TOKEN=px_... \
    --network host \
    fosrl/newt:latest
  ```
- **Network**: Use `--network host` (or proper bridge) so Newt can reach other local services (e.g., `localhost:8080` or `192.168.1.50:3000`).

### 2. Service Mapping
- **Dynamic**: Newt pulls configuration from Pangolin. You define routes in the Pangolin UI, not in Newt's local config.
- **Health Checks**: Ensure the local service is reachable from the Newt container. `curl` from inside Newt to verify.

### 3. Best Practices
- **Redundancy**: Run multiple Newt instances (High Availability) if supported by your Pangolin tier.
- **Security**: Don't run Newt as root if possible, though `--network host` often requires permissions.
