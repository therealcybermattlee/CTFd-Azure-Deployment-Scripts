#!/bin/bash

#############################################
# CTFd Theme Fix Script
# Fixes common theme visibility issues
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
clear
log "${BLUE}========================================${NC}"
log "${BLUE}     CTFd Theme Fix Tool${NC}"
log "${BLUE}========================================${NC}"
echo ""

cd "$CTFD_DIR"

log "${YELLOW}[1] Creating proper theme structure...${NC}"

# Ensure theme directory exists
mkdir -p "data/CTFd/themes/$THEME_NAME/templates"
mkdir -p "data/CTFd/themes/$THEME_NAME/static/css"
mkdir -p "data/CTFd/themes/$THEME_NAME/static/js"

log "${YELLOW}[2] Adding required __init__.py file...${NC}"

# Create __init__.py (REQUIRED for CTFd to recognize the theme)
cat > "data/CTFd/themes/$THEME_NAME/__init__.py" << 'EOF'
"""
Cyber Theme for CTFd
A hacker-themed cyberpunk design
"""
EOF

log "${GREEN}  ✓ Created __init__.py${NC}"

log "${YELLOW}[3] Checking if theme files exist...${NC}"

# Check if base.html exists, if not copy from install script
if [ ! -f "data/CTFd/themes/$THEME_NAME/templates/base.html" ]; then
    log "${YELLOW}  Creating base.html template...${NC}"
    
    cat > "data/CTFd/themes/$THEME_NAME/templates/base.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}{{ get_config('ctf_name') }}{% endblock %} - Cyber Challenge</title>
    
    <!-- CTFd Core Requirements -->
    {{ Styles.get() }}
    
    <!-- Custom Hacker Theme CSS -->
    <link rel="stylesheet" href="{{ url_for('views.themes', theme='cyber-theme', path='static/css/cyber.css') }}">
    
    {% block stylesheets %}{% endblock %}
</head>
<body>
    <!-- Navigation -->
    <nav class="navbar">
        <div class="container">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <a href="{{ url_for('views.index') }}" class="navbar-brand glitch" data-text="{{ get_config('ctf_name') }}">{{ get_config('ctf_name') }}</a>
                <div style="display: flex; gap: 1rem;">
                    {% if get_config('challenge_visibility') != 'admins' %}
                    <a href="{{ url_for('challenges.listing') }}" class="nav-link">Challenges</a>
                    {% endif %}
                    {% if get_config('score_visibility') != 'admins' %}
                    <a href="{{ url_for('scoreboard.listing') }}" class="nav-link">Scoreboard</a>
                    {% endif %}
                    {% if get_config('account_visibility') != 'admins' %}
                    <a href="{{ url_for('users.listing') }}" class="nav-link">Users</a>
                    {% endif %}
                    {% if user %}
                        {% if user.team_id %}
                        <a href="{{ url_for('teams.private') }}" class="nav-link">Team</a>
                        {% endif %}
                        <a href="{{ url_for('views.settings') }}" class="nav-link">Profile</a>
                        <a href="{{ url_for('auth.logout') }}" class="nav-link">Logout</a>
                    {% else %}
                        {% if get_config('registration_visibility') != 'admins' %}
                        <a href="{{ url_for('auth.register') }}" class="nav-link">Register</a>
                        {% endif %}
                        <a href="{{ url_for('auth.login') }}" class="nav-link">Login</a>
                    {% endif %}
                </div>
            </div>
        </div>
    </nav>

    <!-- Main Content Area -->
    <div class="container">
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                    <div class="alert alert-{{ category }}">{{ message }}</div>
                {% endfor %}
            {% endif %}
        {% endwith %}
        
        {% block content %}{% endblock %}
    </div>

    <!-- CTFd Core Scripts -->
    {{ Scripts.get() }}
    
    <!-- Custom Theme Scripts -->
    <script src="{{ url_for('views.themes', theme='cyber-theme', path='static/js/cyber.js') }}"></script>
    
    {% block scripts %}{% endblock %}
</body>
</html>
EOF
    log "${GREEN}  ✓ Created base.html${NC}"
fi

