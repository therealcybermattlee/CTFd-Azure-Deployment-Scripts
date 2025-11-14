# Contributing to CTFd Azure Deployment Scripts

First off, thank you for considering contributing to this project! 🎉

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code:
- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive criticism
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**When reporting bugs, include:**
- Azure VM specifications (Ubuntu version, size)
- Docker version (`docker --version`)
- Complete error messages
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs from `/tmp/ctfd-install-*.log`

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:
- Clear use case description
- Step-by-step description of the suggested enhancement
- Examples of how it would work
- Why this enhancement would be useful to most users

### Pull Requests

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Make your changes
4. Test thoroughly on an Azure VM
5. Commit with clear messages (`git commit -m 'Add AmazingFeature'`)
6. Push to your branch (`git push origin feature/AmazingFeature`)
7. Open a Pull Request

## Development Guidelines

### Script Standards

- **Bash version**: Target Bash 4.0+ compatibility
- **Error handling**: Always use `set -e` and proper error checking
- **Logging**: Use the `log()` function for consistent output
- **Colors**: Use defined color variables (RED, GREEN, YELLOW, BLUE, NC)
- **Functions**: Create reusable functions for complex operations
- **Comments**: Document complex logic and Azure-specific fixes

### Testing Requirements

Before submitting PRs, test on:
1. Fresh Azure Ubuntu 22.04 LTS VM
2. Fresh Azure Ubuntu 24.04 LTS VM
3. VM with existing Docker installation
4. VM after running uninstall script

### Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit first line to 72 characters
- Reference issues and pull requests

Example:
```
Fix Docker group creation on Azure VMs

- Add check for existing docker group
- Create group before Docker installation
- Handle systemd daemon reload properly

Fixes #123
```

### Documentation

- Update README.md if adding new features
- Document any new Azure-specific requirements
- Add troubleshooting steps for new error scenarios
- Include examples for new functionality

## Testing Checklist

- [ ] Clean installation works on fresh VM
- [ ] Upgrade from previous installation works
- [ ] Uninstall removes all components correctly
- [ ] Docker starts properly after reboot
- [ ] SSL certificate obtains successfully
- [ ] All management scripts function correctly
- [ ] Error handling works for common failures

## Project Structure

```
ctfd-install-clean.sh # Main installation script
├── Functions:
│   ├── command_exists()
│   ├── generate_password()
│   ├── wait_for_apt()
│   ├── fix_docker_azure()
│   ├── install_docker()
│   ├── fix_and_install_nginx()
│   └── install_dependencies()
├── Steps:
│   ├── 1. Docker check/install
│   ├── 2. Dependencies
│   ├── 3. Directory setup
│   ├── 4. Credentials
│   ├── 5. Docker Compose
│   ├── 6. Container startup
│   ├── 7. Nginx config
│   └── 8. SSL setup
└── Management scripts creation
```

## Style Guide

### Variables
```bash
# Good
DOMAIN="ctf.example.com"
INSTALL_DIR="$HOME/CTFd"

# Bad
domain=ctf.example.com
installdir=$HOME/CTFd
```

### Functions
```bash
# Good
install_docker() {
    log "${GREEN}Installing Docker...${NC}"
    # Implementation
}

# Bad
function installDocker {
    echo "Installing Docker..."
    # Implementation
}
```

### Error Handling
```bash
# Good
if ! command_exists docker; then
    log "${RED}Docker not found${NC}"
    exit 1
fi

# Bad
command_exists docker || echo "Docker not found"
```

## Questions?

Feel free to open an issue for:
- Clarification on code
- Discussion about implementations
- Help with testing

## Recognition

Contributors will be recognized in:
- README.md Contributors section
- Release notes
- Project documentation

Thank you for contributing! 🚀