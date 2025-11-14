# CTFd Azure Deployment Scripts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CTFd](https://img.shields.io/badge/CTFd-Latest-blue)](https://github.com/CTFd/CTFd)
[![Docker](https://img.shields.io/badge/Docker-Required-blue)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2B-orange)](https://ubuntu.com/)

Production-ready deployment scripts for CTFd on Azure Ubuntu VMs with automated SSL, Docker management, and comprehensive error handling.

## 🚀 Features

- **One-Command Installation** - Fully automated CTFd deployment
- **Azure Optimized** - Handles Azure VM-specific Docker and networking issues
- **SSL/TLS Automation** - Let's Encrypt integration with auto-renewal
- **Error Recovery** - Intelligent error handling and automatic fixes
- **Database Management** - Automatic credential generation and recovery
- **Complete Lifecycle** - Install, uninstall, backup, and maintenance scripts
- **Production Ready** - Nginx reverse proxy, security hardening, and monitoring

## 📋 Prerequisites

- Azure Ubuntu VM (22.04 LTS or newer)
- Minimum 2 vCPUs and 4GB RAM
- Domain name pointing to your VM's public IP
- Ports 80, 443, and 22 open in Azure NSG

## 🔧 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/therealcybermattlee/ctfd-azure-deploy.git
cd ctfd-azure-deploy
```

### 2. Configure Your Domain
Edit `ctfd-install-clean.sh` and update:
```bash
DOMAIN="your-domain.com"  # Replace with your actual domain
EMAIL="admin@your-domain.com"  # For Let's Encrypt notifications
```

### 3. Run Installation
```bash
chmod +x ctfd-install-clean.sh
sudo ./ctfd-install-clean.sh
```

The script will:
- Install and configure Docker
- Set up CTFd with MariaDB and Redis
- Configure Nginx as reverse proxy
- Obtain SSL certificate from Let's Encrypt
- Create management scripts

## 📁 Repository Structure

```
ctfd-azure-deploy/
├── ctfd-install-clean.sh    # Main installation script
├── uninstall-ctfd.sh        # Complete uninstall script
├── README.md            # This file
├── LICENSE              # MIT License
├── CONTRIBUTING.md      # Contribution guidelines
├── docs/
│   ├── TROUBLESHOOTING.md
│   ├── AZURE-SETUP.md
│   └── SSL-SETUP.md
└── .github/
    └── ISSUE_TEMPLATE/
        ├── bug_report.md
        └── feature_request.md
```

## 🛠️ Management Scripts

After installation, the following scripts are created in `~/CTFd/`:

| Script | Purpose |
|--------|---------|
| `start-ctfd.sh` | Start CTFd containers |
| `stop-ctfd.sh` | Stop CTFd containers |
| `restart-ctfd.sh` | Restart CTFd containers |
| `logs-ctfd.sh` | View real-time logs |
| `backup-ctfd.sh` | Create backup |
| `health-ctfd.sh` | Check service health |
| `fix-ctfd.sh` | Auto-fix common issues |

## 🔐 Security Features

- Automatic secure password generation
- SSL/TLS with Let's Encrypt
- Nginx security headers
- Docker security best practices
- Automated backups (daily at 2 AM)
- Isolated Docker networks

## 🔄 Uninstallation

Three uninstall modes available:
```bash
sudo ./uninstall-ctfd.sh
```

1. **Remove CTFd only** - Keeps Docker installed
2. **Remove CTFd and containers** - Keeps Docker installation
3. **Complete removal** - Removes everything including Docker

## 🐛 Troubleshooting

### Common Issues

#### Docker Won't Start
```bash
sudo groupadd -f docker
sudo usermod -aG docker $USER
sudo systemctl restart docker
```

#### Database Connection Failed
```bash
cd ~/CTFd
docker compose down -v
sudo rm -rf data/mysql/*
docker compose up -d
```

#### SSL Certificate Issues
Ensure DNS is properly configured:
```bash
# Check DNS
dig +short your-domain.com

# Manual SSL setup
sudo certbot --nginx -d your-domain.com
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed solutions.

## 📊 System Requirements

### Minimum
- 2 vCPUs
- 4GB RAM
- 20GB Storage
- Ubuntu 22.04 LTS

### Recommended
- 4 vCPUs
- 8GB RAM
- 50GB Storage
- Ubuntu 22.04/24.04 LTS

## 🌐 Azure Network Security Group

Required inbound rules:
| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH Access |
| 80 | TCP | HTTP Traffic |
| 443 | TCP | HTTPS Traffic |

## 📝 Environment Variables

The installation creates `.env` with:
- `SECRET_KEY` - CTFd secret key
- `MYSQL_ROOT_PASSWORD` - Database root password
- `DB_PASSWORD` - CTFd database password
- `DOMAIN` - Your domain name

**⚠️ Keep `.env` secure and never commit to git!**

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [CTFd](https://github.com/CTFd/CTFd) - The amazing CTF platform
- [Docker](https://www.docker.com/) - Container platform
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/therealcybermattlee/ctfd-azure-deploy/issues)
- **Discussions**: [GitHub Discussions](https://github.com/therealcybermattlee/ctfd-azure-deploy/discussions)

## 🔄 Version History

- **v1.0.0** (2025-09-02)
  - Initial release
  - Full Azure VM support
  - Automated SSL setup
  - Complete error handling

## 🏗️ Roadmap

- [ ] Support for multiple CTFd instances
- [ ] Kubernetes deployment option
- [ ] AWS/GCP support
- [ ] Automated challenge deployment
- [ ] Monitoring dashboard integration

---

**Made with ❤️ for the CTF community**
