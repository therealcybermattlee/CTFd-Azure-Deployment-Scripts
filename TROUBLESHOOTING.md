# Troubleshooting Guide

## Common Issues and Solutions

### 🐳 Docker Issues

#### Docker fails to start: "Failed to start Docker Application Container Engine"

**Symptoms:**
```
Job for docker.service failed because the control process exited with error code.
```

**Solutions:**

1. **Check if docker group exists:**
```bash
sudo groupadd -f docker
sudo usermod -aG docker $USER
sudo systemctl daemon-reload
sudo systemctl restart docker
```

2. **Fix kernel modules:**
```bash
sudo modprobe overlay
sudo modprobe br_netfilter
echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/docker.conf
sudo systemctl restart docker
```

3. **Fix Docker daemon config:**
```bash
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

#### Docker socket permission denied

**Solution:**
```bash
sudo chmod 666 /var/run/docker.sock
# OR better:
sudo usermod -aG docker $USER
newgrp docker
```

### 🗄️ Database Issues

#### "Access denied for user 'ctfd'@'172.x.x.x'"

**This means database credentials are mismatched.**

**Solution:**
```bash
cd ~/CTFd
docker compose down -v
sudo rm -rf data/mysql/* data/redis/*
docker compose up -d
docker compose logs -f
```

#### Database container keeps restarting

**Check logs:**
```bash
docker compose logs db --tail=50
```

**Common fixes:**
```bash
# Check disk space
df -h

# Clear and restart
docker compose down
docker volume prune -f
docker compose up -d
```

### 🌐 Nginx Issues

#### nginx: [emerg] open() "/etc/nginx/nginx.conf" failed

**The nginx.conf file is missing.**

**Solution:**
```bash
sudo mkdir -p /etc/nginx
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
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
    access_log /var/log/nginx/access.log;
    gzip on;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
sudo nginx -t
sudo systemctl restart nginx
```

#### Port 80 already in use

**Find what's using port 80:**
```bash
sudo lsof -i :80
# OR
sudo netstat -tlnp | grep :80
```

**Stop conflicting service:**
```bash
sudo systemctl stop apache2  # If Apache is running
# OR just change nginx to different port
```

### 🔒 SSL/Certificate Issues

#### DNS not pointing to server

**Check current DNS:**
```bash
# Your server IP
curl -s ifconfig.me

# Where domain points to
dig +short your-domain.com
nslookup your-domain.com
```

**Fix:** Update A record in your DNS provider to point to your server IP

#### Certbot fails with "Challenge failed"

**Common causes:**
1. **Ports not open in Azure NSG** - Open ports 80 and 443
2. **DNS not propagated** - Wait 5-10 minutes after DNS change
3. **Cloudflare proxy enabled** - Temporarily disable proxy (orange cloud → gray cloud)

**Manual SSL setup:**
```bash
sudo certbot certonly --standalone -d your-domain.com
# Then manually configure nginx
```

### 🔥 CTFd Won't Start

#### CTFd container exits immediately

**Check logs:**
```bash
docker compose logs ctfd --tail=100
```

**Common fixes:**

1. **Port conflict:**
```bash
# Check if port 8000 is in use
sudo lsof -i :8000
```

2. **Database connection:**
```bash
# Verify database is running
docker compose ps
docker compose exec db mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;"
```

3. **Restart everything:**
```bash
cd ~/CTFd
docker compose down
docker compose up -d
```

### 🔧 Azure-Specific Issues

#### Unattended upgrades blocking apt

**Wait for it to finish or stop it:**
```bash
# Check if running
ps aux | grep -i apt

# Wait for completion
sudo tail -f /var/log/unattended-upgrades/unattended-upgrades.log

# Or force stop (not recommended)
sudo killall apt apt-get
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
sudo rm /var/lib/dpkg/lock*
sudo dpkg --configure -a
```

#### Network Security Group (NSG) Issues

**Required rules in Azure Portal:**

| Priority | Name | Port | Protocol | Source | Destination | Action |
|----------|------|------|----------|---------|-------------|---------|
| 100 | AllowHTTP | 80 | TCP | Any | Any | Allow |
| 110 | AllowHTTPS | 443 | TCP | Any | Any | Allow |
| 120 | AllowSSH | 22 | TCP | Your IP | Any | Allow |

### 📝 Installation Logs

**Always check the installation log:**
```bash
ls -la /tmp/ctfd-install-*.log
tail -100 /tmp/ctfd-install-*.log
```

### 🔄 Complete Reset

**If nothing works, complete reset:**
```bash
# 1. Uninstall everything
sudo ./uninstall-ctfd.sh
# Choose option 3 (remove everything)

# 2. Reboot
sudo reboot

# 3. Fresh install
sudo ./ctfd-install-clean.sh
```

### 🆘 Getting Help

When asking for help, provide:

1. **System info:**
```bash
uname -a
lsb_release -a
docker --version
docker compose version
```

2. **Error messages:**
```bash
# Installation log
cat /tmp/ctfd-install-*.log | tail -200

# Docker logs
docker compose logs --tail=50

# System logs
sudo journalctl -xeu docker.service -n 50
```

3. **Current state:**
```bash
docker compose ps
docker ps -a
sudo netstat -tlnp
df -h
free -h
```

### 📊 Health Check Script

**Run the health check:**
```bash
cd ~/CTFd
./health-ctfd.sh
```

This will show:
- Container status
- Service health
- Database connectivity
- Redis connectivity
- Resource usage

### 🐛 Debug Mode

**Run installation in debug mode:**
```bash
sudo bash -x ./install-ctfd.sh 2>&1 | tee debug.log
```

This creates a detailed trace of everything the script does.