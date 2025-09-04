#!/bin/bash

#############################################
# CTFd Crash Loop Fix Script
# Diagnoses and fixes CTFd container crashes
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
log "${BLUE}     CTFd Crash Loop Diagnostic${NC}"
log "${BLUE}========================================${NC}"
log "${GREEN}Domain:${NC} $DOMAIN"
log "${GREEN}Install Directory:${NC} $INSTALL_DIR"
log "${BLUE}========================================${NC}"
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   log "${RED}This script must be run with sudo${NC}"
   log "${YELLOW}Usage: sudo ./fix-ctfd-crashloop.sh${NC}"
   exit 1
fi

# Navigate to CTFd directory
if [ ! -d "$INSTALL_DIR" ]; then
    log "${RED}CTFd installation not found at $INSTALL_DIR${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

log "${GREEN}[Step 1] Analyzing CTFd container logs...${NC}"
echo ""

# Get recent CTFd logs
log "${YELLOW}Recent CTFd container logs:${NC}"
docker compose logs --tail=50 ctfd

echo ""
log "${YELLOW}Database connection logs:${NC}"
docker compose logs --tail=20 db

echo ""
log "${GREEN}[Step 2] Checking configuration issues...${NC}"

# Check .env file
if [ -f ".env" ]; then
    log "${GREEN}✓ .env file exists${NC}"
    
    # Check for required variables
    if grep -q "SECRET_KEY=" .env && grep -q "DB_PASSWORD=" .env; then
        log "${GREEN}✓ Required environment variables present${NC}"
    else
        log "${RED}✗ Missing required environment variables${NC}"
        log "${YELLOW}Regenerating .env file...${NC}"
        
        # Backup old .env
        cp .env .env.backup-$(date +%Y%m%d-%H%M%S)
        
        # Generate new credentials
        SECRET_KEY=$(python3 -c "import os; print(os.urandom(64).hex())")
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        
        cat > .env << EOF
# CTFd Environment Variables
SECRET_KEY=$SECRET_KEY
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
DB_PASSWORD=$DB_PASSWORD
DOMAIN=$DOMAIN
EOF
        log "${GREEN}✓ New .env file created${NC}"
    fi
else
    log "${RED}✗ Missing .env file${NC}"
    log "${YELLOW}Creating .env file...${NC}"
    
    # Generate credentials
    SECRET_KEY=$(python3 -c "import os; print(os.urandom(64).hex())")
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    cat > .env << EOF
# CTFd Environment Variables
SECRET_KEY=$SECRET_KEY
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
DB_PASSWORD=$DB_PASSWORD
DOMAIN=$DOMAIN
EOF
    log "${GREEN}✓ .env file created${NC}"
fi

# Check docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    log "${GREEN}✓ docker-compose.yml exists${NC}"
else
    log "${RED}✗ Missing docker-compose.yml${NC}"
    log "${YELLOW}Creating docker-compose.yml...${NC}"
    
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
    log "${GREEN}✓ docker-compose.yml created${NC}"
fi

log ""
log "${GREEN}[Step 3] Checking data directories and permissions...${NC}"

# Ensure data directories exist with correct permissions
mkdir -p data/CTFd/logs data/CTFd/uploads data/CTFd/themes
mkdir -p data/mysql data/redis

# Fix ownership
chown -R $ACTUAL_USER:$ACTUAL_USER data/
chown -R 999:999 data/mysql  # MySQL container uses uid 999
chmod -R 755 data/

log "${GREEN}✓ Data directories and permissions fixed${NC}"

log ""
log "${GREEN}[Step 4] Database reset and fresh start...${NC}"

# Stop all containers
log "${YELLOW}Stopping all containers...${NC}"
docker compose down

# Check if database corruption might be the issue
if docker compose logs db 2>&1 | grep -i "corrupt\|error\|crash"; then
    log "${YELLOW}Database issues detected. Resetting database...${NC}"
    
    read -p "$(echo -e "${YELLOW}Reset database? This will delete all CTF data! [y/N]:${NC} ") " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf data/mysql/*
        log "${GREEN}✓ Database reset${NC}"
    fi
fi

# Pull latest images
log "${YELLOW}Pulling latest container images...${NC}"
docker compose pull

# Start database first and wait
log "${YELLOW}Starting database container...${NC}"
docker compose up -d db cache
sleep 10

# Check database is ready
log "${YELLOW}Waiting for database to be ready...${NC}"
for i in {1..30}; do
    if docker compose exec -T db mysql -u root -p${MYSQL_ROOT_PASSWORD:-$(grep MYSQL_ROOT_PASSWORD .env | cut -d'=' -f2)} -e "SELECT 1" >/dev/null 2>&1; then
        log "${GREEN}✓ Database is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Start CTFd container
log "${YELLOW}Starting CTFd container...${NC}"
docker compose up -d ctfd

# Wait and monitor startup
log "${YELLOW}Monitoring CTFd startup...${NC}"
for i in {1..60}; do
    container_status=$(docker compose ps ctfd --format "{{.Status}}")
    
    if echo "$container_status" | grep -q "Up"; then
        log "${GREEN}✓ CTFd container is running${NC}"
        break
    elif echo "$container_status" | grep -q "Restarting\|Exit"; then
        log "${RED}✗ CTFd container is still crashing${NC}"
        log "${YELLOW}Recent crash logs:${NC}"
        docker compose logs --tail=10 ctfd
        echo ""
    fi
    
    echo -n "."
    sleep 2
done
echo ""

log ""
log "${GREEN}[Step 5] Final health check...${NC}"

# Check all services
docker compose ps

# Test CTFd connectivity
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}✓ CTFd is responding on port 8000${NC}"
else
    log "${RED}✗ CTFd is still not responding${NC}"
    log "${YELLOW}Final logs from CTFd:${NC}"
    docker compose logs --tail=20 ctfd
fi

log ""
log "${BLUE}========================================${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}     Fix Successful!${NC}"
    log "${BLUE}========================================${NC}"
    log ""
    log "${GREEN}CTFd should now be accessible at:${NC}"
    log "  https://$DOMAIN"
    log ""
    log "${GREEN}Next steps:${NC}"
    log "  1. Visit the site to complete setup"
    log "  2. Create admin account"
    log "  3. Configure CTFd settings"
else
    log "${RED}     Fix Failed${NC}"
    log "${BLUE}========================================${NC}"
    log ""
    log "${RED}CTFd is still crashing. Manual investigation needed.${NC}"
    log ""
    log "${YELLOW}Debug commands:${NC}"
    log "  View logs: docker compose logs -f ctfd"
    log "  Check config: cat docker-compose.yml"
    log "  Check env: cat .env"
    log "  Database test: docker compose exec db mysql -u root -p"
    log ""
    log "${YELLOW}Common issues:${NC}"
    log "  1. Database connection problems"
    log "  2. Missing environment variables"
    log "  3. Permission issues"
    log "  4. Corrupted database"
fi