# Ensure CSS exists
if [ ! -f "data/CTFd/themes/$THEME_NAME/static/css/cyber.css" ]; then
    log "${YELLOW}  Creating cyber.css...${NC}"
    # Copy CSS from install script (truncated for brevity - use full CSS from install script)
    cp ~/ctfd-azure-deployment-scripts/cyber-theme/static/css/cyber.css "data/CTFd/themes/$THEME_NAME/static/css/" 2>/dev/null || \
    curl -s https://raw.githubusercontent.com/therealcybermattlee/CTFd-Azure-Deployment-Scripts/main/cyber-theme/static/css/cyber.css > "data/CTFd/themes/$THEME_NAME/static/css/cyber.css" 2>/dev/null || \
    touch "data/CTFd/themes/$THEME_NAME/static/css/cyber.css"
fi

# Ensure JS exists
if [ ! -f "data/CTFd/themes/$THEME_NAME/static/js/cyber.js" ]; then
    log "${YELLOW}  Creating cyber.js...${NC}"
    touch "data/CTFd/themes/$THEME_NAME/static/js/cyber.js"
fi

log "${YELLOW}[4] Verifying Docker volume mount...${NC}"

# Check and add volume mount if needed
if ! grep -q "./data/CTFd/themes:/opt/CTFd/CTFd/themes" docker-compose.yml; then
    log "${YELLOW}  Adding themes volume mount...${NC}"
    
    # Backup original
    cp docker-compose.yml docker-compose.yml.bak
    
    # Add the volume mount after uploads line
    sed -i '/- \.\/data\/CTFd\/uploads:\/var\/uploads/a\      - ./data/CTFd/themes:/opt/CTFd/CTFd/themes' docker-compose.yml
    
    log "${GREEN}  ✓ Added volume mount${NC}"
else
    log "${GREEN}  ✓ Volume mount already exists${NC}"
fi

log "${YELLOW}[5] Setting correct permissions...${NC}"

# Try to fix permissions - if it fails, continue anyway
if sudo chown -R 1001:1001 "data/CTFd/themes/" 2>/dev/null; then
    log "${GREEN}  ✓ Ownership set to CTFd user${NC}"
else
    log "${YELLOW}  ⚠ Could not change ownership (may already be correct)${NC}"
fi

if sudo chmod -R 755 "data/CTFd/themes/" 2>/dev/null; then
    log "${GREEN}  ✓ Permissions set${NC}"
else
    # Try without sudo as fallback
    chmod -R 755 "data/CTFd/themes/" 2>/dev/null || log "${YELLOW}  ⚠ Could not change permissions (continuing anyway)${NC}"
fi

log "${YELLOW}[6] Restarting CTFd container...${NC}"

# Full restart to ensure volume mount takes effect
docker compose down
sleep 2
docker compose up -d

log "${YELLOW}  Waiting for CTFd to start...${NC}"
sleep 15

# Verify theme is accessible in container
log "${YELLOW}[7] Verifying theme in container...${NC}"

if docker compose exec ctfd test -f "/opt/CTFd/CTFd/themes/$THEME_NAME/__init__.py" 2>/dev/null; then
    log "${GREEN}  ✓ Theme is accessible in container${NC}"
    
    # List themes detected by CTFd
    docker compose exec ctfd python -c "
import os
theme_dir = '/opt/CTFd/CTFd/themes'
themes = [d for d in os.listdir(theme_dir) if os.path.isdir(os.path.join(theme_dir, d)) and not d.startswith('.')]
print('Themes detected by CTFd:', themes)
" 2>/dev/null || true
else
    log "${RED}  ❌ Theme still not accessible${NC}"
fi

log ""
log "${BLUE}========================================${NC}"
log "${GREEN}     Theme Fix Complete!${NC}"
log "${BLUE}========================================${NC}"
log ""
log "${YELLOW}Next steps:${NC}"
log "  1. Login to CTFd admin panel"
log "  2. Go to Admin Panel > Config > Appearance"
log "  3. Look for 'cyber-theme' in the dropdown"
log "  4. If not visible, check container logs: docker compose logs ctfd"
log ""
log "${GREEN}The theme should now be available!${NC}"