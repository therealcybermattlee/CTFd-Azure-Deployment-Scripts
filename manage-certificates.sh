#!/bin/bash

#############################################
# Let's Encrypt Certificate Management Script
# Handles certificate operations without hitting rate limits
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run with sudo${NC}"
   exit 1
fi

# Function to check certificate status
check_certificate() {
    local domain="$1"
    local cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
    
    echo -e "${BLUE}=== Certificate Status for $domain ===${NC}"
    
    if [ ! -f "$cert_path" ]; then
        echo -e "${RED}✗ No certificate found${NC}"
        return 1
    fi
    
    # Get certificate details
    local issuer=$(openssl x509 -in "$cert_path" -noout -issuer 2>/dev/null | grep -oP 'CN=\K[^/]*' || echo "Unknown")
    local subject=$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null | grep -oP 'CN=\K[^/]*' || echo "Unknown")
    local not_after=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)
    
    echo -e "${GREEN}✓ Certificate found${NC}"
    echo -e "  Issuer: $issuer"
    echo -e "  Domain: $subject"
    echo -e "  Expires: $not_after"
    
    # Check if expired
    if ! openssl x509 -checkend 0 -noout -in "$cert_path" 2>/dev/null; then
        echo -e "${RED}✗ Certificate is EXPIRED${NC}"
        return 1
    fi
    
    # Check if expiring soon
    if ! openssl x509 -checkend 2592000 -noout -in "$cert_path" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Certificate expires within 30 days${NC}"
    else
        echo -e "${GREEN}✓ Certificate is valid${NC}"
    fi
    
    return 0
}

# Function to list all certificates
list_certificates() {
    echo -e "${BLUE}=== All Let's Encrypt Certificates ===${NC}"
    
    if [ -d "/etc/letsencrypt/live" ]; then
        for cert_dir in /etc/letsencrypt/live/*/; do
            if [ -d "$cert_dir" ]; then
                domain=$(basename "$cert_dir")
                if [ "$domain" != "README" ]; then
                    echo ""
                    check_certificate "$domain"
                fi
            fi
        done
    else
        echo -e "${YELLOW}No certificates directory found${NC}"
    fi
}

# Function to backup certificates
backup_certificates() {
    local domain="$1"
    local backup_dir="/root/letsencrypt-backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    mkdir -p "$backup_dir"
    
    if [ -z "$domain" ]; then
        # Backup all certificates
        echo -e "${BLUE}Backing up all certificates...${NC}"
        tar -czf "$backup_dir/all-certs-$timestamp.tar.gz" -C / etc/letsencrypt 2>/dev/null
        echo -e "${GREEN}✓ Backup saved to: $backup_dir/all-certs-$timestamp.tar.gz${NC}"
    else
        # Backup specific domain
        if [ -d "/etc/letsencrypt/live/$domain" ]; then
            echo -e "${BLUE}Backing up certificate for $domain...${NC}"
            tar -czf "$backup_dir/$domain-$timestamp.tar.gz" \
                "/etc/letsencrypt/live/$domain" \
                "/etc/letsencrypt/archive/$domain" \
                "/etc/letsencrypt/renewal/$domain.conf" 2>/dev/null
            echo -e "${GREEN}✓ Backup saved to: $backup_dir/$domain-$timestamp.tar.gz${NC}"
        else
            echo -e "${RED}No certificate found for $domain${NC}"
        fi
    fi
}

# Function to check rate limit status
check_rate_limits() {
    local domain="$1"
    
    echo -e "${BLUE}=== Let's Encrypt Rate Limit Information ===${NC}"
    echo -e "${YELLOW}Current limits:${NC}"
    echo "  • 50 certificates per registered domain per week"
    echo "  • 5 duplicate certificates per week"
    echo "  • 5 failed authorizations per hour"
    echo "  • 300 new orders per 3 hours"
    echo ""
    
    if [ ! -z "$domain" ]; then
        echo -e "${BLUE}Checking recent certificate requests for $domain...${NC}"
        
        # Check certificate transparency logs (requires internet)
        echo -e "${YELLOW}Fetching certificate transparency data...${NC}"
        local ct_data=$(curl -s "https://crt.sh/?q=$domain&output=json" 2>/dev/null | head -20)
        
        if [ ! -z "$ct_data" ]; then
            echo -e "${GREEN}Recent certificates issued (from CT logs):${NC}"
            echo "$ct_data" | python3 -m json.tool 2>/dev/null | grep -E '"not_before"|"issuer_name"' | head -10 || echo "Unable to parse CT data"
        else
            echo -e "${YELLOW}Unable to fetch certificate transparency data${NC}"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Rate limit recommendations:${NC}"
    echo "  • Reuse existing certificates when possible"
    echo "  • Use staging environment for testing"
    echo "  • Wait at least 1 week between duplicate cert requests"
    echo "  • Consider using wildcard certificates for subdomains"
}

# Function to renew certificates
renew_certificates() {
    echo -e "${BLUE}=== Certificate Renewal ===${NC}"
    
    # Check current certificates
    echo -e "${YELLOW}Checking certificates for renewal...${NC}"
    certbot renew --dry-run
    
    echo ""
    read -p "$(echo -e "${YELLOW}Proceed with actual renewal? [y/N]:${NC} ") " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        certbot renew
        
        # Reload nginx if running
        if systemctl is-active nginx >/dev/null 2>&1; then
            systemctl reload nginx
            echo -e "${GREEN}✓ Nginx reloaded${NC}"
        fi
    else
        echo -e "${YELLOW}Renewal cancelled${NC}"
    fi
}

# Main menu
main() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Let's Encrypt Certificate Manager${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Options:"
    echo "  1) Check certificate status (specific domain)"
    echo "  2) List all certificates"
    echo "  3) Backup certificates"
    echo "  4) Check rate limit information"
    echo "  5) Renew certificates"
    echo "  6) Force reuse existing certificate (for reinstalls)"
    echo "  7) Exit"
    echo ""
    
    read -p "$(echo -e "${YELLOW}Select option [1-7]:${NC} ") " choice
    
    case $choice in
        1)
            read -p "Enter domain: " domain
            check_certificate "$domain"
            ;;
        2)
            list_certificates
            ;;
        3)
            echo "Backup options:"
            echo "  1) Backup all certificates"
            echo "  2) Backup specific domain"
            read -p "Select [1-2]: " backup_choice
            if [ "$backup_choice" == "2" ]; then
                read -p "Enter domain: " domain
                backup_certificates "$domain"
            else
                backup_certificates
            fi
            ;;
        4)
            read -p "Enter domain (optional): " domain
            check_rate_limits "$domain"
            ;;
        5)
            renew_certificates
            ;;
        6)
            echo -e "${YELLOW}This option helps you reuse existing certificates during CTFd reinstalls${NC}"
            read -p "Enter domain: " domain
            if check_certificate "$domain"; then
                echo ""
                echo -e "${GREEN}Certificate is valid and can be reused!${NC}"
                echo -e "${YELLOW}The install script will automatically detect and use this certificate.${NC}"
            else
                echo -e "${RED}Certificate needs renewal or doesn't exist.${NC}"
            fi
            ;;
        7)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    main
}

# Run main menu
main