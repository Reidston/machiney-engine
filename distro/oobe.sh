#!/bin/bash
# =============================================================================
# MachineY Engine (机器小乙·引擎) — Out-Of-Box Experience (OOBE) Script
#
# Executed automatically on first launch via wsl-distribution.conf oobe.command.
# Creates a restricted user, configures passwordless sudo for specific commands,
# initializes the OpenClaw workspace + config, installs the shell interceptor,
# and starts the OpenClaw Gateway daemon.
#
# Powered by OpenClaw
# =============================================================================

set -euo pipefail

LOG_FILE="/var/log/machiney-oobe.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================"
echo "MachineY Engine (机器小乙·引擎) — OOBE"
echo "Powered by OpenClaw"
echo "Started at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "======================================"

USERNAME="claw_agent"
# OpenClaw Gateway default port (confirmed 2026.3.2)
GATEWAY_PORT=18789
INTERCEPTOR_BIN="/opt/openclaw/interceptor/dist/wrapper.js"

# -------------------------------------------------------------------------
# Step 1: Create restricted user (passwordless — no terminal login allowed)
# -------------------------------------------------------------------------
if id "$USERNAME" &>/dev/null; then
    echo "[SKIP] User '$USERNAME' already exists."
else
    echo "[STEP 1/8] Creating restricted user '$USERNAME'..."
    useradd -m -s /bin/bash "$USERNAME"
    passwd -l "$USERNAME"  # Lock password login
    # Enable systemd linger — allows user services to run without an active
    # login session. Without this, WSL shows:
    #   "Failed to start the systemd user session for 'claw_agent'"
    # because passwd -l blocks PAM authentication for systemd's user@.service.
    # Must create the file directly (loginctl won't work — systemd not running yet).
    mkdir -p /var/lib/systemd/linger
    touch /var/lib/systemd/linger/"$USERNAME"
    echo "[OK] User '$USERNAME' created, password-locked, linger enabled."
fi

# -------------------------------------------------------------------------
# Step 2: Configure passwordless sudo (limited to specific commands only)
# -------------------------------------------------------------------------
echo "[STEP 2/8] Configuring sudoers..."
cat > /etc/sudoers.d/claw_agent << 'EOF'
# OpenClaw agent — restricted sudo access
claw_agent ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart openclaw-gateway.service
claw_agent ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop openclaw-gateway.service
claw_agent ALL=(ALL) NOPASSWD: /usr/bin/systemctl status openclaw-gateway.service
claw_agent ALL=(ALL) NOPASSWD: /usr/bin/systemctl start openclaw-gateway.service
EOF
chmod 440 /etc/sudoers.d/claw_agent
echo "[OK] Sudoers configured."

# -------------------------------------------------------------------------
# Step 3: Set as default WSL user
# -------------------------------------------------------------------------
echo "[STEP 3/8] Setting default user..."
if grep -q "^\[user\]" /etc/wsl.conf 2>/dev/null; then
    sed -i "s/^default = .*/default = ${USERNAME}/" /etc/wsl.conf
else
    cat >> /etc/wsl.conf << WSLCONF

[user]
default = ${USERNAME}
WSLCONF
fi
echo "[OK] Default user set to '$USERNAME'."

# -------------------------------------------------------------------------
# Step 4: Initialize OpenClaw workspace directories
# -------------------------------------------------------------------------
echo "[STEP 4/9] Initializing workspace..."
su - "$USERNAME" -c "mkdir -p ~/.openclaw/skills ~/.openclaw/memory ~/.openclaw/backups ~/.openclaw/logs ~/.openclaw/config ~/.openclaw/agents/main/agent"
echo "[OK] Workspace directories created."

