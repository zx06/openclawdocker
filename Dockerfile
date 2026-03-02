FROM node:24-bookworm

LABEL org.opencontainers.image.source="https://github.com/zx06/openclaw-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw Docker image with agent-browser and Feishu support"
LABEL org.opencontainers.image.licenses="MIT"

ENV \
    NODE_ENV=production \
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
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends \
    gh \
    docker.io \
    jq \
    ripgrep \
    fd-find \
    bat \
    git \
    htop \
    vim \
    tmux \
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
    && update-alternatives --install /usr/bin/fd fd /usr/bin/fdfind 100 \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -fv \
    && apt-get clean

# Use pinned OpenClaw version from .last-openclaw-version
COPY .last-openclaw-version /tmp/.last-openclaw-version
# Install Node.js global packages in one layer to improve cache reuse and reduce image size
RUN OPENCLAW_VERSION="$(cat /tmp/.last-openclaw-version)" && \
    npm install -g \
    "openclaw@${OPENCLAW_VERSION}" \
    agent-browser \
    @larksuiteoapi/node-sdk \
    @iflow-ai/iflow-cli \
    opencode-ai \
    @github/copilot \
    @mariozechner/pi-coding-agent \
    clawhub \
    skills \
    && npm cache clean --force

# Create directories
RUN mkdir -p /home/node/.openclaw && \
    chown -R node:node /home/node/.openclaw

USER node
WORKDIR /home/node

RUN agent-browser install --with-deps && \
    openclaw completion --shell bash > .bashrc

VOLUME ["/home/node/.openclaw"]

EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD openclaw gateway health >/dev/null 2>&1 || openclaw gateway status >/dev/null 2>&1

# Use tini as init process for proper signal handling
ENTRYPOINT ["tini", "--", "openclaw", "gateway", "run", "--allow-unconfigured"]
