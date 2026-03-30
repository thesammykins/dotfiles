---
name: pocket-id-provider
description: Setup and integration of Pocket-ID, the passkey-first OIDC provider. Handles simple, secure identity for homelabs.
license: MIT
---

## What I do
- Deploy `pocket-id/pocket-id` with persistence.
- Configure OIDC Clients (Client ID, Secret, Redirect URIs).
- Setup Passkey (WebAuthn) users.
- Integrate Pocket-ID with Traefik (Forward Auth) or App Services.

## When to use me
- When user needs "Simple SSO" or "Passkey Login" for self-hosted apps.
- When configuring `pocket-id`.
- Triggers: "pocket-id", "oidc", "passkey", "identity provider", "sso".

## Instructions

### 1. Deployment
- **Image**: `pocket-id/pocket-id:latest`.
- **Domain**: MUST run on HTTPS (Passkeys requirement).
- **Environment**:
  - `PUBLIC_URL`: `https://auth.example.com` (Must match public access).
- **Volume**: Mount `/app/backend/data` for DB persistence.

### 2. Configuration
- **First Run**: Access UI to create the Admin user (Registers first passkey).
- **Clients**: Create a generic OIDC client.
  - *Redirect URI*: `https://app.example.com/oauth/callback`
  - *Scopes*: `openid`, `profile`, `email`.

### 3. Integration Patterns
- **Traefik Forward Auth**: Use a middleware (like `thomseddon/traefik-forward-auth` or `oauth2-proxy`) pointing to Pocket-ID's OIDC discovery endpoint (`/.well-known/openid-configuration`).
- **Direct Support**: Apps like Grafana, Portainer, Audiobookshelf support OIDC directly. Use the Client ID/Secret there.
