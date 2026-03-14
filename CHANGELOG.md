# Changelog

All notable changes to MachineY Engine (机器小乙·引擎) will be documented in this file.

## [0.4.0] - 2026-03-14

### 🎉 Initial Public Release

**Installation**
- Docker Hub: `docker pull machiney/engine:latest`
- Build from source with `distro/build.ps1`
- Automatic OOBE (Out-of-Box Experience) on first launch

**Security**
- WSL isolation: `automount=false`, `interop=false`
- Restricted user: `claw_agent` with locked password and limited sudo
- Token authentication: `gateway.auth.mode=token` (auto-generated)
- Loopback binding: Gateway only accessible from localhost
- systemd linger enabled

**Runtime**
- OpenClaw 2026.3.12 pre-installed
- Node.js 22 LTS
- Debian bookworm-slim base
- systemd native with Gateway service
- dbus-user-session for WSL2 compatibility

**Region Support**
- Global defaults (deb.debian.org + 8.8.8.8 DNS)
- China mainland option: Aliyun apt mirror + AliDNS (223.5.5.5)
