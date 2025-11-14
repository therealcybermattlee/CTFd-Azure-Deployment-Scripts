# CTFd Azure Deployment - Claude AI Assistant Notes

## Project Overview
This repository contains scripts for deploying CTFd (Capture The Flag platform) on Azure Ubuntu VMs with Docker, nginx reverse proxy, and SSL/TLS configuration.

## Key Architecture
- **CTFd**: Running in Docker container on port 8000
- **MariaDB**: Database container
- **Redis**: Cache container
- **Nginx**: Reverse proxy with SSL termination (ports 80/443)
- **Docker Compose**: Orchestration of all services
- **Plugins**: Mounted individually to avoid overwriting built-in plugins
- **Themes**: Mounted individually to avoid overwriting built-in themes

## Critical Docker Container Insights

### ⚠️ IMPORTANT: Docker Container File System is READ-ONLY
The CTFd Docker container has a read-only file system for `/opt/CTFd/`. This means:
- **CANNOT** directly modify files in `/opt/CTFd/CTFd/themes/`
- **CANNOT** use volume mounts for themes (causes template override issues)
- **CANNOT** use `docker cp` to copy files into protected directories

### ✅ WORKING APPROACH: Use Uploads Directory
The **ONLY** reliable way to add custom content to CTFd containers:
1. Use the `/var/uploads` directory (mapped to `data/CTFd/uploads/`)
2. Place CSS, JS, and other assets in `data/CTFd/uploads/`
3. Access files via `/files/` URL path in CTFd
4. Apply CSS through Admin Panel or Custom CSS settings

### Theme Installation Best Practice
```bash
# Create CSS in uploads directory (writable)
mkdir -p data/CTFd/uploads/css
cat > data/CTFd/uploads/css/custom-theme.css << 'EOF'
/* Custom theme CSS */
EOF

# Access in CTFd at: /files/css/custom-theme.css
```

## Common Issues and Solutions

### 500 Internal Server Error After Theme Mount
**Cause**: Volume mounting themes directory overrides CTFd's built-in templates
**Solution**: Remove theme volume mount from docker-compose.yml:
```bash
sed -i '/\/opt\/CTFd\/CTFd\/themes/d' docker-compose.yml
docker compose down && docker compose up -d
```

### Database Initialization Errors
**Cause**: CTFd starts before database is ready
**Solution**: Sequential startup with health checks (implemented in ctfd-install-clean.sh)

### Permission Errors in Container
**Cause**: Container runs as user 1001, file system is read-only
**Solution**:
1. Use uploads directory for custom content
2. Set proper permissions: `chown -R 1001:1001 data/CTFd/uploads`
3. Scripts now automatically set correct permissions during installation

## Script Purposes

### Main Installation
- `ctfd-install-clean.sh`: Complete CTFd installation with all fixes and plugin support

### Plugin Management
- `install-ctfd-plugins.sh`: Standalone plugin installation for existing deployments
- Each plugin is mounted individually as `/opt/CTFd/CTFd/plugins/[plugin_name]`
- This avoids overwriting CTFd's built-in plugins

### Theme Management
- `install-cyber-theme.sh`: Installs cyber theme CSS via uploads directory
- `emergency-fix-500.sh`: Fixes 500 errors caused by theme mounts
- **New approach**: Individual theme mounting prevents 500 errors

### Utilities
- `install-theme-via-uploads.sh`: Alternative theme installation method
- `fix-502-gateway.sh`: Troubleshoots nginx proxy issues
- `fix-ctfd-crashloop.sh`: Resolves container crash loops

## Testing Commands

### Check CTFd Health
```bash
docker compose ps
docker compose logs ctfd --tail=50
curl -I http://localhost:8000
```

### Fix Permission Issues
```bash
# If uploads directory has permission errors:
sudo chown -R 1001:1001 data/CTFd/uploads
sudo chmod -R 755 data/CTFd/uploads

# For all CTFd directories:
sudo chown -R 1001:1001 data/CTFd/
sudo chmod -R 755 data/CTFd/
```

### Verify Theme Files
```bash
docker compose exec ctfd ls -la /var/uploads/css/
```

### Apply Custom CSS in Admin Panel
1. Login to CTFd admin
2. Go to Admin Panel → Config → Settings
3. Add to Custom CSS field: `@import url('/files/css/cyber-theme.css');`

## Azure-Specific Notes
- Ensure NSG allows ports 80, 443
- Use Cloudflare in DNS-only mode during Let's Encrypt setup
- Container startup order matters on Azure VMs with limited resources

## Key Learnings
1. **Never mount volumes to `/opt/CTFd/CTFd/themes/`** - it breaks CTFd (individual or entire directory)
2. **Mount plugins individually** as `/opt/CTFd/CTFd/plugins/[plugin_name]` to avoid overwriting built-in plugins
3. **Use uploads directory for themes** - mounting themes causes container instability
3. **Always use uploads directory** for custom content
4. **Set proper permissions** - CTFd runs as user 1001, directories need `chown 1001:1001`
5. **Container file system is read-only** - work within these constraints
6. **Sequential startup** prevents database initialization issues
7. **Test locally first** with `curl http://localhost:8000`

## Contact
For issues or questions about this deployment, check:
- Container logs: `docker compose logs ctfd`
- Nginx logs: `sudo journalctl -u nginx`
- System resources: `docker stats`

---
*Last Updated: 2025-01-15*
*Maintained for: CTFd Azure Deployments*