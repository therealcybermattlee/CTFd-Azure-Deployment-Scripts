#!/bin/bash

#############################################
# CTFd Alembic Migration Fix Script
# Fixes database migration revision conflicts
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
log "${BLUE}     CTFd Alembic Migration Fix${NC}"
log "${BLUE}========================================${NC}"
log "${GREEN}Domain:${NC} $DOMAIN"
log "${GREEN}Install Directory:${NC} $INSTALL_DIR"
log "${BLUE}========================================${NC}"
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   log "${RED}This script must be run with sudo${NC}"
   log "${YELLOW}Usage: sudo ./fix-alembic-migration.sh${NC}"
   exit 1
fi

# Navigate to CTFd directory
if [ ! -d "$INSTALL_DIR" ]; then
    log "${RED}CTFd installation not found at $INSTALL_DIR${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

log "${GREEN}[Step 1] Diagnosing the Alembic migration issue...${NC}"
echo ""

log "${YELLOW}The error 'Can't locate revision identified by a49ad66aa0f1' means:${NC}"
log "  - Database has migration data from a different CTFd version"
log "  - Migration files are out of sync with database state"
log "  - This commonly happens after version changes or incomplete migrations"
echo ""

log "${GREEN}[Step 2] Backup current data...${NC}"

# Create backup directory
BACKUP_DIR="$HOME/ctfd-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Stop containers
log "${YELLOW}Stopping containers...${NC}"
docker compose down

# Backup data
log "${YELLOW}Creating backup...${NC}"
cp -r data/ "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"

log "${GREEN}✓ Backup created at: $BACKUP_DIR${NC}"

log ""
log "${GREEN}[Step 3] Clean database reset...${NC}"

log "${YELLOW}This will completely reset the database and start fresh.${NC}"
log "${RED}All CTF data will be lost, but the site will work.${NC}"
echo ""

read -p "$(echo -e "${YELLOW}Proceed with database reset? [y/N]:${NC} ") " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "${YELLOW}Operation cancelled. Backup preserved at: $BACKUP_DIR${NC}"
    exit 0
fi

# Remove database files completely
log "${YELLOW}Removing corrupted database files...${NC}"
rm -rf data/mysql/*

# Also clean redis cache to be safe
log "${YELLOW}Clearing Redis cache...${NC}"
rm -rf data/redis/*

# Ensure proper ownership
chown -R $ACTUAL_USER:$ACTUAL_USER data/

log "${GREEN}✓ Database files cleaned${NC}"

log ""
log "${GREEN}[Step 4] Starting with fresh database...${NC}"

# Start database and cache first
log "${YELLOW}Starting database and cache...${NC}"
docker compose up -d db cache

# Wait for database to initialize
log "${YELLOW}Waiting for fresh database to initialize (30 seconds)...${NC}"
for i in {1..30}; do
    if docker compose exec -T db mysql -u root -p${MYSQL_ROOT_PASSWORD:-$(grep MYSQL_ROOT_PASSWORD .env | cut -d'=' -f2)} -e "SELECT 1" >/dev/null 2>&1; then
        log "${GREEN}✓ Fresh database is ready${NC}"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

# Verify database is clean
log "${YELLOW}Verifying clean database state...${NC}"
DB_COUNT=$(docker compose exec -T db mysql -u root -p${MYSQL_ROOT_PASSWORD:-$(grep MYSQL_ROOT_PASSWORD .env | cut -d'=' -f2)} -e "USE ctfd; SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'ctfd';" 2>/dev/null | tail -1 || echo "0")

if [ "$DB_COUNT" -eq "0" ]; then
    log "${GREEN}✓ Database is clean and ready for fresh installation${NC}"
else
    log "${YELLOW}⚠ Database has $DB_COUNT existing tables${NC}"
fi

log ""
log "${GREEN}[Step 5] Starting CTFd with clean slate...${NC}"

# Start CTFd - it will create fresh database schema
log "${YELLOW}Starting CTFd (this will create fresh database)...${NC}"
docker compose up -d ctfd

# Monitor the startup process
log "${YELLOW}Monitoring CTFd startup and database creation...${NC}"
echo ""

# Follow logs in real time for a bit to see the migration process
timeout 30 docker compose logs -f ctfd &

# Wait for CTFd to be ready
for i in {1..60}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 5 | grep -q "200\|302"; then
        log ""
        log "${GREEN}✓ CTFd is responding successfully!${NC}"
        break
    fi
    
    container_status=$(docker compose ps ctfd --format "{{.Status}}")
    if echo "$container_status" | grep -q "Restarting\|Exited"; then
        log ""
        log "${RED}✗ CTFd is still having issues${NC}"
        log "${YELLOW}Recent logs:${NC}"
        docker compose logs --tail=10 ctfd
        break
    fi
    
    echo -n "."
    sleep 2
done
echo ""

log ""
log "${GREEN}[Step 6] Final verification...${NC}"

# Check container status
log "${YELLOW}Container status:${NC}"
docker compose ps

# Test connectivity
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}✓ CTFd is accessible on port 8000${NC}"
    
    # Test through nginx if configured
    if systemctl is-active --quiet nginx; then
        if curl -s -o /dev/null -w "%{http_code}" http://localhost --max-time 10 | grep -q "200\|302\|301"; then
            log "${GREEN}✓ Nginx proxy is working${NC}"
        fi
    fi
else
    log "${RED}✗ CTFd is still not responding${NC}"
fi

log ""
log "${BLUE}========================================${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}     Migration Fix Successful!${NC}"
    log "${BLUE}========================================${NC}"
    log ""
    log "${GREEN}CTFd is now running with a fresh database!${NC}"
    log ""
    log "${GREEN}Next steps:${NC}"
    log "  1. Visit: https://$DOMAIN/setup"
    log "  2. Create a new admin account"
    log "  3. Configure your CTF settings"
    log "  4. Import any backed up challenges/users if needed"
    log ""
    log "${YELLOW}Important notes:${NC}"
    log "  - All previous CTF data was reset"
    log "  - Admin accounts need to be recreated"
    log "  - Challenges and teams need to be reconfigured"
    log "  - Backup available at: $BACKUP_DIR"
else
    log "${RED}     Migration Fix Failed${NC}"
    log "${BLUE}========================================${NC}"
    log ""
    log "${RED}CTFd is still not working properly.${NC}"
    log ""
    log "${YELLOW}Manual investigation steps:${NC}"
    log "  1. Check logs: docker compose logs -f ctfd"
    log "  2. Check database: docker compose exec db mysql -u root -p"
    log "  3. Verify network: docker compose exec ctfd ping db"
    log "  4. Check disk space: df -h"
    log ""
    log "${GREEN}Your backup is safe at: $BACKUP_DIR${NC}"
fi

log ""
log "${YELLOW}Backup location: $BACKUP_DIR${NC}"
log "${YELLOW}Contains: data/, .env, docker-compose.yml${NC}"