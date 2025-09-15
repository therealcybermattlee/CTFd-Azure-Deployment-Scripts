#!/bin/bash

#############################################
# Quick CTFd Theme Fix
# Minimal approach that works with Docker permissions
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
THEME_NAME="cyber-theme"
CTFD_DIR="$HOME/CTFd"

# Logging function
log() {
    echo -e "$1"
}

# Header
log "${BLUE}========================================${NC}"
log "${BLUE}     Quick Theme Fix${NC}"
log "${BLUE}========================================${NC}"
echo ""

cd "$CTFD_DIR"

log "${YELLOW}Step 1: Creating __init__.py directly in container...${NC}"

# Create __init__.py directly inside the container to avoid permission issues
docker compose exec ctfd bash -c "
cat > /opt/CTFd/CTFd/themes/$THEME_NAME/__init__.py << 'EOF'
'''Cyber Theme for CTFd'''
EOF
"

if [ $? -eq 0 ]; then
    log "${GREEN}✓ Created __init__.py in container${NC}"
else
    log "${YELLOW}⚠ Could not create __init__.py (may already exist)${NC}"
fi

log "${YELLOW}Step 2: Verifying theme structure in container...${NC}"

# Check what CTFd sees
docker compose exec ctfd bash -c "
echo 'Checking theme directory...'
if [ -d /opt/CTFd/CTFd/themes/$THEME_NAME ]; then
    echo '✓ Theme directory exists'
    echo 'Files in theme:'
    ls -la /opt/CTFd/CTFd/themes/$THEME_NAME/
    
    # Python check
    python3 -c \"
import os
import sys
theme_path = '/opt/CTFd/CTFd/themes/$THEME_NAME'
if os.path.exists(theme_path) and os.path.exists(os.path.join(theme_path, '__init__.py')):
    print('✓ Theme should be detected by CTFd')
else:
    print('✗ Missing required files')
    sys.exit(1)
\"
else
    echo '✗ Theme directory not found'
    exit 1
fi
"

log "${YELLOW}Step 3: Soft restart CTFd to reload themes...${NC}"

# Just restart the CTFd container, not the whole stack
docker compose restart ctfd

log "${YELLOW}Waiting for CTFd to reload...${NC}"
sleep 10

# Final check
log "${YELLOW}Step 4: Final verification...${NC}"

docker compose exec ctfd python3 -c "
import os
theme_dir = '/opt/CTFd/CTFd/themes'
themes = []
for item in os.listdir(theme_dir):
    item_path = os.path.join(theme_dir, item)
    if os.path.isdir(item_path) and not item.startswith('.'):
        # Check if it has __init__.py
        if os.path.exists(os.path.join(item_path, '__init__.py')):
            themes.append(item)
        else:
            print(f'Theme {item} missing __init__.py')

print('\\nThemes available to CTFd:', themes)
if '$THEME_NAME' in themes:
    print('✓✓✓ $THEME_NAME is ready to use!')
else:
    print('✗✗✗ $THEME_NAME not detected')
"

log ""
log "${BLUE}========================================${NC}"
log "${GREEN}Done! Check the admin panel now.${NC}"
log "${BLUE}========================================${NC}"
log ""
log "Admin Panel → Config → Appearance → Theme Dropdown"
log ""
log "If still not visible, try clearing browser cache (Ctrl+Shift+R)"