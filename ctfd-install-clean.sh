#!/bin/bash

#############################################
# CTFd Installation Script for Azure Ubuntu VM
# Clean, production-ready deployment
# Domain: ctf.pax8bootcamp.com
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
EMAIL="admin@pax8bootcamp.com"  # Change this for Let's Encrypt notifications
INSTALL_DIR="$HOME/CTFd"
LOG_FILE="/tmp/ctfd-install-$(date +%Y%m%d-%H%M%S).log"

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
   log "${YELLOW}Usage: sudo ./install-ctfd.sh${NC}"
   exit 1
fi

# Get actual user
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd $ACTUAL_USER | cut -d: -f6)
INSTALL_DIR="$ACTUAL_HOME/CTFd"

# Header
clear
log "${BLUE}========================================${NC}"
log "${BLUE}     CTFd Installation Script${NC}"
log "${BLUE}========================================${NC}"
log "${GREEN}Domain:${NC} $DOMAIN"
log "${GREEN}Install Directory:${NC} $INSTALL_DIR"
log "${GREEN}User:${NC} $ACTUAL_USER"
log "${GREEN}Log File:${NC} $LOG_FILE"
log "${BLUE}========================================${NC}"
echo ""

# Confirmation prompt
read -p "$(echo -e "${YELLOW}Do you want to proceed with installation? [y/N]:${NC} ") " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "${RED}Installation cancelled${NC}"
    exit 1
fi

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to check if valid SSL certificate exists
check_existing_certificate() {
    local domain="$1"
    local cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
    
    if [ ! -f "$cert_path" ]; then
        return 1  # No certificate exists
    fi
    
    # Check if certificate is still valid (not expired)
    if ! openssl x509 -checkend 86400 -noout -in "$cert_path" 2>/dev/null; then
        log "${YELLOW}Existing certificate is expired or expiring soon${NC}"
        return 1  # Certificate expired or expiring within 24 hours
    fi
    
    # Check if certificate matches domain
    local cert_domain=$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null | grep -oP 'CN=\K[^/]*' || echo "")
    if [ "$cert_domain" != "$domain" ]; then
        log "${YELLOW}Existing certificate is for different domain: $cert_domain${NC}"
        return 1  # Certificate doesn't match domain
    fi
    
    log "${GREEN}✓ Found valid existing SSL certificate for $domain${NC}"
    return 0  # Valid certificate exists
}

# Function to setup custom themes
setup_custom_themes() {
    log "${GREEN}[*] Theme Setup...${NC}"
    echo ""
    log "${YELLOW}Would you like to install custom themes from the community?${NC}"
    log "${BLUE}Available options:${NC}"
    log "  1) No themes (use default CTFd theme)"
    log "  2) Install popular community themes"
    log "  3) Install specific theme from GitHub URL"
    echo ""
    
    while true; do
        read -p "$(echo -e "${YELLOW}Select option [1-3]:${NC} ") " theme_choice
        case $theme_choice in
            1)
                log "${GREEN}Using default CTFd theme${NC}"
                return
                ;;
            2)
                log "${GREEN}Installing popular community themes...${NC}"
                install_popular_themes
                break
                ;;
            3)
                log "${GREEN}Installing custom theme from GitHub...${NC}"
                install_custom_theme_url
                break
                ;;
            *)
                log "${RED}Invalid option. Please select 1-3.${NC}"
                ;;
        esac
    done
}

