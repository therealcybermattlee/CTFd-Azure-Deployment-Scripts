#!/bin/bash

#############################################
# Emergency Fix for 500 Internal Server Error
# Removes theme mount that's breaking CTFd
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CTFD_DIR="$HOME/CTFd"

# Logging function
log() {
    echo -e "$1"
}

# Header
clear
log "${RED}========================================${NC}"
log "${RED}     EMERGENCY FIX - 500 Error${NC}"
log "${RED}========================================${NC}"
echo ""

cd "$CTFD_DIR"

log "${YELLOW}[1] Removing problematic theme mount from docker-compose.yml...${NC}"

# Remove the theme mount line that's causing issues
sed -i '/\/opt\/CTFd\/CTFd\/themes/d' docker-compose.yml

log "${GREEN}✓ Removed theme mount${NC}"

log "${YELLOW}[2] Stopping CTFd...${NC}"
docker compose down

log "${YELLOW}[3] Starting CTFd without theme mount...${NC}"
docker compose up -d

log "${YELLOW}[4] Waiting for CTFd to start...${NC}"
sleep 15

# Check if CTFd is responding
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}✓ CTFd is responding normally${NC}"
else
    log "${YELLOW}⚠ CTFd may still be starting up${NC}"
fi

log ""
log "${GREEN}========================================${NC}"
log "${GREEN}     Site Should Be Working Now${NC}"
log "${GREEN}========================================${NC}"
log ""
log "${YELLOW}The theme mount has been removed.${NC}"
log "${YELLOW}CTFd should be working with the default theme.${NC}"
log ""
log "${BLUE}We'll need a different approach for custom themes.${NC}"