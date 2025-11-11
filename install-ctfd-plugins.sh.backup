#!/bin/bash

#############################################
# CTFd Plugin Installation Script
# Installs plugins to existing CTFd deployment
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd $ACTUAL_USER 2>/dev/null | cut -d: -f6 || echo $HOME)
INSTALL_DIR="$ACTUAL_HOME/CTFd"

# Logging function
log() {
    echo -e "$1"
}

# Header
clear
log "${BLUE}========================================${NC}"
log "${BLUE}     CTFd Plugin Installation Script${NC}"
log "${BLUE}========================================${NC}"
log "${GREEN}Install Directory:${NC} $INSTALL_DIR"
log "${BLUE}========================================${NC}"
echo ""

# Check if CTFd is installed
if [ ! -d "$INSTALL_DIR" ]; then
    log "${RED}CTFd installation not found at $INSTALL_DIR${NC}"
    log "${YELLOW}Please run the main installation script first${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    log "${RED}docker-compose.yml not found${NC}"
    log "${YELLOW}Please ensure CTFd is properly installed${NC}"
    exit 1
fi

# Function to install popular plugins
install_popular_plugins() {
    log "${GREEN}[*] Installing popular CTFd plugins...${NC}"

    # Create plugins directory in data folder
    mkdir -p data/CTFd/plugins

    log "${YELLOW}Available popular plugins:${NC}"
    log "  1) CTFd-Crawler - Challenge discovery plugin"
    log "  2) CTFd-SSO - Single Sign-On support"
    log "  3) CTFd-Webhook - Discord/Slack notifications"
    log "  4) CTFd-Containers - Dynamic container challenges"
    log "  5) All of the above"
    log "  6) Skip plugin installation"
    echo ""

    read -p "$(echo -e "${YELLOW}Select option [1-6]:${NC} ")" plugin_choice

    case $plugin_choice in
        1|5)
            log "${YELLOW}Installing CTFd-Crawler...${NC}"
            git clone https://github.com/ItsFadinG/CTFd-Crawler.git data/CTFd/plugins/CTFd-Crawler 2>/dev/null || {
                log "${YELLOW}CTFd-Crawler already exists, updating...${NC}"
                cd data/CTFd/plugins/CTFd-Crawler && git pull && cd "$INSTALL_DIR"
            }
            ;;&
        2|5)
            log "${YELLOW}Installing CTFd-SSO...${NC}"
            git clone https://github.com/alokmenghrajani/CTFd-SSO.git data/CTFd/plugins/CTFd-SSO 2>/dev/null || {
                log "${YELLOW}CTFd-SSO already exists, updating...${NC}"
                cd data/CTFd/plugins/CTFd-SSO && git pull && cd "$INSTALL_DIR"
            }
            ;;&
        3|5)
            log "${YELLOW}Installing CTFd-Webhook...${NC}"
            git clone https://github.com/sciguy14/CTFd-Webhook.git data/CTFd/plugins/CTFd-Webhook 2>/dev/null || {
                log "${YELLOW}CTFd-Webhook already exists, updating...${NC}"
                cd data/CTFd/plugins/CTFd-Webhook && git pull && cd "$INSTALL_DIR"
            }
            ;;&
        4|5)
            log "${YELLOW}Installing CTFd-Containers...${NC}"
            git clone https://github.com/andyjsmith/CTFd-Containers.git data/CTFd/plugins/CTFd-Containers 2>/dev/null || {
                log "${YELLOW}CTFd-Containers already exists, updating...${NC}"
                cd data/CTFd/plugins/CTFd-Containers && git pull && cd "$INSTALL_DIR"
            }
            log "${YELLOW}Note: CTFd-Containers requires additional Docker configuration${NC}"
            ;;
        6)
            log "${GREEN}Skipping plugin installation${NC}"
            return
            ;;
        *)
            log "${RED}Invalid option${NC}"
            return
            ;;
    esac

    log "${GREEN}✓ Plugins installed successfully${NC}"
}