# Function to install popular community themes
install_popular_themes() {
    log "${YELLOW}Installing community themes...${NC}"
    
    # Clone the official themes repository (with host key handling and debugging)
    # Add GitHub to known hosts to avoid interactive prompt for both root and actual user
    mkdir -p ~/.ssh
    mkdir -p "$ACTUAL_HOME/.ssh"
    ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    ssh-keyscan -H github.com >> "$ACTUAL_HOME/.ssh/known_hosts" 2>/dev/null || true
    chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.ssh" 2>/dev/null || true
    
    # Set git config to use HTTPS instead of SSH for github.com
    git config --global url."https://github.com/".insteadOf git@github.com: 2>/dev/null || true
    
    log "${YELLOW}Attempting to clone themes repository...${NC}"
    if git clone --recursive https://github.com/CTFd/themes.git temp_themes; then
        log "${GREEN}✓ Downloaded community themes repository${NC}"
        
        # Function to validate theme compatibility with modern CTFd
        validate_theme() {
            local theme_dir="$1"
            local theme_name="$2"
            
            log "${BLUE}Validating theme: $theme_name${NC}"
            
            # Core required templates for CTFd 3.6+
            local core_templates=(
                "base.html" "challenge.html" "challenges.html" "config.html" 
                "confirm.html" "login.html" "page.html" "register.html" 
                "reset_password.html" "scoreboard.html" "settings.html"
            )
            
            # Check core templates
            local missing_templates=0
            for template in "${core_templates[@]}"; do
                if ! find "$theme_dir/templates" -name "$template" -type f 2>/dev/null | grep -q .; then
                    log "${YELLOW}⚠ Missing core template: $template${NC}"
                    missing_templates=$((missing_templates + 1))
                fi
            done
            
            # Check for templates directory structure
            if [ ! -d "$theme_dir/templates" ]; then
                log "${RED}✗ Missing templates directory${NC}"
                return 1
            fi
            
            if [ ! -d "$theme_dir/static" ]; then
                log "${RED}✗ Missing static directory${NC}"
                return 1
            fi
            
            # Check for modern build system (indicators of compatibility)
            local has_modern_build=false
            if [ -f "$theme_dir/package.json" ] || [ -f "$theme_dir/vite.config.js" ]; then
                has_modern_build=true
                log "${GREEN}✓ Modern build system detected${NC}"
            fi
            
            # Strict validation for core templates
            if [ $missing_templates -gt 5 ]; then
                log "${RED}✗ Theme missing too many core templates ($missing_templates/11)${NC}"
                log "${RED}This theme is likely incompatible with CTFd 3.6+${NC}"
                return 1
            elif [ $missing_templates -gt 0 ] && [ "$has_modern_build" = false ]; then
                log "${RED}✗ Theme missing templates and has no modern build system${NC}"
                log "${RED}This theme is likely incompatible with CTFd 3.6+${NC}"
                return 1
            elif [ $missing_templates -gt 0 ]; then
                log "${YELLOW}⚠ Theme missing $missing_templates templates but has modern build system${NC}"
                log "${YELLOW}Theme may work but could have issues${NC}"
            fi
            
            # Check for base.html specifically (critical)
            if ! find "$theme_dir/templates" -name "base.html" -type f 2>/dev/null | grep -q .; then
                log "${RED}✗ Critical: Missing base.html template${NC}"
                return 1
            fi
            
            log "${GREEN}✓ Theme validation passed${NC}"
            return 0
        }
        
        # WARNING: Most community themes are incompatible with CTFd 3.6+
        log "${YELLOW}Checking for CTFd 3.6+ compatible themes...${NC}"
        log "${RED}Note: Most community themes are outdated and incompatible${NC}"
        themes_installed=0
        
        # Only attempt to install themes known to work with CTFd 3.6+
        # Most themes in the repository are for older CTFd versions
        COMPATIBLE_THEMES=(
            # Add only verified CTFd 3.6+ compatible themes here
            # Currently, most community themes are incompatible
        )
        
        # Fallback: Try to install core-beta compatible themes only
        LEGACY_THEME_MAPPINGS=(
            # Disabled due to compatibility issues with CTFd 3.6+
            # "ctfd-neon-theme:neon"     # Only works with CTFd 3.4.0
            # "pixo:pixo"               # Pre-Bootstrap 5 era
            # "CTFD-odin-theme:odin"    # Missing modern templates
            # "CTFD-crimson-theme:crimson" # Likely incompatible
        )
        
        # Try to install only verified compatible themes
        for mapping in "${COMPATIBLE_THEMES[@]}"; do
            IFS=':' read -r source_name target_name <<< "$mapping"
            if [ -d "temp_themes/$source_name" ]; then
                log "${BLUE}Testing theme: $source_name${NC}"
                if validate_theme "temp_themes/$source_name" "$target_name"; then
                    # Safe installation: copy to temporary location first
                    mkdir -p "temp_install_$target_name"
                    cp -r "temp_themes/$source_name"/* "temp_install_$target_name/"
                    
                    # Set proper permissions
                    chmod -R 755 "temp_install_$target_name"
                    
                    # Move to final location only if validation passed
                    mv "temp_install_$target_name" "data/CTFd/themes/$target_name"
                    log "${GREEN}✓ Successfully installed $target_name theme${NC}"
                    themes_installed=$((themes_installed + 1))
                else
                    log "${RED}✗ Theme $source_name failed compatibility validation${NC}"
                    rm -rf "temp_install_$target_name" 2>/dev/null || true
                fi
            else
                log "${YELLOW}Theme $source_name not found in repository${NC}"
            fi
        done
        
        if [ $themes_installed -eq 0 ]; then
            log "${YELLOW}⚠ No CTFd 3.6+ compatible themes found in repository${NC}"
            log "${GREEN}✓ CTFd will use the stable default core-beta theme${NC}"
            log "${BLUE}This is recommended for stability and security${NC}"
        else
            log "${GREEN}✓ Installed $themes_installed compatible themes${NC}"
            log "${YELLOW}Note: Only use themes in production after thorough testing${NC}"
        fi
        
        # Clean up
        rm -rf temp_themes
        
        log "${GREEN}✓ Popular themes installed${NC}"
        log "${YELLOW}You can change themes in CTFd Admin Panel > Configuration > Theme${NC}"
    else
        log "${RED}✗ Failed to download themes repository${NC}"
        log "${YELLOW}Note: Individual theme download disabled due to compatibility issues${NC}"
        log "${BLUE}Most community themes are incompatible with CTFd 3.6+${NC}"
        
        # Individual theme installation DISABLED for compatibility
        log "${YELLOW}Individual theme installation disabled${NC}"
        log "${RED}Reason: Known community themes are incompatible with CTFd 3.6+${NC}"
        log "${BLUE}CTFd will use the stable core-beta theme (recommended)${NC}"
        log "${YELLOW}For custom themes, use themes compatible with:${NC}"
        log "${YELLOW}  - Bootstrap 5${NC}"
        log "${YELLOW}  - Alpine.js${NC}"
        log "${YELLOW}  - Vite build system${NC}"
        log "${YELLOW}  - CTFd 3.6+ template structure${NC}"
        
        themes_installed=0
        log "${GREEN}✓ Theme installation completed (using default for stability)${NC}"
    fi
}

# Function to install custom theme from GitHub URL
install_custom_theme_url() {
    echo ""
    read -p "$(echo -e "${YELLOW}Enter GitHub repository URL (e.g., https://github.com/user/theme-repo):${NC} ") " theme_url
    
    if [[ -z "$theme_url" ]]; then
        log "${RED}No URL provided, skipping theme installation${NC}"
        return
    fi
    
    # Extract theme name from URL
    theme_name=$(basename "$theme_url" .git)
    
    log "${YELLOW}Installing theme: $theme_name...${NC}"
    
    # Configure git to use HTTPS and ensure host key is known
    git config --global url."https://github.com/".insteadOf git@github.com: 2>/dev/null || true
    mkdir -p ~/.ssh
    mkdir -p "$ACTUAL_HOME/.ssh"
    ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    ssh-keyscan -H github.com >> "$ACTUAL_HOME/.ssh/known_hosts" 2>/dev/null || true
    chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.ssh" 2>/dev/null || true
    
    if git clone "$theme_url" "data/CTFd/themes/$theme_name"; then
        log "${GREEN}✓ Successfully installed $theme_name theme${NC}"
        log "${YELLOW}You can activate it in CTFd Admin Panel > Configuration > Theme${NC}"
    else
        log "${RED}✗ Failed to clone theme repository${NC}"
        log "${YELLOW}Please check the URL and try again manually${NC}"
    fi
}

# Function to wait for apt locks
wait_for_apt() {
    local max_wait=300  # 5 minutes max
    local waited=0
    
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            log "${RED}Timeout waiting for apt locks${NC}"
            exit 1
        fi
        log "${YELLOW}Waiting for package manager locks...${NC}"
        sleep 5
        waited=$((waited + 5))
    done
}

# Function to fix Docker on Azure VMs
fix_docker_azure() {
    log "${YELLOW}Fixing Docker for Azure VM environment...${NC}"
    
    # Ensure docker group exists
    if ! getent group docker >/dev/null 2>&1; then
        log "${YELLOW}Creating docker group...${NC}"
        groupadd docker
    fi
    
    # Add user to docker group
    usermod -aG docker $ACTUAL_USER
    
    # Stop all Docker services
    systemctl stop docker.socket docker.service containerd 2>/dev/null || true
    
    # Clean up corrupted state
    rm -f /var/run/docker.sock /var/run/docker.pid
    rm -rf /var/lib/docker/network/files/* 2>/dev/null || true
    
    # Load required kernel modules
    modprobe overlay 2>/dev/null || true
    modprobe br_netfilter 2>/dev/null || true
    
    # Make kernel modules persistent
    cat > /etc/modules-load.d/docker.conf << EOF
overlay
br_netfilter
EOF
    
    # Configure sysctl settings
    cat > /etc/sysctl.d/99-docker.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
    sysctl --system > /dev/null 2>&1
    
    # Fix containerd config for Azure
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    # Enable systemd cgroup driver
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml 2>/dev/null || true
    
    # Configure Docker daemon - FIXED: removed invalid option
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
    
    # Fix socket permissions
    mkdir -p /etc/systemd/system/docker.socket.d
    cat > /etc/systemd/system/docker.socket.d/override.conf << 'EOF'
[Socket]
SocketMode=0660
SocketUser=root
SocketGroup=docker
EOF
    
    # Create systemd override for docker.service
    mkdir -p /etc/systemd/system/docker.service.d
    cat > /etc/systemd/system/docker.service.d/override.conf << 'EOF'
[Service]
ExecStartPre=
ExecStartPre=-/sbin/modprobe overlay
ExecStartPre=-/sbin/modprobe br_netfilter
EOF
    
    systemctl daemon-reload
}

# Function to install Docker
install_docker() {
    log "${GREEN}[*] Installing Docker...${NC}"
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    wait_for_apt
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Ensure docker group exists
    if ! getent group docker >/dev/null 2>&1; then
        log "${GREEN}Creating docker group...${NC}"
        groupadd docker
    fi
    
    # Add user to docker group
    usermod -aG docker $ACTUAL_USER
    
    # Apply Azure VM fixes
    fix_docker_azure
    
    # Start services in correct order
    systemctl start containerd
    sleep 2
    
    # Start docker socket first
    systemctl start docker.socket
    sleep 1
    
    # Then start docker service
    systemctl start docker
    
    # Verify Docker is working
    local max_attempts=5
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active --quiet docker && docker info >/dev/null 2>&1; then
            log "${GREEN}✓ Docker started successfully${NC}"
            break
        else
            log "${YELLOW}Docker not ready, attempt $attempt/$max_attempts...${NC}"
            if [ $attempt -eq $max_attempts ]; then
                log "${RED}Docker failed to start. Attempting recovery...${NC}"
                
                # Create docker group if missing
                groupadd -f docker
                usermod -aG docker $ACTUAL_USER
                
                # Reload and retry
                systemctl daemon-reload
                systemctl restart containerd
                sleep 2
                systemctl restart docker.socket
                sleep 1
                systemctl restart docker
                sleep 3
                
                if ! docker info >/dev/null 2>&1; then
                    log "${RED}Docker installation failed. Manual intervention required.${NC}"
                    log "${YELLOW}Try: sudo groupadd docker && sudo systemctl restart docker${NC}"
                    exit 1
                fi
            fi
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    # Enable services
    systemctl enable containerd
    systemctl enable docker.socket
    systemctl enable docker
    
    log "${GREEN}✓ Docker installed and configured for Azure${NC}"
}

# Function to fix and install nginx
fix_and_install_nginx() {
    log "${GREEN}[*] Fixing and installing nginx...${NC}"
    
    # Check if nginx is in a broken state
    if dpkg -l | grep -q "^iF.*nginx"; then
        log "${YELLOW}Nginx is in a broken state. Fixing...${NC}"
        
        # Create missing nginx.conf if needed
        if [ ! -f /etc/nginx/nginx.conf ]; then
            log "${YELLOW}Creating missing nginx.conf...${NC}"
            mkdir -p /etc/nginx
            cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    
    access_log /var/log/nginx/access.log;
    
    gzip on;
    
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
        fi
        
        # Create required directories
        mkdir -p /etc/nginx/sites-available
        mkdir -p /etc/nginx/sites-enabled
        mkdir -p /etc/nginx/conf.d
        mkdir -p /etc/nginx/modules-enabled
        mkdir -p /var/log/nginx
        
        # Create default site to prevent conflicts
        if [ ! -f /etc/nginx/sites-available/default ]; then
            cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
        fi
        
        # Fix dpkg state
        dpkg --configure -a 2>/dev/null || true
        apt-get install -f -y
    fi
    
    # Remove and reinstall nginx if still broken
    if ! nginx -t 2>/dev/null; then
        log "${YELLOW}Nginx configuration still broken. Reinstalling...${NC}"
        
        # Complete removal
        systemctl stop nginx 2>/dev/null || true
        apt-get remove --purge -y nginx nginx-common nginx-core 2>/dev/null || true
        rm -rf /etc/nginx
        rm -rf /var/log/nginx
        
        # Fresh install
        apt-get update
        apt-get install -y nginx
    fi
    
    # Ensure nginx is stopped before we configure it
    systemctl stop nginx 2>/dev/null || true
    
    log "${GREEN}✓ Nginx fixed and ready${NC}"
}

# Function to install dependencies
install_dependencies() {
    log "${GREEN}[*] Installing system dependencies...${NC}"
    
    wait_for_apt
    apt-get update
    
    # Install nginx first and fix if needed
    if ! command_exists nginx; then
        apt-get install -y nginx || fix_and_install_nginx
    else
        # Check if nginx is working
        if ! nginx -t 2>/dev/null; then
            fix_and_install_nginx
        fi
    fi
    
    # Install other dependencies
    apt-get install -y \
        certbot \
        python3-certbot-nginx \
        python3 \
        python3-pip \
        openssl \
        curl \
        git || {
        # If certbot-nginx fails due to nginx issues
        log "${YELLOW}Some packages failed. Attempting fix...${NC}"
        fix_and_install_nginx
        apt-get install -f -y
        apt-get install -y certbot python3-certbot-nginx
    }
    
    log "${GREEN}✓ Dependencies installed${NC}"
}

# Main installation
main() {
    log "${BLUE}Starting CTFd Installation...${NC}"
    
    # Step 1: Check and install Docker
    log "\n${GREEN}[Step 1/8] Checking Docker...${NC}"
    
    # First, ensure docker group exists no matter what
    if ! getent group docker >/dev/null 2>&1; then
        log "${YELLOW}Docker group missing. Creating...${NC}"
        groupadd docker
    fi
    
    # Add user to docker group
    usermod -aG docker $ACTUAL_USER 2>/dev/null || true
    
    if ! command_exists docker; then
        install_docker
    else
        log "${GREEN}✓ Docker already installed${NC}"
        
        # Check if Docker is in a broken state
        docker_working=false
        
        # Try to get Docker working
        if systemctl is-active --quiet docker && docker info >/dev/null 2>&1; then
            docker_working=true
            log "${GREEN}✓ Docker is running properly${NC}"
        else
            log "${YELLOW}Docker is installed but not working properly. Attempting repair...${NC}"
            
            # Stop everything first
            systemctl stop docker.socket docker.service containerd 2>/dev/null || true
            
            # Ensure docker group exists (critical for socket)
            if ! getent group docker >/dev/null 2>&1; then
                log "${RED}Docker group was missing! Creating...${NC}"
                groupadd docker
                systemctl daemon-reload
            fi
            
            # Apply all fixes
            fix_docker_azure
            
            # Try to start Docker properly
            log "${YELLOW}Starting Docker services...${NC}"
            systemctl daemon-reload
            
            # Start in correct order with error checking
            if ! systemctl start containerd; then
                log "${RED}Containerd failed to start${NC}"
                journalctl -u containerd --no-pager | tail -10
            else
                sleep 2
                
                if ! systemctl start docker.socket; then
                    log "${RED}Docker socket failed to start${NC}"
                    journalctl -u docker.socket --no-pager | tail -10
                    
                    # Try to fix socket issues
                    log "${YELLOW}Attempting socket fix...${NC}"
                    rm -f /var/run/docker.sock
                    systemctl daemon-reload
                    systemctl start docker.socket
                fi
                
                sleep 1
                
                if ! systemctl start docker.service; then
                    log "${RED}Docker service failed to start${NC}"
                    journalctl -u docker.service --no-pager | tail -10
                fi
            fi
            
            # Check if it's working now
            if docker info >/dev/null 2>&1; then
                docker_working=true
                log "${GREEN}✓ Docker repaired successfully${NC}"
            fi
        fi
        
        # If still not working, try complete reinstall
        if [ "$docker_working" = false ]; then
            log "${RED}Docker repair failed. Performing complete reinstall...${NC}"
            
            # Complete removal
            log "${YELLOW}Removing broken Docker installation...${NC}"
            systemctl stop docker.socket docker.service containerd 2>/dev/null || true
            apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
            apt-get autoremove -y
            
            # Clean up all Docker files
            rm -rf /var/lib/docker
            rm -rf /var/lib/containerd  
            rm -rf /etc/docker
            rm -rf /etc/containerd
            rm -f /var/run/docker.sock
            rm -rf /etc/systemd/system/docker.service.d
            rm -rf /etc/systemd/system/docker.socket.d
            
            # Remove and recreate docker group
            groupdel docker 2>/dev/null || true
            groupadd docker
            
            systemctl daemon-reload
            
            # Fresh install
            log "${GREEN}Installing Docker fresh...${NC}"
            install_docker
            
            # Verify it works
            if ! docker info >/dev/null 2>&1; then
                log "${RED}Docker installation failed completely.${NC}"
                log "${RED}Manual intervention required. Please check:${NC}"
                log "${YELLOW}  1. journalctl -xeu docker.service${NC}"
                log "${YELLOW}  2. journalctl -xeu docker.socket${NC}"
                log "${YELLOW}  3. systemctl status docker${NC}"
                exit 1
            fi
        fi
    fi
    
    # Step 2: Install dependencies
    log "\n${GREEN}[Step 2/8] Installing dependencies...${NC}"
    install_dependencies
    
    # Step 3: Create installation directory
    log "\n${GREEN}[Step 3/8] Setting up directory structure...${NC}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Create data directories
    mkdir -p data/CTFd/logs
    mkdir -p data/CTFd/uploads
    mkdir -p data/CTFd/themes
    mkdir -p data/mysql
    mkdir -p data/redis
    chmod -R 755 data/
    
    # Step 4: Generate credentials
    log "\n${GREEN}[Step 4/8] Generating secure credentials...${NC}"
    SECRET_KEY=$(python3 -c "import os; print(os.urandom(64).hex())")
    MYSQL_ROOT_PASSWORD=$(generate_password)
    DB_PASSWORD=$(generate_password)
    
    # Create .env file
    cat > .env << EOF
# CTFd Environment Variables
# Generated on $(date)
SECRET_KEY=$SECRET_KEY
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
DB_PASSWORD=$DB_PASSWORD
DOMAIN=$DOMAIN
EOF
    
    log "${GREEN}✓ Credentials generated${NC}"
    
    # Step 4.5: Setup custom themes (optional - DISABLED BY DEFAULT)
    echo ""
    log "${YELLOW}Theme Installation:${NC}"
    log "${YELLOW}Skipping theme installation to prevent template errors${NC}"
    log "${GREEN}Using default CTFd theme for stability${NC}"
    log "${BLUE}You can install themes later using: $INSTALL_DIR/manage-themes.sh${NC}"
    
    # Ensure themes directory exists even when empty
    touch data/CTFd/themes/.gitkeep
    
    # Uncomment the following to enable theme installation (not recommended during initial setup)
    # read -p "$(echo -e "${YELLOW}Install community themes? [y/N]:${NC} ") " -n 1 -r
    # echo
    # if [[ $REPLY =~ ^[Yy]$ ]]; then
    #     setup_custom_themes
    # fi
    
    # Step 5: Create docker-compose.yml
    log "\n${GREEN}[Step 5/8] Creating Docker configuration...${NC}"
    cat > docker-compose.yml << 'EOF'
services:
  ctfd:
    image: ctfd/ctfd:3.6.0  # Pinned version for theme compatibility
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
      - SESSION_COOKIE_SECURE=True
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
    
    # Step 6: Start Docker containers
    log "\n${GREEN}[Step 6/8] Starting Docker containers...${NC}"
    docker compose pull
    
    # Start database and cache first to avoid migration conflicts
    log "${YELLOW}Starting database and cache services...${NC}"
    docker compose up -d db cache
    
    # Wait for database to be ready
    log "${YELLOW}Waiting for database to initialize...${NC}"
    for i in {1..30}; do
        if docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
            log "${GREEN}✓ Database is ready${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    # Now start CTFd with database ready
    log "${YELLOW}Starting CTFd application...${NC}"
    docker compose up -d ctfd
    
    # Wait for CTFd initialization
    log "${YELLOW}Waiting for CTFd to initialize...${NC}"
    for i in {1..30}; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 5 | grep -q "200\|302"; then
            log "${GREEN}✓ CTFd is ready${NC}"
            break
        fi
        
        # Check if CTFd is crashing
        container_status=$(docker compose ps ctfd --format "{{.Status}}" 2>/dev/null || echo "unknown")
        if echo "$container_status" | grep -q "Restarting\|Exited"; then
            log "${RED}✗ CTFd container is crashing${NC}"
            log "${YELLOW}Checking logs for migration issues...${NC}"
            if docker compose logs ctfd 2>&1 | grep -q "Can't locate revision"; then
                log "${RED}✗ Database migration conflict detected${NC}"
                log "${YELLOW}This can happen with existing database data${NC}"
                log "${YELLOW}Run ./fix-alembic-migration.sh to resolve${NC}"
                break
            fi
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    # Check final status
    if docker compose ps | grep -q "running"; then
        log "${GREEN}✓ Containers started successfully${NC}"
    else
        log "${RED}✗ Container startup failed. Check logs: docker compose logs${NC}"
    fi
    
    # Step 7: Configure nginx
    log "\n${GREEN}[Step 7/8] Configuring nginx...${NC}"
    cat > /etc/nginx/sites-available/ctfd << EOF
server {
    listen 80;
    server_name $DOMAIN;

    client_max_body_size 100M;
    client_body_timeout 60s;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/ctfd /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Fix nginx permissions and test configuration
    mkdir -p /run/nginx /var/log/nginx
    touch /run/nginx.pid
    chown -R www-data:www-data /run/nginx /var/log/nginx
    chmod 755 /run/nginx
    chmod 644 /run/nginx.pid
    
    if nginx -t; then
        systemctl reload nginx
        log "${GREEN}✓ Nginx configured${NC}"
    else
        log "${YELLOW}⚠ Nginx configuration test failed. Attempting to start anyway...${NC}"
        systemctl restart nginx
        if systemctl is-active nginx >/dev/null; then
            log "${GREEN}✓ Nginx started${NC}"
        else
            log "${RED}✗ Nginx failed to start. Check: sudo systemctl status nginx${NC}"
        fi
    fi
    
    # Step 8: SSL Certificate Setup
    log "\n${GREEN}[Step 8/8] SSL Certificate Setup...${NC}"
    
    # Check for existing valid certificate first
    if check_existing_certificate "$DOMAIN"; then
        log "${GREEN}Using existing SSL certificate for $DOMAIN${NC}"
        log "${YELLOW}Configuring nginx to use existing certificate...${NC}"
        
        # Configure nginx with existing SSL certificate
        cat > /etc/nginx/sites-available/ctfd << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
        
        # Test and reload nginx
        if nginx -t; then
            systemctl reload nginx
            log "${GREEN}✓ SSL configuration applied with existing certificate${NC}"
            log "${GREEN}✓ Avoided Let's Encrypt rate limit by reusing certificate${NC}"
        else
            log "${RED}✗ Nginx SSL configuration error${NC}"
            nginx -t
        fi
        
        # Ensure auto-renewal is configured
        if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
            (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet && systemctl reload nginx") | crontab -
            log "${GREEN}✓ Auto-renewal configured${NC}"
        fi
    else
        # No existing certificate, proceed with new certificate request
        log "${YELLOW}No valid existing certificate found. Requesting new certificate...${NC}"
        
        PUBLIC_IP=$(curl -s ifconfig.me)
        DNS_IP=$(dig +short $DOMAIN | tail -n1)
    
    # Check if Cloudflare is being used
    USING_CLOUDFLARE=false
    if curl -s "https://api.cloudflare.com/client/v4/ips" | grep -q "$DNS_IP" 2>/dev/null; then
        USING_CLOUDFLARE=true
        log "${BLUE}Cloudflare proxy detected for $DOMAIN${NC}"
    elif [ "$DNS_IP" != "$PUBLIC_IP" ]; then
        log "${YELLOW}Domain points to $DNS_IP (not server IP $PUBLIC_IP)${NC}"
        log "${YELLOW}This may be a CDN/proxy service${NC}"
    fi
    
    # Always attempt SSL certificate setup
    log "${GREEN}Setting up SSL certificate...${NC}"
    
    # Check if certbot is installed
    if ! command_exists certbot; then
        log "${YELLOW}Installing certbot...${NC}"
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    # For Cloudflare or other proxies, we need different approach
    if [ "$USING_CLOUDFLARE" = true ] || [ "$DNS_IP" != "$PUBLIC_IP" ]; then
        log "${YELLOW}Proxy/CDN detected - Using HTTP validation with temporary bypass...${NC}"
        
        # Create webroot directory for validation
        mkdir -p /var/www/certbot
        
        # Configure nginx for HTTP validation (no redirect during validation)
        cat > /etc/nginx/sites-available/ctfd << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Let's Encrypt validation
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Regular traffic
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
        
        # Reload nginx configuration
        if nginx -t; then
            systemctl reload nginx
            log "${GREEN}✓ Nginx configured for SSL validation${NC}"
        else
            log "${RED}✗ Nginx configuration error${NC}"
            nginx -t
            return 1
        fi
        
        log "${YELLOW}Cloudflare detected - attempting automatic SSL setup...${NC}"
        log "${YELLOW}Note: You may need to set Cloudflare SSL mode to 'Full (strict)' after this completes${NC}"
        
        # Try to get SSL certificate with webroot method
        log "${YELLOW}Requesting SSL certificate...${NC}"
        if certbot certonly --webroot -w /var/www/certbot -d $DOMAIN --non-interactive --agree-tos --email $EMAIL; then
                log "${GREEN}✓ SSL certificate obtained${NC}"
                
                # Configure nginx with SSL
                cat > /etc/nginx/sites-available/ctfd << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
                
                # Test and reload nginx
                if nginx -t; then
                    systemctl reload nginx
                    log "${GREEN}✓ SSL configuration applied${NC}"
                    
                    # Test SSL setup
                    log "${YELLOW}Testing SSL setup...${NC}"
                    if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" --max-time 10 | grep -q "200\|30"; then
                        log "${GREEN}✓ SSL setup successful!${NC}"
                        log "${YELLOW}You can now re-enable Cloudflare proxy (orange cloud) and set SSL mode to 'Full (strict)'${NC}"
                    else
                        log "${YELLOW}⚠ SSL test inconclusive - please verify manually${NC}"
                    fi
                else
                    log "${RED}✗ Nginx SSL configuration error${NC}"
                    nginx -t
                fi
                
                # Setup auto-renewal
                (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet && systemctl reload nginx") | crontab -
                log "${GREEN}✓ Auto-renewal configured${NC}"
            else
                log "${RED}✗ SSL certificate request failed${NC}"
                log "${RED}HTTPS is required for CTF platform security${NC}"
                log "${RED}Please fix SSL configuration before proceeding${NC}"
                log ""
                log "${YELLOW}To fix SSL:${NC}"
                log "${YELLOW}  1. Disable Cloudflare proxy temporarily (gray cloud)${NC}"
                log "${YELLOW}  2. Run: sudo certbot --nginx -d $DOMAIN${NC}"
                log "${YELLOW}  3. Re-enable Cloudflare proxy and set SSL mode to 'Full (strict)'${NC}"
                log ""
                log "${RED}Deployment stopped - SSL is mandatory${NC}"
                exit 1
            fi
    else
        log "${GREEN}Direct DNS configuration detected${NC}"
        
        # Direct DNS - standard SSL setup
        log "${YELLOW}Requesting SSL certificate from Let's Encrypt...${NC}"
        if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect; then
            log "${GREEN}✓ SSL certificate installed and configured${NC}"
            # Setup auto-renewal
            (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet && systemctl reload nginx") | crontab -
            log "${GREEN}✓ Auto-renewal configured${NC}"
        else
            log "${YELLOW}Automatic SSL setup failed. Trying with webroot method...${NC}"
            
            # Create webroot directory
            mkdir -p /var/www/certbot
            
            # Try webroot method for direct DNS
            log "${YELLOW}Trying webroot method for SSL certificate...${NC}"
            if certbot certonly --webroot -w /var/www/certbot -d $DOMAIN --non-interactive --agree-tos --email $EMAIL; then
                log "${GREEN}✓ SSL certificate obtained${NC}"
                
                # Configure nginx with SSL
                cat > /etc/nginx/sites-available/ctfd << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
                
                if nginx -t; then
                    systemctl reload nginx
                    log "${GREEN}✓ SSL certificate installed and configured${NC}"
                    # Setup auto-renewal
                    (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet && systemctl reload nginx") | crontab -
                    log "${GREEN}✓ Auto-renewal configured${NC}"
                else
                    log "${RED}✗ Nginx SSL configuration error${NC}"
                    nginx -t
                fi
            else
                log "${RED}SSL setup failed. HTTPS is mandatory for CTF security.${NC}"
                log "${YELLOW}To fix SSL:${NC}"
                log "${YELLOW}  1. Run: sudo certbot --nginx -d $DOMAIN${NC}"
                log "${YELLOW}  2. Ensure DNS points directly to this server${NC}"
                log ""
                log "${RED}Deployment stopped - SSL is required${NC}"
                exit 1
            fi
        fi
    fi
    fi  # End of certificate check conditional
    
    # Final connectivity verification
    log "\n${GREEN}Verifying deployment...${NC}"
    sleep 3
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8000" --max-time 10 | grep -q "200\|30"; then
        log "${GREEN}✓ CTFd is responding on HTTP${NC}"
    else
        log "${YELLOW}⚠ CTFd may still be starting up${NC}"
    fi
    
    # Check SSL if configured
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" --max-time 10 | grep -q "200\|30"; then
            log "${GREEN}✓ SSL is working${NC}"
        else
            log "${YELLOW}⚠ SSL may need Cloudflare configuration${NC}"
        fi
    fi
    
    # Create management scripts
    log "\n${GREEN}Creating management scripts...${NC}"
    
    # Start script
    cat > "$INSTALL_DIR/start-ctfd.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose up -d
docker compose ps
EOF
    
    # Stop script
    cat > "$INSTALL_DIR/stop-ctfd.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose stop
EOF
    
    # Restart script
    cat > "$INSTALL_DIR/restart-ctfd.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose restart
docker compose ps
EOF
    
    # Logs script
    cat > "$INSTALL_DIR/logs-ctfd.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose logs -f
EOF
    
    # Backup script
    cat > "$INSTALL_DIR/backup-ctfd.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
BACKUP_DIR="$HOME/ctfd-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
docker compose stop
tar -czf "$BACKUP_DIR/ctfd-backup-$TIMESTAMP.tar.gz" data/ .env docker-compose.yml
docker compose start
echo "Backup saved to: $BACKUP_DIR/ctfd-backup-$TIMESTAMP.tar.gz"
ls -lh "$BACKUP_DIR/ctfd-backup-$TIMESTAMP.tar.gz"
EOF
    
    # Theme management script
    cat > "$INSTALL_DIR/manage-themes.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "=== CTFd Theme Manager ==="
echo ""
echo "⚠️  COMPATIBILITY WARNING ⚠️"
echo "Most community themes are incompatible with CTFd 3.6+"
echo "Only install themes that support:"
echo "  - Bootstrap 5"
echo "  - Alpine.js"
echo "  - Vite build system"
echo "  - CTFd 3.6+ template structure"
echo ""
echo "Current themes installed:"
if [ -d "data/CTFd/themes" ] && [ "$(ls -A data/CTFd/themes)" ]; then
    ls -la data/CTFd/themes/ | grep "^d" | awk '{print "  - " $9}' | grep -v "^\s*- \.$" | grep -v "^\s*- \.\.$"
else
    echo "  Using default core-beta theme (RECOMMENDED)"
fi

echo ""
echo "Theme management options:"
echo "1) Install theme from GitHub URL (advanced users only)"
echo "2) Remove a theme"
echo "3) Test current theme compatibility"
echo "4) Exit"
echo ""

read -p "Select option [1-4]: " choice

case $choice in
    1)
        read -p "Enter GitHub repository URL:" theme_url
        if [[ -n "$theme_url" ]]; then
            echo "⚠ WARNING: Most community themes are incompatible with CTFd 3.6+"
            echo "Proceeding with advanced installation..."
            # Configure git and ensure GitHub host key is known
            git config --global url."https://github.com/".insteadOf git@github.com: 2>/dev/null || true
            mkdir -p ~/.ssh
            ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null || true
            # Validate theme function (same as install script)
            # Modern CTFd 3.6+ theme validation
            validate_theme_mgr() {
                local theme_dir="$1"
                local theme_name="$2"
                
                echo "Validating theme: $theme_name for CTFd 3.6+ compatibility"
                
                # Core required templates for CTFd 3.6+
                local core_templates=(
                    "base.html" "challenge.html" "challenges.html" "config.html" 
                    "confirm.html" "login.html" "page.html" "register.html" 
                    "reset_password.html" "scoreboard.html" "settings.html"
                )
                
                # Check directory structure
                if [ ! -d "$theme_dir/templates" ]; then
                    echo "✗ Missing templates directory"
                    return 1
                fi
                
                if [ ! -d "$theme_dir/static" ]; then
                    echo "✗ Missing static directory"
                    return 1
                fi
                
                # Check core templates
                local missing_templates=0
                for template in "${core_templates[@]}"; do
                    if ! find "$theme_dir/templates" -name "$template" -type f 2>/dev/null | grep -q .; then
                        echo "⚠ Missing: $template"
                        missing_templates=$((missing_templates + 1))
                    fi
                done
                
                # Check for modern build system
                local has_modern_build=false
                if [ -f "$theme_dir/package.json" ] || [ -f "$theme_dir/vite.config.js" ]; then
                    has_modern_build=true
                    echo "✓ Modern build system detected"
                fi
                
                # Validation logic
                if [ $missing_templates -gt 5 ]; then
                    echo "✗ Too many missing templates ($missing_templates/11) - likely incompatible"
                    return 1
                elif [ $missing_templates -gt 0 ] && [ "$has_modern_build" = false ]; then
                    echo "✗ Missing templates and no modern build system - incompatible"
                    return 1
                fi
                
                echo "✓ Theme validation passed"
                return 0
            }
            
            echo "Installing verified compatible themes..."
            themes_installed=0
            
            theme_name=$(basename "$theme_url" .git)
            echo "Installing theme: $theme_name"
            if git clone "$theme_url" "temp_$theme_name"; then
                if validate_theme_mgr "temp_$theme_name" "$theme_name"; then
                    cp -r "temp_$theme_name" "data/CTFd/themes/$theme_name"
                    rm -rf "temp_$theme_name"
                    echo "✓ Successfully installed $theme_name theme"
                    echo "⚠ IMPORTANT: Test theme thoroughly before using in production"
                    echo "Restart CTFd to see new theme: docker compose restart"
                else
                    echo "✗ Theme $theme_name failed compatibility validation"
                    echo "This theme is likely incompatible with CTFd 3.6+"
                    rm -rf "temp_$theme_name"
                fi
            else
                echo "Failed to clone theme repository"
            fi
        else
            echo "No URL provided"
        fi
        ;;
    2)
        echo "Available themes to remove:"
        if [ -d "data/CTFd/themes" ]; then
            ls -1 data/CTFd/themes/
            read -p "Enter theme name to remove: " theme_name
            if [[ -n "$theme_name" ]] && [[ -d "data/CTFd/themes/$theme_name" ]]; then
                rm -rf "data/CTFd/themes/$theme_name"
                echo "✓ Removed $theme_name theme"
                echo "Restart CTFd: docker compose restart"
            else
                echo "Theme not found"
            fi
        else
            echo "No themes directory found"
        fi
        ;;
    3)
        echo "Testing current theme compatibility..."
        if [ -d "data/CTFd/themes" ]; then
            for theme_dir in data/CTFd/themes/*/; do
                if [ -d "$theme_dir" ]; then
                    theme_name=$(basename "$theme_dir")
                    echo ""
                    validate_theme_mgr "$theme_dir" "$theme_name"
                fi
            done
        else
            echo "No custom themes found"
            echo "Using default core-beta theme (fully compatible)"
        fi
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option"
        ;;
esac
EOF

    # Network diagnostics script
    cat > "$INSTALL_DIR/diagnose-network.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "=== CTFd Network Diagnostics ==="
echo ""

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to get public IP")
echo "Public IP: $PUBLIC_IP"

# Check if running on Azure
if curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" >/dev/null 2>&1; then
    echo "Running on: Azure VM"
else
    echo "Running on: Other cloud/local"
fi

echo ""
echo "=== Port Status ==="

# Check if ports are listening
echo "Local port bindings:"
ss -tlnp | grep -E "(80|443|8000)" || echo "No web ports listening"

echo ""
echo "=== Service Status ==="

# Check Docker containers
echo "CTFd containers:"
if docker compose ps 2>/dev/null | tail -n +2; then
    echo "✓ Docker containers running"
else
    echo "✗ Docker containers not running"
fi

# Check nginx
echo ""
echo "Nginx status:"
if systemctl is-active nginx >/dev/null 2>&1; then
    echo "✓ Nginx is running"
    if nginx -t >/dev/null 2>&1; then
        echo "✓ Nginx configuration is valid"
    else
        echo "✗ Nginx configuration has errors"
        nginx -t
    fi
else
    echo "✗ Nginx is not running"
fi

echo ""
echo "=== Firewall Status ==="

# Check ufw
if command -v ufw >/dev/null 2>&1; then
    echo "Ubuntu Firewall (ufw):"
    sudo ufw status
else
    echo "ufw not installed"
fi

# Check iptables
echo ""
echo "iptables rules (Docker may add rules):"
sudo iptables -L INPUT -n | head -10

echo ""
echo "=== Connectivity Tests ==="

# Test local connections
echo "Testing local connections:"
if curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:8000; then
    echo " - http://localhost:8000"
fi

if curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost; then
    echo " - http://localhost (nginx)"
fi

echo ""
echo "Testing external access (from VM):"
if [[ "$PUBLIC_IP" != "Unable to get public IP" ]]; then
    if curl -s -o /dev/null -w "HTTP %{http_code}" "http://$PUBLIC_IP" --max-time 5; then
        echo " - http://$PUBLIC_IP"
    else
        echo " - http://$PUBLIC_IP (failed - likely NSG/firewall issue)"
    fi
    
    if curl -s -o /dev/null -w "HTTP %{http_code}" "http://$PUBLIC_IP:8000" --max-time 5; then
        echo " - http://$PUBLIC_IP:8000"
    else
        echo " - http://$PUBLIC_IP:8000 (failed - port 8000 blocked)"
    fi
fi

echo ""
echo "=== Cloudflare Diagnostics ==="

# Check for domain configuration
if [ -f ".env" ]; then
    DOMAIN=$(grep "DOMAIN=" .env 2>/dev/null | cut -d'=' -f2)
    if [[ -n "$DOMAIN" ]]; then
        echo "Configured domain: $DOMAIN"
        
        # Check DNS resolution
        echo "DNS resolution test:"
        RESOLVED_IP=$(dig +short "$DOMAIN" 2>/dev/null | tail -1)
        if [[ -n "$RESOLVED_IP" ]]; then
            echo "  $DOMAIN resolves to: $RESOLVED_IP"
            if [[ "$RESOLVED_IP" != "$PUBLIC_IP" ]]; then
                # Check if it's a Cloudflare IP
                if curl -s "https://api.cloudflare.com/client/v4/ips" | grep -q "$RESOLVED_IP" 2>/dev/null; then
                    echo "  ✓ Cloudflare proxy detected"
                else
                    echo "  ⚠ Domain points to different IP (not Cloudflare or direct)"
                fi
            else
                echo "  ✓ Direct DNS (not proxied)"
            fi
        else
            echo "  ✗ DNS resolution failed"
        fi
        
        # Test domain connectivity
        echo ""
        echo "Domain connectivity test:"
        if curl -s -o /dev/null -w "HTTP %{http_code}" "http://$DOMAIN" --max-time 10; then
            echo " - http://$DOMAIN"
        else
            echo " - http://$DOMAIN (failed)"
        fi
        
        if curl -s -o /dev/null -w "HTTP %{http_code}" "https://$DOMAIN" --max-time 10; then
            echo " - https://$DOMAIN"
        else
            echo " - https://$DOMAIN (failed)"
        fi
        
        # Check SSL certificate
        echo ""
        echo "SSL Certificate check:"
        SSL_ISSUER=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | grep -o "CN=[^,]*" | head -1)
        if [[ "$SSL_ISSUER" == *"Cloudflare"* ]]; then
            echo "  ✓ Cloudflare SSL certificate"
        elif [[ "$SSL_ISSUER" == *"Let's Encrypt"* ]]; then
            echo "  ✓ Let's Encrypt certificate (direct)"
        elif [[ -n "$SSL_ISSUER" ]]; then
            echo "  ℹ SSL certificate: $SSL_ISSUER"
        else
            echo "  ✗ No SSL certificate or connection failed"
        fi
    else
        echo "No domain configured in .env file"
    fi
