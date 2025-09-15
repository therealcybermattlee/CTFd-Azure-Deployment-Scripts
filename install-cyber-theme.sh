#!/bin/bash

#############################################
# CTFd Cyber Theme Installation Script
# Installs the custom hacker theme to live instance
#############################################

set -e  # Exit on error

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
log "${BLUE}     CTFd Cyber Theme Installer${NC}"
log "${BLUE}========================================${NC}"
log "${GREEN}Installing custom hacker theme...${NC}"
log "${BLUE}========================================${NC}"
echo ""

# Check if running in CTFd directory
if [ ! -f "$CTFD_DIR/docker-compose.yml" ]; then
    log "${RED}CTFd installation not found at $CTFD_DIR${NC}"
    log "${YELLOW}Please run this script from your CTFd installation directory${NC}"
    exit 1
fi

cd "$CTFD_DIR"

log "${GREEN}[Step 1] Creating theme directory structure...${NC}"

# Create theme directories
mkdir -p "data/CTFd/themes/$THEME_NAME/templates"
mkdir -p "data/CTFd/themes/$THEME_NAME/static/css"
mkdir -p "data/CTFd/themes/$THEME_NAME/static/js"

log "${GREEN}[Step 2] Installing theme files...${NC}"

# Create base.html template
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

# Create CSS file
cat > "data/CTFd/themes/$THEME_NAME/static/css/cyber.css" << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=VT323&display=swap');

:root {
    --primary-green: #00ff41;
    --secondary-green: #00cc33;
    --dark-green: #008f11;
    --bg-black: #0a0a0a;
    --bg-dark: #0d0d0d;
    --bg-card: #1a1a1a;
    --text-primary: #00ff41;
    --text-secondary: #00cc33;
    --text-dim: #008f11;
    --error-red: #ff0040;
    --warning-yellow: #ffcc00;
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Share Tech Mono', monospace !important;
    background: var(--bg-black) !important;
    color: var(--text-primary) !important;
    min-height: 100vh;
    position: relative;
    overflow-x: hidden;
}

/* Animated background matrix effect */
body::before {
    content: '';
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: linear-gradient(0deg, transparent 50%, rgba(0, 255, 65, 0.03) 50%);
    background-size: 50px 50px;
    animation: scanline 8s linear infinite;
    pointer-events: none;
    z-index: 1;
}

@keyframes scanline {
    0% { transform: translateY(0); }
    100% { transform: translateY(50px); }
}

/* Navigation */
.navbar {
    background: linear-gradient(180deg, #1a1a1a 0%, #0d0d0d 100%) !important;
    border-bottom: 2px solid var(--primary-green) !important;
    padding: 1rem 0 !important;
    position: relative;
    z-index: 1000;
    box-shadow: 0 0 20px rgba(0, 255, 65, 0.5) !important;
}

.navbar-brand {
    font-size: 1.8rem !important;
    font-weight: bold !important;
    color: var(--primary-green) !important;
    text-decoration: none !important;
    text-shadow: 0 0 10px rgba(0, 255, 65, 0.8) !important;
    letter-spacing: 2px !important;
}

.nav-link {
    color: var(--text-secondary) !important;
    text-decoration: none !important;
    padding: 0.5rem 1rem !important;
    margin: 0 0.25rem !important;
    border: 1px solid transparent !important;
    transition: all 0.3s ease !important;
    position: relative !important;
    text-transform: uppercase !important;
    font-size: 0.9rem !important;
}

.nav-link:hover {
    color: var(--primary-green) !important;
    border: 1px solid var(--primary-green) !important;
    background: rgba(0, 255, 65, 0.1) !important;
    text-shadow: 0 0 5px rgba(0, 255, 65, 0.8) !important;
}

.nav-link::before {
    content: '> ';
    opacity: 0;
    transition: opacity 0.3s ease;
}

.nav-link:hover::before {
    opacity: 1;
}

/* Main Container */
.container {
    position: relative !important;
    z-index: 10 !important;
    max-width: 1200px !important;
    margin: 0 auto !important;
    padding: 2rem !important;
}

/* Cards */
.card {
    background: var(--bg-card) !important;
    border: 1px solid var(--dark-green) !important;
    border-radius: 0 !important;
    margin-bottom: 2rem !important;
    position: relative !important;
    overflow: hidden !important;
    box-shadow: 0 0 15px rgba(0, 255, 65, 0.2) !important;
}

.card::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 2px;
    background: linear-gradient(90deg, transparent, var(--primary-green), transparent);
    animation: scan 3s linear infinite;
}

@keyframes scan {
    0% { left: -100%; }
    100% { left: 100%; }
}

