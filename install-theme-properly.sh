#!/bin/bash

#############################################
# Proper CTFd Theme Installation
# Copies theme files into container without volume mount
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

THEME_NAME="cyber-theme"
CTFD_DIR="$HOME/CTFd"

# Logging function
log() {
    echo -e "$1"
}

# Header
clear
log "${BLUE}========================================${NC}"
log "${BLUE}     Proper Theme Installation${NC}"
log "${BLUE}========================================${NC}"
echo ""

cd "$CTFD_DIR"

log "${YELLOW}[1] Creating temporary theme directory...${NC}"

# Create temp directory with theme files
TEMP_DIR="/tmp/cyber-theme-install"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR/$THEME_NAME/templates"
mkdir -p "$TEMP_DIR/$THEME_NAME/static/css"
mkdir -p "$TEMP_DIR/$THEME_NAME/static/js"

log "${YELLOW}[2] Creating theme files...${NC}"

# Create __init__.py
cat > "$TEMP_DIR/$THEME_NAME/__init__.py" << 'EOF'
"""Cyber Theme for CTFd"""
EOF

# Create base.html
cat > "$TEMP_DIR/$THEME_NAME/templates/base.html" << 'EOF'
{% extends "core/base.html" %}

{% block stylesheets %}
{{ super() }}
<link rel="stylesheet" href="{{ url_for('views.themes', theme='cyber-theme', path='static/css/cyber.css') }}">
{% endblock %}

{% block scripts %}
{{ super() }}
<script src="{{ url_for('views.themes', theme='cyber-theme', path='static/js/cyber.js') }}"></script>
{% endblock %}
EOF

# Create a simpler CSS that extends the core theme
cat > "$TEMP_DIR/$THEME_NAME/static/css/cyber.css" << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&display=swap');

:root {
    --primary-green: #00ff41;
    --bg-black: #0a0a0a;
}

body {
    font-family: 'Share Tech Mono', monospace !important;
    background: var(--bg-black) !important;
}

.navbar {
    background: linear-gradient(180deg, #1a1a1a 0%, #0d0d0d 100%) !important;
    border-bottom: 2px solid var(--primary-green) !important;
}

.navbar-brand, .nav-link {
    color: var(--primary-green) !important;
}

.btn-primary {
    background: transparent !important;
    color: var(--primary-green) !important;
    border: 1px solid var(--primary-green) !important;
}

.btn-primary:hover {
    background: var(--primary-green) !important;
    color: var(--bg-black) !important;
}

.card {
    background: #1a1a1a !important;
    border: 1px solid #008f11 !important;
}

.card-header {
    background: #0d0d0d !important;
    color: var(--primary-green) !important;
}

/* Override core theme colors */
.text-white { color: var(--primary-green) !important; }
.bg-dark { background: var(--bg-black) !important; }
EOF

# Create minimal JS
cat > "$TEMP_DIR/$THEME_NAME/static/js/cyber.js" << 'EOF'
console.log('[CYBER_THEME] Loaded');
EOF

log "${GREEN}✓ Theme files created${NC}"

log "${YELLOW}[3] Copying theme into container...${NC}"

# Copy the theme directory into the container
docker cp "$TEMP_DIR/$THEME_NAME" ctfd:/tmp/

# Move theme to correct location inside container
docker compose exec ctfd bash -c "
    # Ensure themes directory exists
    mkdir -p /opt/CTFd/CTFd/themes
    
    # Remove old theme if exists
    rm -rf /opt/CTFd/CTFd/themes/$THEME_NAME
    
    # Move new theme
    mv /tmp/$THEME_NAME /opt/CTFd/CTFd/themes/
    
    # Set permissions
    chown -R 1001:1001 /opt/CTFd/CTFd/themes/$THEME_NAME
    chmod -R 755 /opt/CTFd/CTFd/themes/$THEME_NAME
    
    # Verify
    if [ -f /opt/CTFd/CTFd/themes/$THEME_NAME/__init__.py ]; then
        echo '✓ Theme installed successfully'
        ls -la /opt/CTFd/CTFd/themes/$THEME_NAME/
    else
        echo '✗ Theme installation failed'
        exit 1
    fi
"

log "${GREEN}✓ Theme copied into container${NC}"

log "${YELLOW}[4] Restarting CTFd...${NC}"

# Soft restart to pick up the new theme
docker compose restart ctfd

log "${YELLOW}Waiting for CTFd to restart...${NC}"
sleep 10

log "${YELLOW}[5] Verifying theme availability...${NC}"

docker compose exec ctfd python3 -c "
import os
theme_dir = '/opt/CTFd/CTFd/themes'
themes = [d for d in os.listdir(theme_dir) if os.path.isdir(os.path.join(theme_dir, d)) and not d.startswith('.')]
print('Available themes:', themes)
if '$THEME_NAME' in themes:
    print('✓ $THEME_NAME is available!')
"

# Clean up
rm -rf "$TEMP_DIR"

log ""
log "${BLUE}========================================${NC}"
log "${GREEN}     Theme Installation Complete${NC}"
log "${BLUE}========================================${NC}"
log ""
log "${GREEN}Theme has been installed WITHOUT volume mounts${NC}"
log ""
log "${YELLOW}To activate:${NC}"
log "  1. Login to CTFd admin panel"
log "  2. Go to Admin Panel → Config → Appearance"
log "  3. Select 'cyber-theme' from dropdown"
log "  4. Save settings"
log ""
log "${YELLOW}Note: This theme extends the core theme rather than replacing it.${NC}"