else
    echo "No .env file found - domain not configured"
fi

echo ""
echo "=== Recommendations ==="

if ! systemctl is-active nginx >/dev/null 2>&1; then
    echo "⚠ Start nginx: sudo systemctl start nginx"
fi

if ! docker compose ps 2>/dev/null | grep -q "Up"; then
    echo "⚠ Start CTFd: docker compose up -d"
fi

if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    echo "⚠ Check firewall rules - ufw is active"
    echo "  Allow ports: sudo ufw allow 80 && sudo ufw allow 443"
fi

echo ""
echo "=== Cloudflare Recommendations ==="

if [[ -n "$DOMAIN" ]]; then
    if [[ "$RESOLVED_IP" != "$PUBLIC_IP" ]]; then
        echo "🔸 Cloudflare Configuration Tips:"
        echo "  1. SSL/TLS Mode: Set to 'Full (strict)' if you have Let's Encrypt"
        echo "  2. SSL/TLS Mode: Set to 'Flexible' if you only have HTTP"
        echo "  3. Always Use HTTPS: Enable if using SSL"
        echo "  4. Edge Certificates: Check 'Universal SSL' is active"
        echo ""
        echo "🔸 Common Cloudflare Issues:"
        echo "  • 525 Error: Origin SSL certificate not valid"
        echo "  • 526 Error: Origin certificate invalid/self-signed"
        echo "  • 521 Error: Web server is down"
        echo "  • 522 Error: Connection timed out"
        echo ""
        echo "🔸 Quick Cloudflare Fixes:"
        echo "  • Temporarily bypass Cloudflare: Set DNS to 'DNS Only' (gray cloud)"
        echo "  • Check origin server: Test direct IP access"
        echo "  • Verify SSL mode matches your server setup"
        echo ""
    fi
