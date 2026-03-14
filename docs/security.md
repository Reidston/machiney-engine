# Security Architecture

MachineY Engine (机器小乙·引擎) implements a 4-layer defense model to protect the host system from uncontrolled AI agent behavior.

## Threat Model

| # | Threat | Example | Severity |
|---|--------|---------|----------|
| T1 | **Misoperation** | Agent runs `rm -rf ./*` on wrong path | 🔴 High |
| T2 | **Unauthorized Access** | Agent reads Windows files via `/mnt/c/` | 🔴 High |
| T3 | **Prompt Injection** | Malicious user injects commands via chat | 🔴🔴 Critical |
| T4 | **Data Exfiltration** | Agent uploads local files via `curl` | 🔴 High |
| T5 | **Persistence** | Agent adds crontab entries or modifies `.bashrc` | 🟡 Medium |

## Defense Layers

### Layer 1: WSL Isolation (wsl.conf)

```ini
[automount]
enabled = false       # Windows filesystem NOT mounted
[interop]
enabled = false       # Cannot call Windows executables
appendWindowsPath = false
```

**Effect**: Agent cannot see or access any Windows files. `/mnt/c/` does not exist. Cannot call `cmd.exe`, `powershell.exe`, or any Windows program.

This is the **hardest security boundary** — OS-level isolation that the agent cannot bypass.

### Layer 2: User Isolation (claw_agent)

- Password locked (`passwd -l`) — no terminal login
- sudoers limited to 4 systemctl commands only
- Cannot install system packages
- Cannot modify system files

### Layer 3: Token Authentication

```json
{
  "gateway": {
    "auth": { "mode": "token" }
  }
}
```

- Auto-generated random token on first setup
- Required for WebSocket and HTTP API access
- Access via `openclaw dashboard` (auto-attaches token)

### Layer 4: Network Isolation

```json
{
  "gateway": {
    "bind": "loopback"
  }
}
```

- Gateway only listens on `127.0.0.1`
- Not accessible from the network
- Only the local user can access the API

## Coverage Matrix

```
                    T1       T2       T3       T4       T5
                  Misop  Unauth   Inject   Exfil   Persist
┌──────────────┬───────────────────────────────────────────┐
│ WSL Isolation │   —      ✅✅     —       —       —     │
│ User Isolat.  │   ✅      —      —       —       ✅    │
│ Token Auth    │   —       —      —       —       —     │
│ Network Isol. │   —       —      —       ✅      —     │
│ Interceptor*  │   ✅      —      ✅      ✅      ✅    │
└──────────────┴───────────────────────────────────────────┘

* Interceptor is available in OpenClaw Studio Pro (coming soon)
```

## Reporting Security Issues

If you discover a security vulnerability, please email: security@openclaw-ai.com
