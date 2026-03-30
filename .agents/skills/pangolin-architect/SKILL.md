---
name: pangolin-architect
description: Expert setup and configuration for Pangolin (Fossorial), the self-hosted tunneled reverse proxy. Handles Identity, Access Control, and WireGuard tunnels.
license: MIT
---

## What I do
- Deploy Pangolin Server (Control Plane) using Docker.
- Configure Identity Providers (OIDC) and Access Policies.
- Manage WireGuard tunnels for secure remote access without opening ports.
- Integrate with `newt` (connectors) and `gerbil` (WG management).

## When to use me
- When user asks to "expose local services safely" or "self-host cloudflare tunnel".
- When configuring `fosrl/pangolin`.
- When setting up reverse proxying with identity awareness.
- Triggers: "pangolin", "fossorial", "tunnel proxy", "wireguard proxy".

## Instructions

### 1. Deployment (Docker Compose)
- **Image**: `fosrl/pangolin:latest`
- **Ports**: Needs UDP/51820 (WireGuard) and TCP/443 (HTTPS) exposed publicly.
- **Volumes**: Persist `/data` for configuration and certificates.
- **Env Vars**:
  - `PANGOLIN_PUBLIC_DOMAIN`: The domain where dashboard is accessible.
  - `PANGOLIN_WG_ENDPOINT`: Public IP/DNS:Port for WireGuard connections.

### 2. Identity & Access
- **Strategy**: Pangolin is identity-aware. Always define an IDP (Pocket-ID, Authentik, Keycloak) before exposing sensitive apps.
- **Policies**: Use "Least Privilege". Create specific policies for specific resources (e.g., "Admins Only" for Portainer).

### 3. Architecture
- **Server**: The Pangolin instance runs on a VPS or DMZ.
- **Client (Newt)**: Runs inside the private network (Homelab).
- **Flow**: User -> Pangolin (VPS) -> WireGuard Tunnel -> Newt (Home) -> Service (192.168.x.x).

### 4. Troubleshooting
- **Logs**: Check `docker logs pangolin` for WireGuard handshake issues.
- **DNS**: Ensure wildcard DNS (`*.tunnel.example.com`) points to Pangolin if using subdomains.
