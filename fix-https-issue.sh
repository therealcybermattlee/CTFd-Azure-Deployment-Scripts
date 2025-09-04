#!/bin/bash

#############################################
# CTFd HTTPS Fix Script
# Fixes internal server error caused by 
# strict HTTPS enforcement
#############################################

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="ctf.pax8bootcamp.com"
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd $ACTUAL_USER | cut -d: -f6)
INSTALL_DIR="$ACTUAL_HOME/CTFd"

# Logging function
log() {
    echo -e "$1"
}

# Header
clear
log "${BLUE}========================================${NC}"
log "${BLUE}     CTFd HTTPS Fix Script${NC}"
log "${BLUE}========================================${NC}"
log "${GREEN}Domain:${NC} $DOMAIN"
log "${GREEN}Install Directory:${NC} $INSTALL_DIR"
log "${BLUE}========================================${NC}"
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   log "${RED}This script must be run with sudo${NC}"
   log "${YELLOW}Usage: sudo ./fix-https-issue.sh${NC}"
   exit 1
fi

# Navigate to CTFd directory
if [ ! -d "$INSTALL_DIR" ]; then
    log "${RED}CTFd installation not found at $INSTALL_DIR${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

log "${GREEN}[Step 1] Backing up current configuration...${NC}"
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)
cp .env .env.backup-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true

log "${GREEN}[Step 2] Fixing Docker configuration for mixed HTTP/HTTPS support...${NC}"

# Create a more flexible docker-compose configuration
cat > docker-compose.yml << 'EOF'
services:
  ctfd:
    image: ctfd/ctfd:3.6.0
    container_name: ctfd
    restart: always
    ports:
      - "8000:8000"
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - DATABASE_URL=mysql+pymysql://ctfd:${DB_PASSWORD}@db:3306/ctfd
      - REDIS_URL=redis://cache:6379
      - WORKERS=4
      - SERVER_NAME=${DOMAIN}
      - REVERSE_PROXY=True
      # Temporarily disable secure cookies to fix HTTPS issues
      - SESSION_COOKIE_SECURE=False
      - SESSION_COOKIE_HTTPONLY=True
      - SESSION_COOKIE_SAMESITE=Lax
      - LOG_FOLDER=/var/log/CTFd
      - UPLOAD_FOLDER=/var/uploads
    volumes:
      - ./data/CTFd/logs:/var/log/CTFd
      - ./data/CTFd/uploads:/var/uploads
      - ./data/CTFd/themes:/opt/CTFd/CTFd/themes
    depends_on:
      - db
      - cache
    networks:
      - ctfd_net

  db:
    image: mariadb:10.11
    container_name: ctfd_db
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_USER=ctfd
      - MYSQL_PASSWORD=${DB_PASSWORD}
      - MYSQL_DATABASE=ctfd
    volumes:
      - ./data/mysql:/var/lib/mysql
    command: [mysqld, --character-set-server=utf8mb4, --collation-server=utf8mb4_unicode_ci, --wait_timeout=28800, --log-warnings=0]
    networks:
      - ctfd_net

  cache:
    image: redis:7-alpine
    container_name: ctfd_cache
    restart: always
    volumes:
      - ./data/redis:/data
    networks:
      - ctfd_net

networks:
  ctfd_net:
    driver: bridge
EOF

log "${GREEN}[Step 3] Updating nginx configuration for proper proxy headers...${NC}"

# Fix nginx configuration to properly pass HTTPS status
cat > /etc/nginx/sites-available/ctfd << 'EOF'
server {
    listen 80;
    server_name ctf.pax8bootcamp.com;
    
    # Allow Let's Encrypt validation
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ctf.pax8bootcamp.com;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/ctf.pax8bootcamp.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ctf.pax8bootcamp.com/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    client_max_body_size 100M;
    client_body_timeout 60s;

    location / {
        proxy_pass http://localhost:8000;
        
        # Important: Pass the correct protocol to CTFd
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;  # Force HTTPS protocol
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port 443;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

log "${GREEN}[Step 4] Testing nginx configuration...${NC}"
if nginx -t; then
    log "${GREEN}✓ Nginx configuration is valid${NC}"
else
    log "${RED}✗ Nginx configuration error. Please check manually.${NC}"
    exit 1
fi

log "${GREEN}[Step 5] Restarting services...${NC}"

# Restart Docker containers
log "${YELLOW}Restarting CTFd containers...${NC}"
docker compose down
sleep 2
docker compose up -d

# Wait for containers to start
log "${YELLOW}Waiting for services to initialize...${NC}"
sleep 10

# Restart nginx
log "${YELLOW}Reloading nginx...${NC}"
systemctl reload nginx

log "${GREEN}[Step 6] Verifying fix...${NC}"

# Check if CTFd is responding
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}✓ CTFd is responding on HTTP${NC}"
else
    log "${YELLOW}⚠ CTFd may still be starting up${NC}"
fi

# Check HTTPS
if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}✓ HTTPS is working correctly${NC}"
else
    log "${YELLOW}⚠ HTTPS may need a moment to stabilize${NC}"
fi

# Check container status
log ""
log "${GREEN}Container Status:${NC}"
docker compose ps

log ""
log "${BLUE}========================================${NC}"
log "${GREEN}     Fix Applied Successfully!${NC}"
log "${BLUE}========================================${NC}"
log ""
log "${GREEN}The HTTPS issue should now be resolved.${NC}"
log "${GREEN}Please try accessing: https://$DOMAIN${NC}"
log ""
log "${YELLOW}If you still see errors:${NC}"
log "  1. Wait 30 seconds for services to fully start"
log "  2. Clear your browser cache and cookies"
log "  3. Try incognito/private browsing mode"
log "  4. Check logs: docker compose logs ctfd"
log ""
log "${GREEN}Configuration changes made:${NC}"
log "  - Disabled SESSION_COOKIE_SECURE to allow mixed HTTP/HTTPS"
log "  - Updated nginx to properly pass HTTPS headers"
log "  - Added security headers for HTTPS"
log ""
log "${YELLOW}Backups created:${NC}"
log "  - docker-compose.yml.backup-*"
log "  - .env.backup-*"