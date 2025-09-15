#!/bin/bash

#############################################
# CTFd Theme Override - Last Resort
# Modifies core theme CSS via uploads
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CTFD_DIR="$HOME/CTFd"

# Logging function
log() {
    echo -e "$1"
}

# Header
clear
log "${BLUE}========================================${NC}"
log "${BLUE}     Core Theme Override Method${NC}"
log "${BLUE}========================================${NC}"
echo ""

cd "$CTFD_DIR"

log "${YELLOW}[1] Creating custom CSS override file...${NC}"

# Create a custom CSS file in uploads that we'll inject
mkdir -p "data/CTFd/uploads/css"

cat > "data/CTFd/uploads/css/cyber-override.css" << 'EOF'
/* Cyber Theme Override for CTFd */
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&display=swap');

:root {
    --cyber-green: #00ff41;
    --cyber-green-dark: #00cc33;
    --cyber-dark: #0a0a0a;
    --cyber-card: #1a1a1a;
    --cyber-border: #008f11;
}

* {
    transition: color 0.3s ease, background 0.3s ease, border-color 0.3s ease;
}

body {
    font-family: 'Share Tech Mono', monospace !important;
    background: var(--cyber-dark) !important;
    color: var(--cyber-green) !important;
    background-image: 
        repeating-linear-gradient(
            0deg,
            rgba(0, 255, 65, 0.03),
            rgba(0, 255, 65, 0.03) 1px,
            transparent 1px,
            transparent 2px
        );
}

/* Navigation */
.navbar, nav {
    background: linear-gradient(180deg, var(--cyber-card) 0%, var(--cyber-dark) 100%) !important;
    border-bottom: 2px solid var(--cyber-green) !important;
    box-shadow: 0 0 20px rgba(0, 255, 65, 0.3);
}

.navbar-brand {
    color: var(--cyber-green) !important;
    text-shadow: 0 0 15px var(--cyber-green);
    font-size: 1.5rem;
    letter-spacing: 2px;
    animation: glow 2s ease-in-out infinite alternate;
}

@keyframes glow {
    from { text-shadow: 0 0 10px var(--cyber-green); }
    to { text-shadow: 0 0 20px var(--cyber-green), 0 0 30px var(--cyber-green); }
}

.nav-link, .navbar-nav .nav-link {
    color: var(--cyber-green) !important;
    border: 1px solid transparent;
    margin: 0 5px;
    padding: 5px 15px !important;
}

.nav-link:hover {
    border: 1px solid var(--cyber-green);
    background: rgba(0, 255, 65, 0.1);
    text-shadow: 0 0 5px var(--cyber-green);
}

/* Buttons */
.btn {
    font-family: 'Share Tech Mono', monospace !important;
    text-transform: uppercase;
    letter-spacing: 1px;
    border-radius: 0 !important;
}

.btn-primary, .btn-success {
    background: transparent !important;
    color: var(--cyber-green) !important;
    border: 1px solid var(--cyber-green) !important;
}

.btn-primary:hover, .btn-success:hover {
    background: var(--cyber-green) !important;
    color: var(--cyber-dark) !important;
    box-shadow: 0 0 15px var(--cyber-green);
}

.btn-danger {
    background: transparent !important;
    color: #ff0040 !important;
    border: 1px solid #ff0040 !important;
}

.btn-danger:hover {
    background: #ff0040 !important;
    color: var(--cyber-dark) !important;
}

/* Cards */
.card, .jumbotron, .modal-content {
    background: var(--cyber-card) !important;
    border: 1px solid var(--cyber-border) !important;
    border-radius: 0 !important;
    box-shadow: 0 0 10px rgba(0, 255, 65, 0.1);
}

.card-header, .modal-header {
    background: var(--cyber-dark) !important;
    border-bottom: 1px solid var(--cyber-green) !important;
    color: var(--cyber-green) !important;
}

/* Forms */
input, textarea, select, .form-control {
    background: var(--cyber-dark) !important;
    color: var(--cyber-green) !important;
    border: 1px solid var(--cyber-border) !important;
    border-radius: 0 !important;
}

input:focus, textarea:focus, select:focus, .form-control:focus {
    border-color: var(--cyber-green) !important;
    box-shadow: 0 0 5px var(--cyber-green) !important;
    background: rgba(0, 255, 65, 0.05) !important;
}

/* Tables */
.table {
    color: var(--cyber-green) !important;
}

.table thead th {
    background: var(--cyber-dark) !important;
    color: var(--cyber-green) !important;
    border-color: var(--cyber-green) !important;
    text-transform: uppercase;
    letter-spacing: 1px;
}

.table-striped tbody tr:nth-of-type(odd) {
    background: rgba(0, 255, 65, 0.05) !important;
}

/* Text */
h1, h2, h3, h4, h5, h6 {
    color: var(--cyber-green) !important;
    text-shadow: 0 0 5px var(--cyber-green);
}

.text-muted {
    color: var(--cyber-green-dark) !important;
}

.text-white {
    color: var(--cyber-green) !important;
}

a {
    color: var(--cyber-green) !important;
}

a:hover {
    color: var(--cyber-green) !important;
    text-shadow: 0 0 5px var(--cyber-green);
}

/* Challenges */
.challenge-button {
    background: var(--cyber-card) !important;
    border: 1px solid var(--cyber-border) !important;
    transition: all 0.3s;
}