fi

echo "⚠ Don't forget to check Azure Network Security Group!"
echo "  Ports 80 and 443 must be open for inbound traffic"
echo ""

# Check for nginx permission issues and offer fix
if ! sudo nginx -t >/dev/null 2>&1; then
    if sudo nginx -t 2>&1 | grep -q "Permission denied"; then
        echo "=== Nginx Permission Fix ==="
        echo "Nginx has permission issues. Running fix..."
        sudo mkdir -p /run/nginx /var/log/nginx
        sudo touch /run/nginx.pid
        sudo chown -R www-data:www-data /run/nginx /var/log/nginx
        sudo chmod 755 /run/nginx
        sudo chmod 644 /run/nginx.pid
        
        if sudo nginx -t >/dev/null 2>&1; then
            echo "✓ Nginx permissions fixed"
            sudo systemctl restart nginx
            echo "✓ Nginx restarted"
        else
            echo "⚠ Nginx still has issues - may need manual intervention"
        fi
        echo ""
    fi
fi

echo "Access URLs to test:"
echo "  Internal: http://localhost:8000"
if [[ "$PUBLIC_IP" != "Unable to get public IP" ]]; then
    echo "  External: http://$PUBLIC_IP"
fi
EOF

    # Health check script
    cat > "$INSTALL_DIR/health-ctfd.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "=== CTFd Health Check ==="
