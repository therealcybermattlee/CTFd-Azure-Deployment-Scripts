#!/bin/bash

#############################################
# CTFd Theme Installation via Uploads Directory
# Uses the uploads volume which we have write access to
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
log "${BLUE}     Theme Installation via Uploads${NC}"
log "${BLUE}========================================${NC}"
echo ""

cd "$CTFD_DIR"

log "${YELLOW}[1] Creating theme in uploads directory (where we have write access)...${NC}"

# Create theme structure in the uploads directory which is mounted
mkdir -p "data/CTFd/uploads/themes/$THEME_NAME/templates"
mkdir -p "data/CTFd/uploads/themes/$THEME_NAME/static/css"
mkdir -p "data/CTFd/uploads/themes/$THEME_NAME/static/js"

log "${YELLOW}[2] Creating theme files...${NC}"

# Create __init__.py
cat > "data/CTFd/uploads/themes/$THEME_NAME/__init__.py" << 'EOF'
"""Cyber Theme for CTFd"""
EOF

# Create base.html that extends core
cat > "data/CTFd/uploads/themes/$THEME_NAME/templates/base.html" << 'EOF'
{% extends "core/base.html" %}

{% block stylesheets %}
{{ super() }}
<style>
    @import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&display=swap');
    
    :root {
        --cyber-green: #00ff41;
        --cyber-dark: #0a0a0a;
        --cyber-card: #1a1a1a;
    }
    
    body {
        font-family: 'Share Tech Mono', monospace !important;
        background: var(--cyber-dark) !important;
        color: var(--cyber-green) !important;
    }
    
    .navbar {
        background: linear-gradient(180deg, #1a1a1a 0%, #0d0d0d 100%) !important;
        border-bottom: 2px solid var(--cyber-green) !important;
    }
    
    .navbar-brand {
        color: var(--cyber-green) !important;
        text-shadow: 0 0 10px rgba(0, 255, 65, 0.8) !important;
    }
    
    .nav-link {
        color: var(--cyber-green) !important;
    }
    
    .btn-primary {
        background: transparent !important;
        color: var(--cyber-green) !important;
        border: 1px solid var(--cyber-green) !important;
    }
    
    .btn-primary:hover {
        background: var(--cyber-green) !important;
        color: var(--cyber-dark) !important;
    }
    
    .card {
        background: var(--cyber-card) !important;
        border: 1px solid var(--cyber-green) !important;
    }
    
    .jumbotron {
        background: var(--cyber-card) !important;
        border: 1px solid var(--cyber-green) !important;
    }
    
    h1, h2, h3, h4, h5, h6 {
        color: var(--cyber-green) !important;
    }
    
    .text-muted {
        color: #00cc33 !important;
    }
    
    input, textarea, select {
        background: var(--cyber-dark) !important;
        color: var(--cyber-green) !important;
        border: 1px solid var(--cyber-green) !important;
    }
    
    .table {
        color: var(--cyber-green) !important;
    }
    
    .modal-content {
        background: var(--cyber-card) !important;
        border: 1px solid var(--cyber-green) !important;
    }
</style>
{% endblock %}

{% block scripts %}
{{ super() }}
<script>
    console.log('[CYBER_THEME] Activated');
    document.addEventListener('DOMContentLoaded', function() {
        // Add cyber effect to page title
        const title = document.querySelector('.navbar-brand');
        if (title) {
            title.style.animation = 'pulse 2s infinite';
        }
    });
</script>
<style>
    @keyframes pulse {
        0% { opacity: 1; }
        50% { opacity: 0.7; }
        100% { opacity: 1; }
    }
</style>
{% endblock %}
EOF

# Create empty CSS file (styles are inline in base.html for simplicity)
touch "data/CTFd/uploads/themes/$THEME_NAME/static/css/cyber.css"

# Create empty JS file (script is inline in base.html for simplicity)
touch "data/CTFd/uploads/themes/$THEME_NAME/static/js/cyber.js"

log "${GREEN}✓ Theme files created${NC}"

log "${YELLOW}[3] Creating symlink inside container...${NC}"

# Try to create a symlink from uploads to themes directory
docker compose exec -T ctfd bash << 'SCRIPT'
# Check if we can create a symlink
if [ -w /opt/CTFd/CTFd/themes ]; then
    # Remove old theme if exists
    rm -rf /opt/CTFd/CTFd/themes/cyber-theme 2>/dev/null || true
    
    # Try to create symlink
    ln -sf /var/uploads/themes/cyber-theme /opt/CTFd/CTFd/themes/cyber-theme 2>/dev/null && \
    echo "✓ Symlink created" || echo "✗ Cannot create symlink"
else
    echo "✗ Themes directory not writable"
    
    # Alternative: Try to copy using Python within CTFd context
    python3 << 'PYTHON'
import os
import shutil
import sys

src = '/var/uploads/themes/cyber-theme'
dst = '/opt/CTFd/CTFd/themes/cyber-theme'

try:
    if os.path.exists(src):
        # Try to copy
        if os.path.exists(dst):
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
        print("✓ Theme copied via Python")
    else:
        print("✗ Source theme not found")
        sys.exit(1)
except Exception as e:
    print(f"✗ Failed: {e}")
    
    # Last resort: Modify CTFd to load from uploads
    print("\nTrying alternative: Modifying theme search path...")
PYTHON
fi

# Verify if theme is accessible
if [ -f /opt/CTFd/CTFd/themes/cyber-theme/__init__.py ]; then
    echo "✓ Theme is in place"
else
    # Check if it's in uploads at least
    if [ -f /var/uploads/themes/cyber-theme/__init__.py ]; then
        echo "✓ Theme exists in uploads directory"
        echo "Note: May need manual configuration"
    else
        echo "✗ Theme not found anywhere"
    fi
fi
SCRIPT

log "${YELLOW}[4] Restarting CTFd...${NC}"
docker compose restart ctfd

log "${YELLOW}Waiting for CTFd to restart...${NC}"
sleep 10

log "${YELLOW}[5] Checking theme availability...${NC}"

docker compose exec -T ctfd python3 << 'CHECK'
import os
import sys

# Check standard themes directory
themes_dir = '/opt/CTFd/CTFd/themes'
if os.path.exists(themes_dir):
    themes = [d for d in os.listdir(themes_dir) 
              if os.path.isdir(os.path.join(themes_dir, d)) 
              and not d.startswith('.')]
    print(f"Themes in standard directory: {themes}")
    
    if 'cyber-theme' in themes:
        print("✓✓✓ cyber-theme is available!")
    else:
        print("✗ cyber-theme not in standard directory")

# Also check uploads
uploads_themes = '/var/uploads/themes'
if os.path.exists(uploads_themes):
    alt_themes = [d for d in os.listdir(uploads_themes) 
                  if os.path.isdir(os.path.join(uploads_themes, d))]
    print(f"Themes in uploads: {alt_themes}")
CHECK

log ""
log "${BLUE}========================================${NC}"
log "${GREEN}     Installation Attempt Complete${NC}"
log "${BLUE}========================================${NC}"
log ""
log "${YELLOW}Check if 'cyber-theme' appears in the admin panel.${NC}"
log ""
log "If not visible, we have one more option:"
log "  Run: ${GREEN}./install-theme-core-override.sh${NC}"
log ""
log "Theme files are saved in: data/CTFd/uploads/themes/cyber-theme/"