# =============================================================================
# OpenClaw WSL Distribution — Rootfs Builder (v3 — Multi-Stage Extreme Slim)
#
# Strategy: Build stage installs everything (build tools + openclaw).
#           Runtime stage copies ONLY what's needed to run.
#
# Target: ~1.5 GB raw → ~500 MB compressed (install.tar.gz)
# =============================================================================

# ===========================
# STAGE 1: Builder
# ===========================
FROM debian:bookworm-slim AS builder

# Use official Debian sources (global distribution)
# China users can switch to Aliyun mirror post-install via openclaw-cn-setup

# Install ALL build dependencies (these stay in builder only)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git build-essential cmake python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js v22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally (this compiles native modules with build-essential)
RUN npm install -g openclaw || npm install -g openclaw --registry=https://registry.npmmirror.com

# ===========================
# STAGE 2: Runtime (minimal)
# ===========================
FROM debian:bookworm-slim AS runtime

LABEL maintainer="MachineY Team"
LABEL description="MachineY Linux — Secure AI Agent Runtime (Powered by OpenClaw)"

# Use official Debian sources (global distribution)

# Install ONLY runtime dependencies (no build tools, no python, no perl extras)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    sudo \
    openssl \
    systemd \
    dbus \
    dbus-user-session \
    procps \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Ensure /sbin/init → systemd (required for WSL2 systemd boot)
RUN ln -sf /usr/lib/systemd/systemd /sbin/init

# Copy Node.js binary from builder (just the binary, ~119MB)
COPY --from=builder /usr/bin/node /usr/bin/node

# Copy npm (needed for openclaw plugin management)
COPY --from=builder /usr/lib/node_modules/npm /usr/lib/node_modules/npm
RUN ln -sf /usr/lib/node_modules/npm/bin/npm-cli.js /usr/bin/npm \
    && ln -sf /usr/lib/node_modules/npm/bin/npx-cli.js /usr/bin/npx

# Copy OpenClaw (the core, ~942MB)
COPY --from=builder /usr/lib/node_modules/openclaw /usr/lib/node_modules/openclaw
RUN ln -sf /usr/lib/node_modules/openclaw/openclaw.mjs /usr/bin/openclaw \
    && chmod +x /usr/bin/openclaw

# -----------------------------------------------------------------------------
# Configuration files
# -----------------------------------------------------------------------------
COPY distro/configs/wsl.conf /etc/wsl.conf
COPY distro/configs/wsl-distribution.conf /etc/wsl-distribution.conf

# Note: /etc/resolv.conf is created at runtime, not build time.
# Docker bind-mounts resolv.conf during build (can't rm/overwrite).
# DNS is guaranteed by: oobe.sh, Tauri ensure_dns, systemd ExecStartPre.

# systemd service
COPY distro/services/openclaw-gateway.service /etc/systemd/system/openclaw-gateway.service

# OOBE script
COPY distro/oobe.sh /etc/oobe.sh
RUN chmod +x /etc/oobe.sh

# Region-specific setup scripts (user runs manually or OOBE offers)
COPY distro/scripts/openclaw-cn-setup /usr/local/bin/openclaw-cn-setup
RUN chmod +x /usr/local/bin/openclaw-cn-setup

# Application icon (PNG for WSL shortcut — wsl-distribution.conf shortcut.icon)
# TODO: Replace with final MachineY logo when ready
RUN mkdir -p /usr/share/icons \
    && echo "placeholder" > /usr/share/icons/machiney.png

# -----------------------------------------------------------------------------
# WSL compliance: mask conflicting systemd services
# See: https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro
# -----------------------------------------------------------------------------
RUN systemctl mask \
    systemd-resolved.service \
    systemd-networkd.service \
    NetworkManager.service \
    systemd-tmpfiles-setup.service \
    systemd-tmpfiles-clean.service \
    systemd-tmpfiles-clean.timer \
    systemd-tmpfiles-setup-dev-early.service \
    systemd-tmpfiles-setup-dev.service \
    tmp.mount \
    2>/dev/null || true

# -----------------------------------------------------------------------------
# WSL compliance: remove /etc/resolv.conf so WSL auto-generates DNS config
# -----------------------------------------------------------------------------
RUN rm -f /etc/resolv.conf

# -----------------------------------------------------------------------------
# Final cleanup — remove every byte we don't need
# -----------------------------------------------------------------------------
RUN rm -rf /usr/share/doc /usr/share/man /usr/share/info /usr/share/lintian \
    && rm -rf /usr/lib/x86_64-linux-gnu/gconv \
    && rm -rf /usr/lib/x86_64-linux-gnu/perl* \
    && rm -rf /usr/share/perl* /usr/lib/perl* \
    && rm -rf /var/log/* /tmp/* /var/tmp/* /var/cache/apt/* \
    && rm -rf /root/.npm /root/.cache \
    && rm -rf /usr/lib/modules \
    && rm -rf /usr/include \
    && apt-get clean