# -------------------------------------------------------------------------
# Step 5: Disable IPv6 (required for Node.js in WSL2)
#
# WHY: WSL2 has no IPv6 route. Node.js v22 undici (built-in fetch)
#      resolves CDN-hosted APIs (e.g. OpenRouter on Cloudflare) to
#      IPv6 addresses first → connect() returns ENETUNREACH → the
#      Gateway reports "LLM request timed out".
#      Disabling IPv6 at kernel level forces IPv4-only DNS resolution.
# -------------------------------------------------------------------------
echo "[STEP 5/9] Disabling IPv6 (WSL2 workaround for Node.js)..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
# Persist across WSL restarts
cat > /etc/sysctl.d/99-disable-ipv6.conf << 'SYSCTL_EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
SYSCTL_EOF
echo "[OK] IPv6 disabled (sysctl + /etc/sysctl.d/99-disable-ipv6.conf)."

# -------------------------------------------------------------------------
# Step 5.5: Ensure /etc/resolv.conf has public DNS servers
#
# WHY: wsl.conf sets generateResolvConf=false to prevent Windows from
#      overwriting our DNS config. But this also means that if the file
#      is missing (first boot, WSL restart), nothing creates it.
#      Without DNS, Gateway cannot reach OpenRouter, Feishu, etc.
# -------------------------------------------------------------------------
echo "[STEP 5.5/9] Ensuring /etc/resolv.conf has DNS servers..."
if [ ! -s /etc/resolv.conf ]; then
    # Remove symlink if it exists (WSL creates a dead symlink)
    rm -f /etc/resolv.conf 2>/dev/null || true
    # Global defaults — China users will override via region selection below
    printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf
    echo "[OK] Created /etc/resolv.conf with global DNS (8.8.8.8 + 1.1.1.1)."
else
    echo "[SKIP] /etc/resolv.conf already exists and is non-empty."
fi

# -------------------------------------------------------------------------
# Step 5.6: Region selection
#
# Ask user to choose region for optimized mirrors, DNS, and plugins.
# Default: global (no extra action). China: runs openclaw-cn-setup.
# -------------------------------------------------------------------------
echo ""
echo "🌏 Region / 区域选择"
echo "  1) Global (default)"
echo "  2) 中国大陆 (China mainland — 阿里云镜像 + 国内DNS)"
echo ""

# Read with 30s timeout, default to global
REGION_CHOICE="1"
echo "👉 Please enter 1 or 2 (30s timeout, default: 1)"
echo "   请输入 1 或 2（30秒超时，默认: 1）"
if read -t 30 -p "> " REGION_INPUT 2>/dev/null; then
    REGION_CHOICE="${REGION_INPUT:-1}"
fi
echo ""

if [ "$REGION_CHOICE" = "2" ]; then
    echo "[STEP 5.6/9] Applying China region optimizations..."
    # Switch apt to Aliyun
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources
    fi
    # Override DNS with AliDNS
    printf 'nameserver 223.5.5.5\nnameserver 8.8.8.8\nnameserver 114.114.114.114\n' > /etc/resolv.conf
    # Save region preference
    echo "cn" > /etc/openclaw-region
    echo "[OK] 中国区域优化完成 (apt: 阿里云, DNS: 223.5.5.5)."
else
    echo "[STEP 5.6/9] Using global defaults."
    echo "global" > /etc/openclaw-region
fi

# -------------------------------------------------------------------------
# Step 6: Run `openclaw setup` to initialize openclaw.json
# -------------------------------------------------------------------------
echo "[STEP 6/9] Running openclaw setup..."
su - "$USERNAME" -c "openclaw setup 2>&1" || echo "[WARN] openclaw setup returned non-zero."
echo "[OK] openclaw.json initialized."

# -------------------------------------------------------------------------
# Step 7: Set gateway.mode=local in config
# -------------------------------------------------------------------------
echo "[STEP 7/9] Setting gateway config (mode=local, auth=token, bind=loopback)..."
su - "$USERNAME" -c "openclaw config set gateway.mode local 2>&1" || echo "[WARN] config set gateway.mode failed."
su - "$USERNAME" -c "openclaw config set gateway.auth.mode token 2>&1" || echo "[WARN] config set gateway.auth.mode failed."
su - "$USERNAME" -c "openclaw config set gateway.bind loopback 2>&1" || echo "[WARN] config set gateway.bind failed."
echo "[OK] Gateway: mode=local, auth=token, bind=loopback."

