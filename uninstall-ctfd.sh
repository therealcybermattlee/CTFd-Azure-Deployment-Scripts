#!/bin/bash

#############################################
# CTFd Uninstallation Script for Azure Ubuntu VM
# Complete removal with optional data preservation
#############################################

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/CTFd"
LOG_FILE="/tmp/ctfd-uninstall-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   log "${RED}========================================${NC}"
   log "${RED}This script must be run with sudo${NC}"
   log "${RED}========================================${NC}"
   log ""
   log "${YELLOW}Usage: sudo ./uninstall-ctfd.sh${NC}"
   exit 1
fi

# Get actual user
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd $ACTUAL_USER | cut -d: -f6)
INSTALL_DIR="$ACTUAL_HOME/CTFd"

# Header
clear
log "${RED}========================================${NC}"
log "${RED}     CTFd Uninstallation Script${NC}"
log "${RED}========================================${NC}"
log "${YELLOW}This will remove CTFd and related components${NC}"
log "${YELLOW}Installation directory: $INSTALL_DIR${NC}"
log "${RED}========================================${NC}"
echo ""

# Check if CTFd is installed
if [ ! -d "$INSTALL_DIR" ]; then
    log "${YELLOW}CTFd installation not found at $INSTALL_DIR${NC}"
    log "${GREEN}Nothing to uninstall${NC}"
    exit 0
fi

# Uninstall mode selection
log "${BLUE}Select uninstall mode:${NC}"
log "  1) Complete - Remove everything including data (NO RECOVERY)"
log "  2) Preserve Data - Keep data directories and backups"
log "  3) Docker Only - Remove containers but keep CTFd files"
log "  4) Cancel - Exit without making changes"
echo ""

while true; do
    read -p "$(echo -e "${YELLOW}Select option [1-4]:${NC} ") " uninstall_mode
    case $uninstall_mode in
        1|2|3)
            break
            ;;
        4)
            log "${GREEN}Uninstall cancelled${NC}"
            exit 0
            ;;
        *)
            log "${RED}Invalid option. Please select 1-4.${NC}"
            ;;
    esac
done

# Confirmation
if [ "$uninstall_mode" == "1" ]; then
    log ""
    log "${RED}⚠️  WARNING: COMPLETE UNINSTALL SELECTED ⚠️${NC}"
    log "${RED}This will permanently delete:${NC}"
    log "${RED}  - All CTFd data${NC}"
    log "${RED}  - All databases${NC}"
    log "${RED}  - All uploads${NC}"
    log "${RED}  - All backups${NC}"
    log "${RED}  - All configurations${NC}"
    log ""
    read -p "$(echo -e "${RED}Type 'DELETE ALL' to confirm:${NC} ") " confirm
    if [ "$confirm" != "DELETE ALL" ]; then
        log "${GREEN}Uninstall cancelled${NC}"
        exit 0
    fi
else
    log ""
    read -p "$(echo -e "${YELLOW}Are you sure you want to continue? [y/N]:${NC} ") " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "${GREEN}Uninstall cancelled${NC}"
        exit 0
    fi
fi

# Function to stop and remove Docker containers
remove_docker_containers() {
    log "${GREEN}[*] Stopping and removing Docker containers...${NC}"
    
    if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        cd "$INSTALL_DIR"
        
        # Stop containers
        if docker compose ps 2>/dev/null | grep -q "running\|Up"; then
            log "${YELLOW}Stopping CTFd containers...${NC}"
            docker compose stop 2>/dev/null || true
        fi
        
        # Remove containers and networks
        log "${YELLOW}Removing containers and networks...${NC}"
        docker compose down 2>/dev/null || true
        
        # Remove volumes if complete uninstall
        if [ "$uninstall_mode" == "1" ]; then
            log "${YELLOW}Removing Docker volumes...${NC}"
            docker compose down -v 2>/dev/null || true
        fi
        
        # Remove dangling images
        log "${YELLOW}Cleaning up Docker images...${NC}"
        docker image prune -f 2>/dev/null || true
        
        # Optionally remove CTFd images
        if [ "$uninstall_mode" == "1" ]; then
            docker rmi ctfd/ctfd:latest 2>/dev/null || true
            docker rmi mariadb:10.11 2>/dev/null || true
            docker rmi redis:7-alpine 2>/dev/null || true
        fi
    else
        log "${YELLOW}docker-compose.yml not found, skipping container removal${NC}"
    fi
    
    log "${GREEN}✓ Docker cleanup complete${NC}"
}

