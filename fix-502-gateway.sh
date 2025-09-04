#!/bin/bash

#############################################
# CTFd 502 Bad Gateway Fix Script
# Diagnoses and fixes nginx gateway errors
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
log "${BLUE}     CTFd 502 Bad Gateway Fix${NC}"
log "${BLUE}========================================${NC}"
log "${GREEN}Domain:${NC} $DOMAIN"
log "${GREEN}Install Directory:${NC} $INSTALL_DIR"
log "${BLUE}========================================${NC}"
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   log "${RED}This script must be run with sudo${NC}"
   log "${YELLOW}Usage: sudo ./fix-502-gateway.sh${NC}"
   exit 1
fi

# Navigate to CTFd directory
if [ ! -d "$INSTALL_DIR" ]; then
    log "${RED}CTFd installation not found at $INSTALL_DIR${NC}"
    log "${YELLOW}CTFd may not be installed. Run the install script first.${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

log "${GREEN}[Step 1] Diagnosing the issue...${NC}"
echo ""

# Check Docker service
log "${YELLOW}Checking Docker service...${NC}"
if systemctl is-active --quiet docker; then
    log "${GREEN}✓ Docker service is running${NC}"
else
    log "${RED}✗ Docker service is not running${NC}"
    log "${YELLOW}Starting Docker...${NC}"
    systemctl start docker
    sleep 3
    if systemctl is-active --quiet docker; then
        log "${GREEN}✓ Docker started successfully${NC}"
    else
        log "${RED}✗ Failed to start Docker${NC}"
        log "${YELLOW}Attempting to fix Docker...${NC}"
        
        # Ensure docker group exists
        groupadd -f docker
        usermod -aG docker $ACTUAL_USER
        
        # Restart Docker components
        systemctl daemon-reload
        systemctl restart containerd
        sleep 2
        systemctl restart docker.socket
        sleep 1
        systemctl restart docker
        
        if ! systemctl is-active --quiet docker; then
            log "${RED}Docker cannot be started. Manual intervention required.${NC}"
            exit 1
        fi
    fi
fi

# Check Docker containers
log ""
log "${YELLOW}Checking CTFd containers...${NC}"
container_status=$(docker compose ps --format "table {{.Service}}\t{{.State}}" 2>/dev/null || echo "Failed")

if echo "$container_status" | grep -q "running"; then
    log "${GREEN}✓ Some containers are running${NC}"
    echo "$container_status"
else
    log "${RED}✗ No containers are running${NC}"
    log "${YELLOW}Containers need to be started${NC}"
fi

# Check if containers exist but are stopped
if docker ps -a | grep -q "ctfd"; then
    log "${YELLOW}Containers exist but may be stopped${NC}"
else
    log "${RED}Containers don't exist - need to create them${NC}"
fi

log ""
log "${GREEN}[Step 2] Fixing the issue...${NC}"

# Stop all containers first
log "${YELLOW}Stopping any existing containers...${NC}"
docker compose down 2>/dev/null || true
sleep 2

# Check for .env file
if [ ! -f ".env" ]; then
    log "${RED}✗ Missing .env file - creating with defaults${NC}"
    
    # Generate credentials
    SECRET_KEY=$(python3 -c "import os; print(os.urandom(64).hex())")
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    cat > .env << EOF
SECRET_KEY=$SECRET_KEY
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
DB_PASSWORD=$DB_PASSWORD
DOMAIN=$DOMAIN
EOF
    log "${GREEN}✓ Created .env file with new credentials${NC}"
fi

# Check for docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    log "${RED}✗ Missing docker-compose.yml - creating default${NC}"
    
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
    log "${GREEN}✓ Created docker-compose.yml${NC}"
fi

# Create required directories
log "${YELLOW}Ensuring data directories exist...${NC}"
mkdir -p data/CTFd/logs data/CTFd/uploads data/CTFd/themes
mkdir -p data/mysql data/redis
chown -R $ACTUAL_USER:$ACTUAL_USER data/

# Start containers
log "${YELLOW}Starting CTFd containers...${NC}"
docker compose pull
docker compose up -d

# Wait for containers to start
log "${YELLOW}Waiting for services to initialize (30 seconds)...${NC}"
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

# Check container status
log "${YELLOW}Checking container status...${NC}"
docker compose ps

# Test CTFd connectivity
log ""
log "${GREEN}[Step 3] Testing connectivity...${NC}"

if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}✓ CTFd is responding on port 8000${NC}"
else
    log "${RED}✗ CTFd is not responding on port 8000${NC}"
    log "${YELLOW}Checking container logs...${NC}"
    docker compose logs ctfd | tail -20
fi

# Fix nginx configuration
log ""
log "${GREEN}[Step 4] Fixing nginx configuration...${NC}"

# Check if nginx config exists
if [ ! -f "/etc/nginx/sites-available/ctfd" ]; then
    log "${YELLOW}Creating nginx configuration...${NC}"
    
    cat > /etc/nginx/sites-available/ctfd << 'EOF'
server {
    listen 80;
    server_name ctf.pax8bootcamp.com;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
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
    
    ln -sf /etc/nginx/sites-available/ctfd /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
fi

# Test nginx configuration
if nginx -t 2>/dev/null; then
    log "${GREEN}✓ Nginx configuration is valid${NC}"
    systemctl reload nginx
else
    log "${RED}✗ Nginx configuration has errors${NC}"
    nginx -t
fi

# Check if nginx is running
if systemctl is-active --quiet nginx; then
    log "${GREEN}✓ Nginx is running${NC}"
else
    log "${YELLOW}Starting nginx...${NC}"
    systemctl start nginx
fi

log ""
log "${GREEN}[Step 5] Final verification...${NC}"

# Test local connection
if curl -s -o /dev/null -w "Local CTFd: %{http_code}\n" http://localhost:8000 | grep -q "200\|302"; then
    log "${GREEN}✓ CTFd backend is accessible${NC}"
else
    log "${RED}✗ CTFd backend is not accessible${NC}"
fi

# Test through nginx
if curl -s -o /dev/null -w "Nginx proxy: %{http_code}\n" http://localhost | grep -q "200\|302\|301"; then
    log "${GREEN}✓ Nginx proxy is working${NC}"
else
    log "${RED}✗ Nginx proxy is not working${NC}"
fi

# Show running containers
log ""
log "${BLUE}Container Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

log ""
log "${BLUE}========================================${NC}"
log "${GREEN}     Fix Complete!${NC}"
log "${BLUE}========================================${NC}"
log ""
log "${GREEN}The 502 error should be resolved.${NC}"
log "${GREEN}Please try accessing: https://$DOMAIN${NC}"
log ""
log "${YELLOW}If you still see errors:${NC}"
log "  1. Check Docker logs: docker compose logs -f ctfd"
log "  2. Check nginx logs: tail -f /var/log/nginx/error.log"
log "  3. Verify firewall: sudo ufw status"
log "  4. Check Azure NSG allows ports 80 and 443"
log ""
log "${GREEN}Useful commands:${NC}"
log "  View logs: docker compose logs -f"
log "  Restart: docker compose restart"
log "  Status: docker compose ps"