.challenge-button:hover {
    border-color: var(--cyber-green) !important;
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(0, 255, 65, 0.3);
}

.solved-challenge {
    background: rgba(0, 255, 65, 0.1) !important;
    border-color: var(--cyber-green) !important;
}

/* Scrollbar */
::-webkit-scrollbar {
    width: 10px;
    height: 10px;
}

::-webkit-scrollbar-track {
    background: var(--cyber-dark);
}

::-webkit-scrollbar-thumb {
    background: var(--cyber-border);
    border: 1px solid var(--cyber-green);
}

::-webkit-scrollbar-thumb:hover {
    background: var(--cyber-green);
}

/* Alerts */
.alert {
    border-radius: 0 !important;
    border: 1px solid var(--cyber-green) !important;
    background: rgba(0, 255, 65, 0.1) !important;
    color: var(--cyber-green) !important;
}

.alert-danger {
    border-color: #ff0040 !important;
    background: rgba(255, 0, 64, 0.1) !important;
    color: #ff0040 !important;
}

/* Terminal Effect */
body::before {
    content: '';
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: linear-gradient(0deg, transparent 50%, rgba(0, 255, 65, 0.01) 50%);
    background-size: 100% 4px;
    pointer-events: none;
    z-index: 9999;
    animation: scan 10s linear infinite;
}

@keyframes scan {
    0% { transform: translateY(0); }
    100% { transform: translateY(20px); }
}

/* Make everything cyber! */
.bg-white { background: var(--cyber-card) !important; }
.bg-light { background: var(--cyber-card) !important; }
.bg-dark { background: var(--cyber-dark) !important; }
.text-dark { color: var(--cyber-green) !important; }
EOF

log "${GREEN}✓ Created cyber override CSS${NC}"

log "${YELLOW}[2] Injecting CSS into CTFd...${NC}"

# Create a JavaScript file that will inject our CSS
cat > "data/CTFd/uploads/css/cyber-inject.js" << 'EOF'
// Cyber Theme Injector
(function() {
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.type = 'text/css';
    link.href = '/files/css/cyber-override.css?v=' + Date.now();
    document.head.appendChild(link);
    console.log('[CYBER THEME] Override CSS injected');
})();
EOF

log "${YELLOW}[3] Creating auto-loader in uploads...${NC}"

# Try to inject via the uploads directory
docker compose exec -T ctfd bash << 'SCRIPT'
# Check if we can access CTFd static files
if [ -d /opt/CTFd/CTFd/themes/core/static/css ]; then
    echo "Core theme directory found"
    
    # Try to append to existing CSS
    if [ -w /opt/CTFd/CTFd/themes/core/static/css ]; then
        echo "/* Cyber Theme Override */" >> /opt/CTFd/CTFd/themes/core/static/css/main.css 2>/dev/null && \
        echo "@import url('/files/css/cyber-override.css');" >> /opt/CTFd/CTFd/themes/core/static/css/main.css 2>/dev/null && \
        echo "✓ Injected into core CSS" || echo "✗ Cannot modify core CSS"
    else
        echo "✗ Core CSS not writable"
    fi
fi

# Alternative: Check if we can access templates
if [ -d /opt/CTFd/CTFd/themes/core/templates ]; then
    echo "Core templates found but likely read-only"
fi

echo ""
echo "CSS Override file is available at: /files/css/cyber-override.css"
SCRIPT

log "${YELLOW}[4] Restarting CTFd...${NC}"
docker compose restart ctfd
sleep 10

log ""
log "${BLUE}========================================${NC}"
log "${GREEN}     CSS Override Installed${NC}"
log "${BLUE}========================================${NC}"
log ""
log "${YELLOW}The cyber theme CSS has been created.${NC}"
log ""
log "If the theme doesn't auto-apply, you can manually add it:"
log ""
log "${GREEN}Option 1: Browser Developer Console${NC}"
log "  1. Open CTFd in your browser"
log "  2. Open Developer Console (F12)"
log "  3. Paste this code:"
log ""
cat << 'BROWSERCODE'
var link = document.createElement('link');
link.rel = 'stylesheet';
link.href = '/files/css/cyber-override.css';
document.head.appendChild(link);
BROWSERCODE
log ""
log "${GREEN}Option 2: Custom JavaScript in CTFd Admin${NC}"
log "  1. Admin Panel → Config → Settings → Theme Settings"
log "  2. Add to Custom JS field:"
log "  <link rel='stylesheet' href='/files/css/cyber-override.css'>"
log ""
log "${YELLOW}The theme CSS is stored at:${NC}"
log "  data/CTFd/uploads/css/cyber-override.css"

# Try to auto-apply the theme
log ""
log "${YELLOW}Attempting to auto-apply theme...${NC}"
docker compose exec -T ctfd python3 << 'AUTO_APPLY' 2>/dev/null
try:
    from CTFd import create_app
    from CTFd.models import Configs
    from CTFd.utils import set_config
    
    app = create_app()
    with app.app_context():
        # Add the cyber theme CSS to the custom CSS config
        custom_css = '@import url("/files/css/cyber-override.css");'
        set_config('css', custom_css)
        print("✓ Cyber theme successfully auto-applied!")
        print("Refresh your browser to see the new theme")
except Exception as e:
    print(f"Could not auto-apply: {e}")
    print("Please apply manually via Admin Panel")
AUTO_APPLY