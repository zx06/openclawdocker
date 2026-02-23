#!/bin/bash
#
# OpenClaw Docker Installer
# One-command setup for OpenClaw on Docker
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/zx06/openclaw-docker/master/install.sh)
#
# Or with options:
#   bash <(curl -fsSL https://raw.githubusercontent.com/zx06/openclaw-docker/master/install.sh) --no-start
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Config
INSTALL_DIR="${OPENCLAW_INSTALL_DIR:-$HOME/openclaw}"
IMAGE="ghcr.io/zx06/openclaw:latest"
REPO_URL="https://github.com/zx06/openclaw-docker"
COMPOSE_URL="https://raw.githubusercontent.com/zx06/openclaw-docker/master/docker-compose.yml"

# Flags
NO_START=false
SKIP_ONBOARD=false
PULL_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-start) NO_START=true; shift ;;
        --skip-onboard) SKIP_ONBOARD=true; shift ;;
        --pull-only) PULL_ONLY=true; shift ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --help|-h)
            echo "OpenClaw Docker Installer"
            echo ""
            echo "Usage: install.sh [OPTIONS]"
            echo "  --install-dir DIR   Installation directory (default: ~/openclaw)"
            echo "  --no-start          Don't start the gateway after setup"
            echo "  --skip-onboard      Skip onboarding wizard"
            echo "  --pull-only         Only pull the image, don't set up"
            echo "  --help, -h          Show this help"
            exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

log_step()    { echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          OpenClaw Docker Installer (zx06)            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

log_step "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    log_error "Docker not found. Install: https://docs.docker.com/get-docker/"
    exit 1
fi
log_success "docker found"

if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    log_success "Docker Compose found (plugin)"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    log_success "Docker Compose found (standalone)"
else
    log_error "Docker Compose not found. Install: https://docs.docker.com/compose/install/"
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi
log_success "Docker is running"

if [ "$PULL_ONLY" = true ]; then
    log_step "Pulling OpenClaw image..."
    docker pull "$IMAGE"
    log_success "Done!"
    exit 0
fi

log_step "Setting up installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
curl -fsSL "$COMPOSE_URL" -o docker-compose.yml
log_success "Downloaded docker-compose.yml"

log_step "Creating data directories..."
mkdir -p ~/.openclaw ~/.openclaw/workspace
log_success "Created ~/.openclaw and ~/.openclaw/workspace"

log_step "Pulling OpenClaw image..."
docker pull "$IMAGE"
log_success "Image pulled"

if [ "$SKIP_ONBOARD" = false ]; then
    log_step "Running onboarding wizard..."
    echo -e "${YELLOW}Follow the prompts to configure your AI provider and channels.${NC}\n"
    if ! $COMPOSE_CMD run --rm openclaw-cli onboard; then
        log_warning "Onboarding skipped. Run later: cd $INSTALL_DIR && $COMPOSE_CMD run --rm openclaw-cli onboard"
    else
        log_success "Onboarding complete!"
    fi
fi

if [ "$NO_START" = false ]; then
    log_step "Starting OpenClaw gateway..."
    $COMPOSE_CMD up -d openclaw
    echo -n "Waiting for gateway"
    for i in {1..30}; do
        if curl -sf http://localhost:18789/healthz &> /dev/null; then
            echo ""
            log_success "Gateway is running!"
            break
        fi
        echo -n "."; sleep 1
    done
    if ! curl -sf http://localhost:18789/healthz &> /dev/null; then
        echo ""
        log_warning "Gateway may still be starting. Check: docker logs -f openclaw"
    fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         🎉 OpenClaw installed successfully!           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Access:${NC}       http://localhost:18789"
echo -e "${BOLD}Config:${NC}       ~/.openclaw/"
echo -e "${BOLD}Install dir:${NC}  $INSTALL_DIR"
echo ""
echo -e "${BOLD}Commands:${NC}"
echo -e "  ${CYAN}Logs:${NC}     docker logs -f openclaw"
echo -e "  ${CYAN}Stop:${NC}     cd $INSTALL_DIR && $COMPOSE_CMD down"
echo -e "  ${CYAN}Start:${NC}    cd $INSTALL_DIR && $COMPOSE_CMD up -d openclaw"
echo -e "  ${CYAN}Update:${NC}   docker pull $IMAGE && $COMPOSE_CMD up -d openclaw"
echo -e "  ${CYAN}CLI:${NC}      cd $INSTALL_DIR && $COMPOSE_CMD run --rm openclaw-cli <cmd>"
echo ""
echo -e "${BOLD}Repo:${NC} $REPO_URL"
echo ""
