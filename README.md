# OpenClaw Docker

每日自动构建的 OpenClaw Docker 镜像，支持飞书、Playwright 浏览器功能。

## 特性

- 基于 Node.js 24 LTS + Debian Bookworm
- 包含 Playwright Chromium 浏览器
- 支持飞书插件依赖
- 中文字体支持（避免截图乱码）
- 国内 npm 镜像加速
- socat-proxy 代理服务（兼容 Synology NAS 等特殊网络环境）
- 智能版本追踪：检测到 openclaw npm 新版本时自动触发构建

## 快速开始

### 一键安装（推荐）

**Linux / macOS:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zx06/openclaw-docker/master/install.sh)
```

**Windows PowerShell:**
```powershell
irm https://raw.githubusercontent.com/zx06/openclaw-docker/master/install.ps1 | iex
```

### 使用 Docker Compose

```bash
# 启动
docker compose up -d openclaw

# 查看日志
docker compose logs -f

# 停止
docker compose down
```

### 使用 Docker

```bash
# 拉取镜像
docker pull ghcr.io/zx06/openclaw:latest

# 运行
docker run -d \
  --name openclaw \
  -p 18789:18789 \
  -v ~/.openclaw:/home/node/.openclaw \
  ghcr.io/zx06/openclaw:latest
```

## 首次配置

容器启动后，运行配置向导：

```bash
docker compose run --rm openclaw-cli onboard
```

> 说明：若未先完成 `onboard`，直接启动 `openclaw gateway` 可能提示缺少配置并退出。

## 访问

| 服务 | 地址 |
|------|------|
| Control UI | http://localhost:18789 |
| Gateway | ws://localhost:18789 |
| socat-proxy | ws://localhost:18790 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `npm_config_registry` | https://registry.npmmirror.com | npm 镜像 |
| `OPENCLAW_SKIP_SERVICE_CHECK` | true | 跳过服务检查，避免启动失败 |

## 镜像标签

| 标签 | 说明 |
|------|------|
| `latest` | 最新构建 |
| `daily-YYYYMMDD` | 每日构建 |
| `mini-latest` | 精简版（仅必要依赖） |
| `mini-daily-YYYYMMDD` | 精简版每日构建 |

## 本地构建

```bash
docker build -t ghcr.io/zx06/openclaw:local .
docker build -f Dockerfile.mini -t ghcr.io/zx06/openclaw:mini-local .
```

## 使用 Mini 版本

```bash
docker pull ghcr.io/zx06/openclaw:mini-latest
```

## 故障排查

### 查看日志

```bash
docker compose logs -f openclaw
```

### 进入容器调试

```bash
docker exec -it openclaw /bin/bash
```

### 检查状态

```bash
docker exec -it openclaw openclaw status
```
