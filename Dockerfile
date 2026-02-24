FROM node:24-bookworm

LABEL org.opencontainers.image.source="https://github.com/zx06/openclaw-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw Docker image with Playwright and Feishu support"
LABEL org.opencontainers.image.licenses="MIT"

ENV \
    NODE_ENV=production \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    npm_config_registry=https://registry.npmmirror.com \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false \
    TZ=Asia/Shanghai

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    wget \
    gnupg \
    docker.io \
    jq \
    git \
    htop \
    iputils-ping \
    dnsutils \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libdbus-1-3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libx11-6 \
    libxext6 \
    ffmpeg \
    libopus0 \
    fonts-noto-cjk \
    fonts-wqy-zenhei \
    tini \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -fv \
    && apt-get clean

# Install Node.js global packages in one layer to improve cache reuse and reduce image size
RUN npm install -g \
    openclaw@latest \
    playwright \
    @larksuiteoapi/node-sdk \
    @iflow-ai/iflow-cli \
    opencode-ai \
    @github/copilot \
    @playwright/test \
    && npm cache clean --force \
    && npx playwright install chromium --with-deps \
    && chmod -R o+rx /home/node/.cache/ms-playwright

# Configure bash completion at build time (best-effort)
RUN mkdir -p /usr/share/bash-completion/completions && \
    (openclaw completion bash > /usr/share/bash-completion/completions/openclaw \
      || openclaw completion > /usr/share/bash-completion/completions/openclaw \
      || openclaw autocomplete > /usr/share/bash-completion/completions/openclaw \
      || true) && \
    if [ ! -s /usr/share/bash-completion/completions/openclaw ]; then \
      rm -f /usr/share/bash-completion/completions/openclaw; \
    fi

# Create directories
RUN mkdir -p /home/node/.openclaw /home/node/.cache && \
    chown -R node:node /home/node/.openclaw /home/node/.cache && \
    touch /home/node/.bashrc && \
    grep -Fq '/usr/share/bash-completion/completions/openclaw' /home/node/.bashrc \
      || echo '[ -f /usr/share/bash-completion/completions/openclaw ] && source /usr/share/bash-completion/completions/openclaw' >> /home/node/.bashrc

USER node
WORKDIR /home/node

VOLUME ["/home/node/.openclaw"]

EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD openclaw gateway health >/dev/null 2>&1 || openclaw gateway status >/dev/null 2>&1

# Use tini as init process for proper signal handling
ENTRYPOINT ["tini", "--", "openclaw", "gateway", "run", "--allow-unconfigured"]