.card-header {
    background: linear-gradient(90deg, var(--bg-dark) 0%, var(--bg-card) 100%) !important;
    color: var(--primary-green) !important;
    border-bottom: 1px solid var(--dark-green) !important;
    padding: 1rem !important;
    font-size: 1.2rem !important;
    text-transform: uppercase !important;
    letter-spacing: 1px !important;
}

.card-body {
    padding: 1.5rem !important;
    color: var(--text-secondary) !important;
}

/* Buttons */
.btn {
    background: transparent !important;
    color: var(--primary-green) !important;
    border: 1px solid var(--primary-green) !important;
    padding: 0.75rem 1.5rem !important;
    text-transform: uppercase !important;
    letter-spacing: 1px !important;
    cursor: pointer !important;
    transition: all 0.3s ease !important;
    font-family: 'Share Tech Mono', monospace !important;
    position: relative !important;
    overflow: hidden !important;
}

.btn::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: var(--primary-green);
    transition: left 0.3s ease;
    z-index: -1;
}

.btn:hover {
    color: var(--bg-black) !important;
    text-shadow: none !important;
    box-shadow: 0 0 15px rgba(0, 255, 65, 0.6) !important;
}

.btn:hover::before {
    left: 0;
}

.btn-danger {
    color: var(--error-red) !important;
    border-color: var(--error-red) !important;
}

.btn-danger::before {
    background: var(--error-red) !important;
}

.btn-danger:hover {
    color: var(--bg-black) !important;
}

/* Forms */
.form-control {
    background: var(--bg-dark) !important;
    border: 1px solid var(--dark-green) !important;
    color: var(--primary-green) !important;
    padding: 0.75rem !important;
    font-family: 'Share Tech Mono', monospace !important;
    transition: all 0.3s ease !important;
}

.form-control:focus {
    outline: none !important;
    border-color: var(--primary-green) !important;
    box-shadow: 0 0 10px rgba(0, 255, 65, 0.3) !important;
    background: var(--bg-card) !important;
}

.form-control::placeholder {
    color: var(--text-dim) !important;
}

/* Tables */
.table {
    width: 100% !important;
    color: var(--text-secondary) !important;
    border-collapse: collapse !important;
}

.table th {
    background: var(--bg-dark) !important;
    color: var(--primary-green) !important;
    padding: 1rem !important;
    text-align: left !important;
    border-bottom: 2px solid var(--dark-green) !important;
    text-transform: uppercase !important;
    letter-spacing: 1px !important;
}

.table td {
    padding: 0.75rem 1rem !important;
    border-bottom: 1px solid rgba(0, 255, 65, 0.1) !important;
}

.table tr:hover {
    background: rgba(0, 255, 65, 0.05) !important;
}

/* Alerts */
.alert {
    padding: 1rem !important;
    margin-bottom: 1rem !important;
    border: 1px solid !important;
    position: relative !important;
    background: var(--bg-card) !important;
}

.alert-success {
    border-color: var(--primary-green) !important;
    color: var(--primary-green) !important;
    background: rgba(0, 255, 65, 0.1) !important;
}

.alert-danger {
    border-color: var(--error-red) !important;
    color: var(--error-red) !important;
    background: rgba(255, 0, 64, 0.1) !important;
}

.alert-warning {
    border-color: var(--warning-yellow) !important;
    color: var(--warning-yellow) !important;
    background: rgba(255, 204, 0, 0.1) !important;
}

/* Challenge Cards */
.challenge-button {
    background: var(--bg-card) !important;
    border: 1px solid var(--dark-green) !important;
    padding: 1.5rem !important;
    cursor: pointer !important;
    transition: all 0.3s ease !important;
    position: relative !important;
    overflow: hidden !important;
    color: var(--text-secondary) !important;
    margin-bottom: 1rem !important;
}

.challenge-button:hover {
    transform: translateY(-5px) !important;
    border-color: var(--primary-green) !important;
    box-shadow: 0 5px 20px rgba(0, 255, 65, 0.4) !important;
}

/* Glitch Effect */
.glitch {
    position: relative;
    color: var(--primary-green);
    animation: glitch-skew 1s infinite linear alternate-reverse;
}

.glitch::before,
.glitch::after {
    content: attr(data-text);
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
}

.glitch::before {
    animation: glitch-1 0.2s infinite;
    color: var(--error-red);
    z-index: -1;
}

.glitch::after {
    animation: glitch-2 0.2s infinite;
    color: var(--warning-yellow);
    z-index: -2;
}

@keyframes glitch-1 {
    0% {
        clip: rect(44px, 450px, 56px, 0);
        transform: translate(-2px, -2px);
    }
    100% {
        clip: rect(10px, 450px, 100px, 0);
        transform: translate(2px, 2px);
    }
}

