# Automated developer environment setup (WSL/Ubuntu)

This repository contains a single script to install common developer tools inside WSL/Ubuntu: Docker (Engine), nvm + Node LTS, Zsh + Oh My Zsh with autocompletion and syntax highlighting.

Files
- `install-dev-tools.sh` — Bash script to perform the installations and idempotent configuration.

Quick start (run inside WSL/Ubuntu)

1. Open your WSL/Ubuntu shell.
2. Make the script executable and run it:

```bash
chmod +x ./install-dev-tools.sh
./install-dev-tools.sh
```

Notes and caveats
- The script must be run as your normal user (it uses sudo internally). Do not run as root.
- After Docker installation you may need to log out and log back in (or run `newgrp docker`) to apply the docker group membership.
- On WSL, Docker Engine may require Docker Desktop (Windows) or a background daemon depending on your setup. See Docker's WSL documentation for details.
- The script installs Oh My Zsh non-interactively (it will not change your default shell). To switch to zsh as default: `chsh -s $(which zsh)`.
- `zsh-syntax-highlighting` is appended to the end of your `.zshrc` (it must be sourced last).
