FROM node:24-bookworm

LABEL org.opencontainers.image.source="https://github.com/zx06/openclaw-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw Docker image with Playwright and Feishu support"
LABEL org.opencontainers.image.licenses="MIT"

ENV \
    NODE_ENV=production \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    npm_config_registry=https://registry.npmmirror.com \
    TZ=Asia/Shanghai

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    wget \
    gnupg \
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

# Install Node.js global packages
RUN npm install -g openclaw@latest \
    && npm install -g playwright \
    && npm install -g @larksuiteoapi/node-sdk \
    && npm install -g @iflow-ai/iflow-cli \
    && npm install -g opencode-ai \
    && npm install -g @github/copilot \
    && npm install -g @playwright/test \
    && npx playwright install chromium --with-deps \
    && chmod -R o+rx /home/node/.cache/ms-playwright

# Create directories
RUN mkdir -p /home/node/.openclaw /home/node/.cache && \
    chown -R node:node /home/node/.openclaw /home/node/.cache

USER node
WORKDIR /home/node

VOLUME ["/home/node/.openclaw"]

EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD openclaw status || exit 1

# Use tini as init process for proper signal handling
ENTRYPOINT ["tini", "--", "openclaw", "gateway", "run", "--allow-unconfigured"]