@keyframes glitch-2 {
    0% {
        clip: rect(20px, 450px, 30px, 0);
        transform: translate(2px, 0);
    }
    100% {
        clip: rect(80px, 450px, 90px, 0);
        transform: translate(-2px, 0);
    }
}

@keyframes glitch-skew {
    0% { transform: skew(0deg); }
    20% { transform: skew(2deg); }
    40% { transform: skew(-2deg); }
    60% { transform: skew(1deg); }
    80% { transform: skew(-1deg); }
    100% { transform: skew(0deg); }
}

/* Scrollbar Styling */
::-webkit-scrollbar {
    width: 10px;
    height: 10px;
}

::-webkit-scrollbar-track {
    background: var(--bg-dark);
}

::-webkit-scrollbar-thumb {
    background: var(--dark-green);
    border: 1px solid var(--primary-green);
}

::-webkit-scrollbar-thumb:hover {
    background: var(--primary-green);
}

/* Responsive Design */
@media (max-width: 768px) {
    .navbar-brand {
        font-size: 1.3rem !important;
    }
    
    .container {
        padding: 1rem !important;
    }
}
EOF

# Create JavaScript file
cat > "data/CTFd/themes/$THEME_NAME/static/js/cyber.js" << 'EOF'
// Cyber Theme JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Add random glitch effect
    setInterval(() => {
        const glitchElements = document.querySelectorAll('.glitch');
        glitchElements.forEach(el => {
            if (Math.random() > 0.95) {
                el.style.animation = 'none';
                setTimeout(() => {
                    el.style.animation = '';
                }, 200);
            }
        });
    }, 3000);
    
    // Add terminal-style cursor to form inputs
    const inputs = document.querySelectorAll('.form-control');
    inputs.forEach(input => {
        input.addEventListener('focus', function() {
            this.style.borderColor = 'var(--primary-green)';
        });
        input.addEventListener('blur', function() {
            this.style.borderColor = 'var(--dark-green)';
        });
    });
    
    // Add hover effects to cards
    const cards = document.querySelectorAll('.card, .challenge-button');
    cards.forEach(card => {
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-2px)';
        });
        card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0)';
        });
    });
    
    console.log('%c[CYBER_THEME] Matrix initialized...', 'color: #00ff41; font-family: monospace;');
});
EOF

log "${GREEN}[Step 3] Updating Docker configuration for themes...${NC}"

# Check if themes volume mount already exists
if grep -q "themes:/opt/CTFd/CTFd/themes" docker-compose.yml; then
    log "${YELLOW}Themes volume mount already exists${NC}"
else
    log "${YELLOW}Adding themes volume mount to docker-compose.yml...${NC}"
    
    # Create updated docker-compose.yml with themes volume
    sed '/- \.\/data\/CTFd\/uploads:\/var\/uploads/a\      - ./data/CTFd/themes:/opt/CTFd/CTFd/themes' docker-compose.yml > docker-compose.yml.tmp
    mv docker-compose.yml.tmp docker-compose.yml
fi

log "${GREEN}[Step 4] Setting correct permissions...${NC}"

# Set proper ownership
sudo chown -R $(whoami):$(whoami) "data/CTFd/themes/"
chmod -R 755 "data/CTFd/themes/"

log "${GREEN}[Step 5] Restarting CTFd with new theme...${NC}"

# Restart CTFd to pick up the theme
docker compose restart ctfd

# Wait for restart
log "${YELLOW}Waiting for CTFd to restart...${NC}"
sleep 10

# Check if CTFd is responding
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 --max-time 10 | grep -q "200\|302"; then
    log "${GREEN}✓ CTFd restarted successfully${NC}"
else
    log "${YELLOW}⚠ CTFd may still be starting up${NC}"
fi

log ""
log "${BLUE}========================================${NC}"
log "${GREEN}     Theme Installation Complete!${NC}"
log "${BLUE}========================================${NC}"
log ""
log "${GREEN}The Cyber Theme has been installed successfully!${NC}"
log ""
log "${YELLOW}To activate the theme:${NC}"
log "  1. Login to CTFd admin panel"
log "  2. Go to Admin Panel > Config > Appearance"
log "  3. Select 'cyber-theme' from the theme dropdown"
log "  4. Save settings"
log ""
log "${GREEN}Theme files installed at:${NC}"
log "  📁 data/CTFd/themes/cyber-theme/"
log "  📄 templates/base.html"
log "  🎨 static/css/cyber.css"
log "  ⚡ static/js/cyber.js"
log ""
log "${BLUE}Theme features:${NC}"
log "  ✅ Matrix-style hacker aesthetic"
log "  ✅ Terminal-inspired UI elements"
log "  ✅ Glitch effects and animations"
log "  ✅ Green cyber color scheme"
log "  ✅ Responsive design"
log ""
log "${GREEN}Enjoy your new cyber theme! 🖥️💚${NC}"