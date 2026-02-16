# Security Policy

This document outlines security best practices and the shared responsibility model for running WineBot.

## 1. Shared Responsibility
WineBot provides a Windows compatibility layer inside a Linux container. Because Wine runs Windows binaries with the same privileges as the `winebot` user, a compromised Windows application can theoretically access any data within the container or attempt to pivot to your local network.

## 2. Recommended Hardening

### Network Isolation
If your automation does not require internet access, run the container with network isolation:
```bash
docker run --network none ...
```
In `docker-compose.yml`, use an internal network:
```yaml
networks:
  winebot-net:
    internal: true
```

### VNC Security (Encryption)
VNC traffic is **not encrypted** by default. To secure the remote desktop:
1. Bind VNC to localhost only: `VNC_BIND=127.0.0.1`.
2. Use an **SSH Tunnel** to access the desktop:
   ```bash
   ssh -L 5900:localhost:5900 user@remote-host
   ```
3. Always set a strong `VNC_PASSWORD`.

### API Protection
Always set an `API_TOKEN` in production environments. The dashboard and CLI will require this token to perform any actions.

### File System Safety
Mount your `apps/` and `automation/` directories as **Read-Only** (`:ro`) to prevent malicious scripts from modifying your local source files or installers. (Enabled by default in `compose/docker-compose.yml`).

## 3. Reporting a Vulnerability
If you discover a security vulnerability in WineBot, please open a GitHub Issue or contact the maintainers directly. Do not disclose sensitive bugs in public comments until a patch is available.
