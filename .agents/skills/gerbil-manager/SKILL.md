---
name: gerbil-manager
description: Configuration for Gerbil (Fossorial), the WireGuard interface manager. Manages peers and interfaces via API.
license: MIT
---

## What I do
- Deploy `fosrl/gerbil` to manage WireGuard interfaces programmatically.
- Configure peer creation, removal, and bandwidth tracking.
- Integrate Gerbil with custom dashboards or scripts.

## When to use me
- When user needs a "WireGuard API" or "WireGuard Manager".
- When managing WG peers dynamically for Pangolin or standalone VPNs.
- Triggers: "gerbil", "wireguard api", "wg manager", "manage peers".

## Instructions

### 1. Deployment
- **Privileges**: Requires `NET_ADMIN` capability to manage network interfaces.
  ```yaml
  services:
    gerbil:
      image: fosrl/gerbil:latest
      cap_add:
        - NET_ADMIN
      environment:
        - GERBIL_INTERFACE=wg0
        - GERBIL_PORT=51820
      volumes:
        - ./data:/data
  ```

### 2. Configuration
- **API**: Gerbil exposes an HTTP API. Secure this! It controls network access.
- **Backend**: Uses `wg-quick` or native kernel wireguard.
- **Persistence**: Ensure `/data` is mounted to persist peer keys and configs across restarts.

### 3. Usage Pattern
- **Standalone**: Use it to build your own VPN panel.
- **Integrated**: Pangolin uses it internally/alongside to manage tunnel peers.
