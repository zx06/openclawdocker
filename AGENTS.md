# Project Guidelines

## Code Style
- 本仓库以 Docker/Compose/GitHub Actions 配置为主，风格是声明式 YAML + 命令式 Shell。
- Dockerfile 约定：`apt-get install --no-install-recommends` 后立即清理缓存（`rm -rf /var/lib/apt/lists/*`、`apt-get clean`）。
- 入口进程统一使用 `tini`；健康检查统一使用：`openclaw gateway health >/dev/null 2>&1 || openclaw gateway status >/dev/null 2>&1`。
- 运行参数优先放在 `ENV`，例如 `NODE_ENV=production`、npm 静默相关配置、`TZ=Asia/Shanghai`。

## Architecture
- 双镜像结构：
  - `Dockerfile`：完整版（含 `agent-browser`、浏览器依赖、飞书相关 SDK）。
  - `Dockerfile.mini`：精简版（仅保留核心运行依赖，不含浏览器栈）。
- `docker-compose.yml` 有 3 个服务：
  - `openclaw`：主网关服务（18789/18790）。
  - `socat-proxy`：`18790 -> 127.0.0.1:18789` 端口代理兼容层。
  - `openclaw-cli`：CLI 交互容器（`profiles: [cli]`）。
- 持久化目录统一挂载到 `~/.openclaw` 与 `~/.openclaw/workspace`。

## Build and Test
- 本地构建：
  - `docker build -t ghcr.io/zx06/openclaw:local .`
  - `docker build -f Dockerfile.mini -t ghcr.io/zx06/openclaw:mini-local .`
- 本地运行（主服务）：
  - `docker compose up -d openclaw`
  - `docker compose logs -f`
  - `docker compose down`
- 快速验证（与 CI smoke-test 对齐）：
  - `docker build -t openclaw:smoke .`
  - `docker run --rm --entrypoint sh openclaw:smoke -lc "openclaw --help >/dev/null"`
  - `docker run --rm --entrypoint bash openclaw:smoke -lc 'OUT="$(agent-browser open http://example.com)"; echo "$OUT" | grep -q "Example Domain"'`
  - `docker build -f Dockerfile.mini -t openclaw:smoke-mini .`

## Project Conventions
- 标签约定：
  - full：`latest`、`daily-YYYYMMDD`
  - mini：`mini-latest`、`mini-daily-YYYYMMDD`
- 构建触发约定：
  - `master` 分支相关文件变更触发构建。
  - 每日定时任务兜底构建。
  - PR/Push 对 Docker 关键文件触发 smoke-test。
- 版本追踪约定：`.last-openclaw-version` 记录上次构建的 npm `openclaw` 版本；每 6 小时检查新版本并触发 `docker.yml`。

## Integration Points
- 镜像发布到两个仓库：GHCR 与阿里云 ACR（多架构清单合并后发布）。
- 运行依赖包含 `openclaw`、`agent-browser`（完整版）、`@larksuiteoapi/node-sdk` 等全局 npm 包。
- `PLAYWRIGHT_BROWSERS_PATH=/ms-playwright` 是浏览器二进制可见性的关键路径（构建阶段与运行用户共享）。

## Security
- 容器默认以非 root 用户 `node` 运行。
- Registry 登录凭据来自 GitHub Secrets（`ACR_USERNAME`、`ACR_PASSWORD`、`GITHUB_TOKEN`），仓库中不应写入明文凭据。
- 修改健康检查、入口命令、端口映射时，需同步检查 `Dockerfile`、`docker-compose.yml` 与 `.github/workflows/smoke-test.yml`，避免运行态与 CI 规则漂移。

## 关键参考文件
- `README.md`
- `Dockerfile`
- `Dockerfile.mini`
- `docker-compose.yml`
- `.github/workflows/docker.yml`
- `.github/workflows/smoke-test.yml`
- `.github/workflows/openclaw-release-tracker.yml`
