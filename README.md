# MachineY Engine (机器小乙·引擎)

<p align="center">
  <strong>机器小乙，让你成为工作的甲方</strong><br/>
  <em>Secure AI Agent Runtime for Windows — Powered by OpenClaw</em>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#security">Security</a> •
  <a href="#build-from-source">Build from Source</a> •
  <a href="docs/security.md">Security Docs</a>
</p>

---

## What is MachineY Engine?

MachineY Engine (机器小乙·引擎) is a **pre-configured WSL2 distribution** that provides a secure, sandboxed environment for running AI agents on Windows. Powered by [OpenClaw](https://openclaw.ai).

- 🔒 4-layer security: WSL isolation → user restrictions → token auth → loopback binding
- 🌏 Region-aware: Global or China mainland (Aliyun mirrors + AliDNS)
- ⚡ Zero-config OOBE: creates user, sets up Gateway, starts services
- 🤖 OpenClaw + Node.js 22 pre-installed
- 🔧 systemd native with Gateway service

## Installation

### From Docker Hub (recommended)

```powershell
# 1. Pull the image
docker pull machiney/engine:latest

# 2. Export as .wsl file
docker create --name machiney-tmp machiney/engine:latest
docker export machiney-tmp -o machiney-engine.wsl
docker rm machiney-tmp

# 3. Install — double-click machiney-engine.wsl, or:
wsl --install --from-file machiney-engine.wsl
```

### From Source

```powershell
git clone https://github.com/Reidston/machiney-engine.git
cd machiney-engine
powershell -ExecutionPolicy Bypass -File distro/build.ps1
# Output: distro/install.tar.gz (~238 MB)
```

## Quick Start

After install, enter WSL:

```powershell
wsl -d machiney-engine -u claw_agent
```

### Step 1: Configure API Key & Model

```bash
# Set OpenRouter Key
openclaw onboard --auth-choice apiKey \
  --token-provider openrouter --token "YOUR_KEY"

# Set model (stepfun free — zero cost to verify)
openclaw models set openrouter/stepfun/step-3.5-flash:free
```

> 📌 Get a key at https://openrouter.ai/keys

### Step 2: Verify

```bash
openclaw models status     # Should show openrouter/stepfun/step-3.5-flash:free
openclaw health            # Check service health
```

### Step 3: Open Dashboard

```bash
openclaw dashboard         # Opens web control panel in browser
```

> 📖 Full docs: https://docs.openclaw.ai

## Security

| Layer | Mechanism | Protection |
|-------|-----------|------------|
| **L1** | WSL Isolation (`automount=false, interop=false`) | Blocks Windows file/program access |
| **L2** | User Isolation (restricted `claw_agent`) | Prevents privilege escalation |
| **L3** | Token Auth (`auth.mode=token`) | Secures Gateway API |
| **L4** | Loopback Binding (`bind=loopback`) | Blocks external access |

See [docs/security.md](docs/security.md) for the full architecture.

## Project Structure

```
├── distro/
│   ├── Dockerfile                 # Multi-stage build (Debian bookworm-slim)
│   ├── build.ps1                  # Build script
│   ├── oobe.sh                    # Out-of-Box Experience (first boot)
│   ├── configs/
│   │   ├── wsl.conf               # WSL security settings
│   │   └── wsl-distribution.conf  # Distribution metadata
│   ├── services/
│   │   └── openclaw-gateway.service
│   └── scripts/
│       └── openclaw-cn-setup      # China region optimization
├── .github/
│   └── workflows/
│       └── docker-publish.yml     # Auto-build & push to Docker Hub
├── docs/
│   └── security.md
├── LICENSE                        # Apache 2.0
└── README.md
```

## MachineY Studio (Coming Soon)

**机器小乙·工坊 (MachineY Studio)** — Windows companion app:

- 🖥️ GUI Dashboard & Setup Wizard
- 🔐 Secure WSL ↔ Windows bridge
- ✅ Human-in-the-loop command approval
- 📊 Audit logging

## About

**机器小乙 (MachineY)** — 让你成为工作的甲方。

Built by [机器小乙](https://jiqixiaoyi.cn). AI runtime powered by [OpenClaw](https://openclaw.ai).

## License

Apache License 2.0 — see [LICENSE](LICENSE).