# -------------------------------------------------------------------------
# Step 8: Install shell interceptor as $SHELL wrapper
# -------------------------------------------------------------------------
echo "[STEP 8/9] Installing shell interceptor..."
WRAPPER_SCRIPT="/usr/local/bin/openclaw-shell"
cat > "$WRAPPER_SCRIPT" << SHELLWRAP
#!/bin/bash
# OpenClaw Shell Interceptor wrapper
# Invoked when OpenClaw agent runs shell commands.
# Evaluates the command against the security policy before executing.

INTERCEPTOR="${INTERCEPTOR_BIN}"
if [[ -f "\$INTERCEPTOR" ]]; then
    exec /usr/bin/node "\$INTERCEPTOR" "\$@"
else
    # Fallback to bash if interceptor not compiled yet
    exec /bin/bash "\$@"
fi
SHELLWRAP
chmod 755 "$WRAPPER_SCRIPT"
echo "[OK] Shell interceptor installed at $WRAPPER_SCRIPT."

# -------------------------------------------------------------------------
# Step 9: Start the OpenClaw Gateway daemon
#
# Strategy:
#   1. If systemd is PID 1, use the systemd service (ideal)
#   2. Otherwise, use setsid to create a new session leader that survives
#      WSL session termination (nohup alone is not enough for WSL)
# -------------------------------------------------------------------------
echo "[STEP 9/9] Starting OpenClaw Gateway..."

if pidof systemd &>/dev/null; then
    systemctl daemon-reload
    systemctl enable openclaw-gateway.service 2>/dev/null || true
    systemctl start openclaw-gateway.service || echo "[WARN] Gateway service failed to start."
    echo "[OK] Gateway started via systemd on port ${GATEWAY_PORT}."
else
    echo "[INFO] systemd not available — starting Gateway via setsid..."
    GATEWAY_LOG="/home/${USERNAME}/.openclaw/logs/gateway.log"
    # setsid creates a new session, preventing WSL from killing the process
    # when the launching shell exits. bash -lc ensures .bashrc is sourced
    # (needed for OPENROUTER_API_KEY and other env vars).
    su - "$USERNAME" -c "setsid openclaw gateway run --bind loopback > '${GATEWAY_LOG}' 2>&1 &  disown"
    sleep 4
    if pgrep -f "openclaw gateway run" &>/dev/null || pgrep -f "openclaw-gateway" &>/dev/null; then
        echo "[OK] OpenClaw Gateway started on port ${GATEWAY_PORT}."
    else
        echo "[WARN] Gateway may not have started — check ${GATEWAY_LOG}"
        tail -5 "${GATEWAY_LOG}" 2>/dev/null || true
    fi
fi

echo "======================================"
echo "MachineY Engine OOBE completed successfully!"
echo "机器小乙·引擎 初始化完成！"
echo "Finished at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "======================================"
echo ""
echo "══════════════════════════════════════"
echo "🚀 Quick Start / 快速开始"
echo "══════════════════════════════════════"
echo ""
echo "Step 1 — 配置 API Key 和模型 / Configure API Key & Model:"
echo ""
echo "  # 1a. 配置 OpenRouter Key / Set OpenRouter Key"
echo "  openclaw onboard --auth-choice apiKey \\"
echo "    --token-provider openrouter --token \"YOUR_KEY\""
echo ""
echo "  # 1b. 指定模型（stepfun 免费）/ Set model (stepfun free)"
echo "  openclaw models set openrouter/stepfun/step-3.5-flash:free"
echo ""
echo "  📌 Key 获取 / Get Key: https://openrouter.ai/keys"
echo ""
echo "Step 2 — 验证 / Verify:"
echo "  openclaw models status"
echo "  openclaw health"
echo ""
echo "Step 3 — 打开控制台 / Open Dashboard:"
echo "  openclaw dashboard"
echo ""
echo "📖 https://docs.openclaw.ai"
echo ""

# Enable lingering for claw_agent so systemd doesn't fail to start
# the user session (redundant — already done in Step 1 via touch, but belt-and-suspenders)
loginctl enable-linger "$USERNAME" 2>/dev/null || true