# Function to remove nginx configuration
remove_nginx_config() {
    log "${GREEN}[*] Removing nginx configuration...${NC}"
    
    # Remove CTFd site configuration
    if [ -f /etc/nginx/sites-available/ctfd ]; then
        rm -f /etc/nginx/sites-available/ctfd
        log "${GREEN}✓ Removed nginx site configuration${NC}"
    fi
    
    if [ -L /etc/nginx/sites-enabled/ctfd ]; then
        rm -f /etc/nginx/sites-enabled/ctfd
        log "${GREEN}✓ Removed nginx site symlink${NC}"
    fi
    
    # Restore default site if it was removed
    if [ ! -L /etc/nginx/sites-enabled/default ] && [ -f /etc/nginx/sites-available/default ]; then
        ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
        log "${GREEN}✓ Restored default nginx site${NC}"
    fi
    
    # Preserve SSL certificates to avoid Let's Encrypt rate limits
    DOMAIN=$(grep "DOMAIN=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d'=' -f2)
    if [ ! -z "$DOMAIN" ] && [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        log "${YELLOW}Found SSL certificates for $DOMAIN${NC}"
        if [ "$uninstall_mode" == "1" ]; then
            log "${YELLOW}⚠ SSL certificates will be PRESERVED to avoid Let's Encrypt rate limits${NC}"
            log "${YELLOW}  To manually remove: sudo certbot delete --cert-name $DOMAIN${NC}"
            log "${GREEN}✓ Keeping SSL certificates to prevent rate limiting${NC}"
        else
            log "${YELLOW}Keeping SSL certificates (mode: $uninstall_mode)${NC}"
        fi
    fi
    
    # Test and reload nginx
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log "${GREEN}✓ Nginx configuration updated${NC}"
    else
        log "${RED}⚠ Nginx configuration test failed. Manual intervention may be required.${NC}"
    fi
}

# Function to remove cron jobs
remove_cron_jobs() {
    log "${GREEN}[*] Removing cron jobs...${NC}"
    
    # Remove backup cron job
    crontab -u $ACTUAL_USER -l 2>/dev/null | grep -v "$INSTALL_DIR/backup-ctfd.sh" | crontab -u $ACTUAL_USER - 2>/dev/null || true
    
    # Remove SSL renewal if it mentions our domain
    if [ ! -z "$DOMAIN" ]; then
        crontab -l 2>/dev/null | grep -v "certbot renew" | crontab - 2>/dev/null || true
    fi
    
    log "${GREEN}✓ Cron jobs removed${NC}"
}

# Function to backup data before removal
backup_data() {
    if [ "$uninstall_mode" == "2" ]; then
        log "${GREEN}[*] Creating final backup...${NC}"
        
        BACKUP_DIR="$ACTUAL_HOME/ctfd-final-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        if [ -d "$INSTALL_DIR/data" ]; then
            log "${YELLOW}Backing up data directory...${NC}"
            cp -r "$INSTALL_DIR/data" "$BACKUP_DIR/"
        fi
        
        if [ -f "$INSTALL_DIR/.env" ]; then
            log "${YELLOW}Backing up environment configuration...${NC}"
            cp "$INSTALL_DIR/.env" "$BACKUP_DIR/"
        fi
        
        if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
            log "${YELLOW}Backing up docker-compose configuration...${NC}"
            cp "$INSTALL_DIR/docker-compose.yml" "$BACKUP_DIR/"
        fi
        
        # Keep existing backups
        if [ -d "$ACTUAL_HOME/ctfd-backups" ]; then
            log "${YELLOW}Preserving existing backups...${NC}"
        fi
        
        log "${GREEN}✓ Backup saved to: $BACKUP_DIR${NC}"
    fi
}

# Function to remove CTFd files
remove_ctfd_files() {
    log "${GREEN}[*] Removing CTFd files...${NC}"
    
    if [ "$uninstall_mode" == "1" ]; then
        # Complete removal
        log "${YELLOW}Removing everything in $INSTALL_DIR...${NC}"
        rm -rf "$INSTALL_DIR"
        
        # Remove backups
        if [ -d "$ACTUAL_HOME/ctfd-backups" ]; then
            log "${YELLOW}Removing all backups...${NC}"
            rm -rf "$ACTUAL_HOME/ctfd-backups"
        fi
        
        log "${GREEN}✓ All CTFd files removed${NC}"
        
    elif [ "$uninstall_mode" == "2" ]; then
        # Keep data but remove executables
        log "${YELLOW}Removing CTFd files but preserving data...${NC}"
        
        # Remove scripts
        rm -f "$INSTALL_DIR"/*.sh
        
        # Remove docker files
        rm -f "$INSTALL_DIR/docker-compose.yml"
        
        # Keep .env, data directory, and any backups
        log "${GREEN}✓ CTFd files removed (data preserved)${NC}"
        
    elif [ "$uninstall_mode" == "3" ]; then
        # Docker only - keep all files
        log "${YELLOW}Keeping all CTFd files (Docker-only removal)${NC}"
    fi
}

# Function to optionally remove Docker completely
remove_docker_optional() {
    if [ "$uninstall_mode" == "1" ]; then
        echo ""
        read -p "$(echo -e "${YELLOW}Remove Docker completely from the system? [y/N]:${NC} ") " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "${YELLOW}Removing Docker...${NC}"
            
            # Stop Docker services
            systemctl stop docker.socket docker.service containerd 2>/dev/null || true
            systemctl disable docker.socket docker.service containerd 2>/dev/null || true
            
            # Remove Docker packages
            apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
            apt-get autoremove -y
            
            # Remove Docker files
            rm -rf /var/lib/docker
            rm -rf /var/lib/containerd
            rm -rf /etc/docker
            rm -rf /etc/containerd
            
            # Remove Docker group
            groupdel docker 2>/dev/null || true
            
            log "${GREEN}✓ Docker removed completely${NC}"
        else
            log "${YELLOW}Docker kept on system${NC}"
        fi
    fi
}

# Main uninstall process
main() {
    log "${BLUE}Starting CTFd Uninstallation...${NC}"
    log "Uninstall mode: $uninstall_mode"
    echo ""
    
    # Step 1: Stop and remove Docker containers
    log "${GREEN}[Step 1/6] Docker cleanup...${NC}"
    remove_docker_containers
    
    # Step 2: Remove nginx configuration
    log "\n${GREEN}[Step 2/6] Nginx cleanup...${NC}"
    remove_nginx_config
    
    # Step 3: Remove cron jobs
    log "\n${GREEN}[Step 3/6] Cron job cleanup...${NC}"
    remove_cron_jobs
    
    # Step 4: Backup data if requested
    log "\n${GREEN}[Step 4/6] Data backup...${NC}"
    backup_data
    
    # Step 5: Remove CTFd files
    log "\n${GREEN}[Step 5/6] File cleanup...${NC}"
    remove_ctfd_files
    
    # Step 6: Optional Docker removal
    log "\n${GREEN}[Step 6/6] Optional Docker removal...${NC}"
    remove_docker_optional
    
    # Summary
    log "\n${BLUE}========================================${NC}"
    log "${GREEN}     Uninstallation Complete!${NC}"
    log "${BLUE}========================================${NC}"
    
    case $uninstall_mode in
        1)
            log "${GREEN}✓ CTFd completely removed${NC}"
            log "${GREEN}✓ All data deleted${NC}"
            ;;
        2)
            log "${GREEN}✓ CTFd removed${NC}"
            log "${GREEN}✓ Data preserved in: $BACKUP_DIR${NC}"
            ;;
        3)
            log "${GREEN}✓ Docker containers removed${NC}"
            log "${GREEN}✓ CTFd files preserved in: $INSTALL_DIR${NC}"
            ;;
    esac
    
    log ""
    log "${GREEN}Log file saved to: $LOG_FILE${NC}"
    
    # Final message
    if [ "$uninstall_mode" != "1" ]; then
        log ""
        log "${YELLOW}To reinstall CTFd, run:${NC}"
        log "${GREEN}  sudo ./ctfd-install-clean.sh${NC}"
    fi
}

# Run main uninstall
main "$@"