---
name: unraid-guru
description: Expert Unraid management. Focuses on Docker Templates (XML), Community Applications, Array/Pool configuration, and VM optimization.
license: MIT
---

## What I do
- Write valid Unraid Docker Template XML files.
- Debug "Docker container failed to start" or "Execution Error" issues.
- Optimize Share settings (Cache -> Array mover behavior).
- Configure Parity checks and Notification agents.

## When to use me
- When creating a template for Community Applications (CA).
- When debugging Unraid server issues.
- When configuring Unraid storage pools.
- Triggers: "unraid", "docker template", "ca template", "parity", "cache pool".

## Instructions

### 1. Docker Templates (XML)
- **Structure**:
  ```xml
  <Container version="2">
    <Name>My App</Name>
    <Repository>user/image:tag</Repository>
    <Registry>https://hub.docker.com/r/user/image</Registry>
    <Network>bridge</Network>
    <Config Name="WebUI" Target="8080" Default="8080" Mode="tcp" Description="..." Type="Port" Display="always" Required="true" Mask="false">8080</Config>
    <Config Name="Data" Target="/data" Default="/mnt/user/appdata/myapp" Mode="rw" Description="..." Type="Path" Display="always" Required="true" Mask="false">/mnt/user/appdata/myapp</Config>
  </Container>
  ```
- **Icon**: Always provide an image URL.
- **WebUI**: Define the web interface port so "WebUI" button works in dashboard.

### 2. Storage Best Practices
- **Appdata**: MUST live on the Cache Pool (NVMe/SSD). Set share to `Cache: Only` or `Primary: Cache` (Unraid 6.12+).
- **Mover**: Don't run mover while heavy downloads are active.
- **XFS vs BTRFS vs ZFS**:
  - *Array*: XFS is standard (independent drives).
  - *Cache*: BTRFS (raid1) or ZFS (modern/robust) for pools.

### 3. Troubleshooting
- **Logs**: Tools -> Syslog. Look for "Call Trace" (Hardware issue) or "OOM" (Out of Memory).
- **Fix Common Permissions**: Tools -> Docker Safe New Perms (Fixes file access issues in shares).