# Function to install custom plugin from URL
install_custom_plugin() {
    log "${GREEN}[*] Installing custom plugin from URL...${NC}"
    read -p "$(echo -e "${YELLOW}Enter GitHub repository URL (e.g., https://github.com/user/plugin):${NC} ")" plugin_url

    if [[ -z "$plugin_url" ]]; then
        log "${RED}No URL provided${NC}"
        return
    fi

    # Extract plugin name from URL
    plugin_name=$(basename "$plugin_url" .git)

    # Create plugins directory
    mkdir -p data/CTFd/plugins

    # Clone the plugin
    log "${YELLOW}Cloning plugin: $plugin_name...${NC}"
    if git clone "$plugin_url" "data/CTFd/plugins/$plugin_name" 2>/dev/null; then
        log "${GREEN}✓ Plugin $plugin_name installed successfully${NC}"
    else
        log "${RED}Failed to clone plugin from $plugin_url${NC}"
        log "${YELLOW}Plugin may already exist or URL may be invalid${NC}"
    fi
}

# Function to update docker-compose.yml with plugin volume
update_docker_compose() {
    log "${YELLOW}Updating Docker configuration for plugins...${NC}"

    # Check if plugins volume already exists
    if grep -q "./data/CTFd/plugins:/opt/CTFd/CTFd/plugins" docker-compose.yml; then
        log "${GREEN}✓ Plugin volume already configured${NC}"
        return
    fi

    # Backup current docker-compose.yml
    cp docker-compose.yml docker-compose.yml.backup

    # Add plugins volume to CTFd service
    # This adds the volume mount after the uploads volume
    sed -i '/- \.\/data\/CTFd\/uploads:\/var\/uploads/a\      - ./data/CTFd/plugins:/opt/CTFd/CTFd/plugins' docker-compose.yml

    log "${GREEN}✓ Docker configuration updated${NC}"
}

# Function to restart CTFd with plugins
restart_ctfd() {
    log "${YELLOW}Restarting CTFd to load plugins...${NC}"

    # Stop CTFd container
    docker compose stop ctfd

    # Start CTFd container
    docker compose up -d ctfd

    # Wait for CTFd to be ready
    log "${YELLOW}Waiting for CTFd to be ready...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:8000 > /dev/null; then
            log "${GREEN}✓ CTFd is ready with plugins loaded${NC}"
            return
        fi
        sleep 2
    done

    log "${RED}CTFd may not have started properly. Check logs with: docker compose logs ctfd${NC}"
}

# Main menu
main_menu() {
    log "${YELLOW}Plugin Installation Options:${NC}"
    log "  1) Install popular plugins"
    log "  2) Install custom plugin from GitHub URL"
    log "  3) List installed plugins"
    log "  4) Update all installed plugins"
    log "  5) Exit"
    echo ""

    read -p "$(echo -e "${YELLOW}Select option [1-5]:${NC} ")" main_choice

    case $main_choice in
        1)
            install_popular_plugins
            update_docker_compose
            restart_ctfd
            ;;
        2)
            install_custom_plugin
            update_docker_compose
            restart_ctfd
            ;;
        3)
            log "${GREEN}[*] Installed plugins:${NC}"
            if [ -d "data/CTFd/plugins" ]; then
                ls -la data/CTFd/plugins/ 2>/dev/null | grep "^d" | awk '{print "  - " $NF}' | tail -n +3
            else
                log "${YELLOW}No plugins directory found${NC}"
            fi
            ;;
        4)
            log "${GREEN}[*] Updating all installed plugins...${NC}"
            if [ -d "data/CTFd/plugins" ]; then
                for plugin_dir in data/CTFd/plugins/*/; do
                    if [ -d "$plugin_dir/.git" ]; then
                        plugin_name=$(basename "$plugin_dir")
                        log "${YELLOW}Updating $plugin_name...${NC}"
                        cd "$plugin_dir" && git pull && cd "$INSTALL_DIR"
                    fi
                done
                restart_ctfd
                log "${GREEN}✓ All plugins updated${NC}"
            else
                log "${YELLOW}No plugins directory found${NC}"
            fi
            ;;
        5)
            log "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            log "${RED}Invalid option${NC}"
            ;;
    esac
}

# Display important note about plugins
log "${YELLOW}========================================${NC}"
log "${YELLOW}IMPORTANT NOTES:${NC}"
log "${YELLOW}1. Plugins require CTFd restart to take effect${NC}"
log "${YELLOW}2. Some plugins may require additional configuration${NC}"
log "${YELLOW}3. Check plugin documentation for specific requirements${NC}"
log "${YELLOW}4. Plugin compatibility depends on CTFd version${NC}"
log "${YELLOW}========================================${NC}"
echo ""

# Run main menu
main_menu

# Show how to verify plugins
echo ""
log "${GREEN}========================================${NC}"
log "${GREEN}Plugin Installation Complete!${NC}"
log "${GREEN}========================================${NC}"
log ""
log "${BLUE}To verify plugins are loaded:${NC}"
log "  1. Access CTFd admin panel"
log "  2. Go to Admin → Plugins"
log "  3. Configure plugin settings as needed"
log ""
log "${BLUE}To check plugin logs:${NC}"
log "  docker compose logs ctfd | grep -i plugin"
log ""
log "${BLUE}To manually manage plugins:${NC}"
log "  cd $INSTALL_DIR/data/CTFd/plugins"
log ""