echo ""
echo "Container Status:"
docker compose ps
echo ""
echo "Service Health:"
if curl -s -o /dev/null -w "CTFd Web: %{http_code}\n" http://localhost:8000 | grep -q "200\|302"; then
    echo "  ✓ CTFd is responding"
else
    echo "  ✗ CTFd is not responding"
fi
if docker compose exec -T db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1" >/dev/null 2>&1; then
    echo "  ✓ Database is accessible"
else
    echo "  ✗ Database is not accessible"
fi
if docker compose exec -T cache redis-cli ping >/dev/null 2>&1; then
    echo "  ✓ Redis is responding"
else
    echo "  ✗ Redis is not responding"
fi
echo ""
echo "Resource Usage:"
docker stats --no-stream
EOF
    
    # Fix script for common issues
    cat > "$INSTALL_DIR/fix-ctfd.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "=== CTFd Fix Script ==="
echo "Attempting to fix common issues..."

# Restart Docker if needed
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Starting Docker..."
    sudo systemctl start docker
    sleep 3
fi

# Check for database issues
if docker compose logs ctfd 2>&1 | grep -q "Access denied\|Can't connect"; then
    echo "Database connection issue detected."
    read -p "Reset database? This will delete all data! [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose down -v
        rm -rf data/mysql/* data/redis/*
        docker compose up -d
        echo "Database reset. Please wait for initialization..."
        sleep 15
    fi
else
    echo "Restarting containers..."
    docker compose restart
fi

echo "Fix attempt complete. Checking status..."
sleep 5
docker compose ps
EOF
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR"/*.sh
    
    # Set ownership
    chown -R $ACTUAL_USER:$ACTUAL_USER "$INSTALL_DIR"
    
    # Setup cron backup
    (crontab -u $ACTUAL_USER -l 2>/dev/null; echo "0 2 * * * $INSTALL_DIR/backup-ctfd.sh") | crontab -u $ACTUAL_USER -
    
    # Final summary
    log "\n${BLUE}========================================${NC}"
    log "${GREEN}     Installation Complete!${NC}"
    log "${BLUE}========================================${NC}"
    log ""
    log "${GREEN}Access Information:${NC}"
    log "  Local: http://localhost:8000"
    log "  Public: http://$PUBLIC_IP"
    log "  Domain: https://$DOMAIN"
    log ""
    log "${GREEN}Credentials (saved in .env):${NC}"
    log "  MySQL Root: $MYSQL_ROOT_PASSWORD"
    log "  Database: $DB_PASSWORD"
    log ""
    log "${GREEN}Management Scripts:${NC}"
    log "  Start: $INSTALL_DIR/start-ctfd.sh"
    log "  Stop: $INSTALL_DIR/stop-ctfd.sh"
    log "  Restart: $INSTALL_DIR/restart-ctfd.sh"
    log "  Logs: $INSTALL_DIR/logs-ctfd.sh"
    log "  Backup: $INSTALL_DIR/backup-ctfd.sh"
    log "  Health: $INSTALL_DIR/health-ctfd.sh"
    log "  Fix: $INSTALL_DIR/fix-ctfd.sh"
    log "  Themes: $INSTALL_DIR/manage-themes.sh"
    log "  Network: $INSTALL_DIR/diagnose-network.sh"
    log ""
    log "${GREEN}Next Steps:${NC}"
    log "  1. Visit https://$DOMAIN/setup"
    log "  2. Create admin account"
    log "  3. Configure CTFd settings"
    log "  4. Change theme in Admin Panel > Configuration > Theme (if themes installed)"
    log ""
    log "${YELLOW}Azure NSG Reminder:${NC}"
    log "  Ensure ports 80 and 443 are open in Network Security Group"
    log ""
    log "${YELLOW}If external access doesn't work:${NC}"
    log "  1. Check Azure NSG: ports 80, 443 must be open"
    log "  2. Check Ubuntu firewall: sudo ufw status"
    log "  3. Test direct access: http://PUBLIC_IP:8000"
    log "  4. Run network diagnostics: ./diagnose-network.sh"
    log ""
    log "${GREEN}Installation log saved to: $LOG_FILE${NC}"
}

# Run main installation
main "$@"