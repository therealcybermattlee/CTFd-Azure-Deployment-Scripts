#!/bin/bash

#############################################
# CTFd Theme Diagnostic Script
# Checks theme installation and troubleshoots issues
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
THEME_NAME="cyber-theme"
CTFD_DIR="$HOME/CTFd"

# Logging function
log() {
    echo -e "$1"
}

# Header
clear
log "${BLUE}========================================${NC}"
log "${BLUE}     CTFd Theme Diagnostic Tool${NC}"
log "${BLUE}========================================${NC}"
echo ""

cd "$CTFD_DIR"

log "${YELLOW}[1] Checking theme directories...${NC}"
echo "Host system theme directory:"
ls -la data/CTFd/themes/ 2>/dev/null || echo "  ❌ Directory not found"

if [ -d "data/CTFd/themes/$THEME_NAME" ]; then
    log "${GREEN}  ✓ Theme directory exists${NC}"
    echo "  Theme files:"
    find "data/CTFd/themes/$THEME_NAME" -type f | head -10
else
    log "${RED}  ❌ Theme directory not found${NC}"
fi

log ""
log "${YELLOW}[2] Checking Docker volume mounts...${NC}"
if grep -q "themes:/opt/CTFd/CTFd/themes" docker-compose.yml; then
    log "${GREEN}  ✓ Themes volume mount configured${NC}"
    grep "themes:/opt/CTFd/CTFd/themes" docker-compose.yml | head -1
else
    log "${RED}  ❌ Themes volume mount NOT configured${NC}"
fi

log ""
log "${YELLOW}[3] Checking theme files inside container...${NC}"
docker compose exec ctfd ls -la /opt/CTFd/CTFd/themes/ 2>/dev/null || echo "  ❌ Failed to list container themes"

if docker compose exec ctfd test -d "/opt/CTFd/CTFd/themes/$THEME_NAME" 2>/dev/null; then
    log "${GREEN}  ✓ Theme exists in container${NC}"
    echo "  Theme structure in container:"
    docker compose exec ctfd find "/opt/CTFd/CTFd/themes/$THEME_NAME" -type f 2>/dev/null | head -10
else
    log "${RED}  ❌ Theme NOT found in container${NC}"
fi

log ""
log "${YELLOW}[4] Checking theme init file...${NC}"
if docker compose exec ctfd test -f "/opt/CTFd/CTFd/themes/$THEME_NAME/__init__.py" 2>/dev/null; then
    log "${GREEN}  ✓ __init__.py exists${NC}"
else
    log "${YELLOW}  ⚠ __init__.py missing (creating it now)${NC}"
    # Create __init__.py if missing
    touch "data/CTFd/themes/$THEME_NAME/__init__.py" 2>/dev/null || true
fi

log ""
log "${YELLOW}[5] Checking CTFd theme detection...${NC}"
docker compose exec ctfd python -c "
import os
theme_dir = '/opt/CTFd/CTFd/themes'
themes = [d for d in os.listdir(theme_dir) if os.path.isdir(os.path.join(theme_dir, d)) and not d.startswith('.')]
print('Available themes:', themes)
if '$THEME_NAME' in themes:
    print('✓ $THEME_NAME is detected by CTFd')
else:
    print('❌ $THEME_NAME is NOT detected by CTFd')
" 2>/dev/null || echo "  ❌ Failed to check theme detection"

log ""
log "${YELLOW}[6] Checking container logs for theme errors...${NC}"
docker compose logs ctfd --tail=20 2>&1 | grep -i "theme\|template" || echo "  No theme-related messages in recent logs"

log ""
log "${BLUE}========================================${NC}"
log "${BLUE}     Diagnostic Summary${NC}"
log "${BLUE}========================================${NC}"

# Check if we need to fix anything
NEEDS_FIX=false

if [ ! -d "data/CTFd/themes/$THEME_NAME" ]; then
    log "${RED}❌ Theme directory missing on host${NC}"
    NEEDS_FIX=true
fi

if ! grep -q "themes:/opt/CTFd/CTFd/themes" docker-compose.yml; then
    log "${RED}❌ Docker volume mount missing${NC}"
    NEEDS_FIX=true
fi

if ! docker compose exec ctfd test -d "/opt/CTFd/CTFd/themes/$THEME_NAME" 2>/dev/null; then
    log "${RED}❌ Theme not accessible in container${NC}"
    NEEDS_FIX=true
fi

if [ "$NEEDS_FIX" = true ]; then
    log ""
    log "${YELLOW}Issues detected. Run ./fix-theme-mount.sh to fix them.${NC}"
else
    log "${GREEN}✓ Theme appears to be properly installed${NC}"
    log ""
    log "${YELLOW}If theme still doesn't appear in dropdown:${NC}"
    log "  1. Check if __init__.py exists in theme directory"
    log "  2. Ensure theme follows CTFd structure"
    log "  3. Try a full container restart: docker compose down && docker compose up -d"
fi