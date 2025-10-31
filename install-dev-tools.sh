#!/usr/bin/env bash
set -euo pipefail

# install-dev-tools.sh
# Installs Docker CE, nvm (and Node LTS), Zsh + Oh My Zsh, zsh-autosuggestions and zsh-syntax-highlighting.
# Intended for Ubuntu (WSL) — run inside WSL/Ubuntu as a regular user with sudo available.

PROGNAME=$(basename "$0")
echo "==> $PROGNAME: Starting setup"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found. Install it and re-run." >&2
    exit 1
  fi
}

is_ubuntu() {
  [ -f /etc/os-release ] && grep -qi 'ubuntu' /etc/os-release || return 1
}

if ! is_ubuntu; then
  echo "This script is designed for Ubuntu. Detected:"
  cat /etc/os-release || true
  echo "Proceeding may fail. Abort now if this is not Ubuntu." >&2
fi

USER_NAME=${SUDO_USER:-$USER}
HOME_DIR=$(eval echo "~$USER_NAME")

echo "Running as user: $USER_NAME (home: $HOME_DIR)"

sudo_check() {
  if [ "$EUID" -eq 0 ]; then
    echo "Don't run this script as root. Run it as your normal user (it will use sudo internally)." >&2
    exit 1
  fi
}

sudo_check

apt_update() {
  echo "==> Updating apt repositories..."
  sudo apt-get update -y
}

install_packages() {
  echo "==> Installing base packages"
  sudo apt-get install -y ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https \
    build-essential git wget unzip
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "Docker already installed — skipping Docker installation"
    return
  fi

  echo "==> Installing Docker Engine (Docker CE)"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  echo "==> Adding $USER_NAME to docker group"
  sudo groupadd -f docker
  sudo usermod -aG docker "$USER_NAME" || true

  echo "Docker installed. You may need to log out and log back in (or run 'newgrp docker') to use docker as a non-root user."
}

install_nvm_and_node() {
  if [ -d "$HOME_DIR/.nvm" ]; then
    echo "nvm already present in $HOME_DIR/.nvm — skipping nvm install"
  else
    echo "==> Installing nvm (Node Version Manager)"
    # Install nvm using install script
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
  fi

  # Ensure nvm is loaded in this script for immediate use
  export NVM_DIR="$HOME_DIR/.nvm"
  # shellcheck disable=SC1090
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  echo "==> Installing latest LTS Node via nvm"
  nvm install --lts || true
  nvm alias default 'lts/*' || true
}

install_zsh_and_oh_my_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    echo "Zsh already installed — skipping zsh install"
  else
    echo "==> Installing zsh"
    sudo apt-get install -y zsh
  fi

  ZSH_DIR="$HOME_DIR/.oh-my-zsh"
  if [ -d "$ZSH_DIR" ]; then
    echo "Oh My Zsh already installed — skipping"
  else
    echo "==> Installing Oh My Zsh (non-interactive)"
    # Use official installer but avoid chsh/run zsh during the script
    export RUNZSH=no
    export CHSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  # Install plugins
  ZSH_CUSTOM=${ZSH_CUSTOM:-"$ZSH_DIR/custom"}
  echo "==> Installing zsh-autosuggestions and zsh-syntax-highlighting"
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi

  # Configure .zshrc (idempotent edits)
  ZSHRC="$HOME_DIR/.zshrc"
  echo "==> Configuring $ZSHRC"

  # Ensure theme is set (but don't overwrite if user changed it)
  if ! grep -q "^ZSH_THEME=" "$ZSHRC" 2>/dev/null; then
    echo "ZSH_THEME=\"robbyrussell\"" >> "$ZSHRC"
  fi

  # Add nvm source lines to .zshrc if missing
  if ! grep -q "NVM_DIR" "$ZSHRC" 2>/dev/null; then
    cat >> "$ZSHRC" <<'EOF'
# Load nvm (installed by nvm installer)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
  fi

  # Ensure plugins line contains recommended plugins
  if grep -q "^plugins=" "$ZSHRC" 2>/dev/null; then
    # Add plugins if missing
    plugins_line=$(grep "^plugins=" "$ZSHRC" | head -n1)
    # remove surrounding 'plugins=(' and ')'
    current=$(echo "$plugins_line" | sed -E "s/^plugins=\(?(.*)\)?/\1/;s/[()\"]//g")
    for p in git docker docker-compose npm nvm zsh-autosuggestions zsh-syntax-highlighting; do
      if ! echo " $current " | grep -q " $p "; then
        current="$current $p"
      fi
    done
    # replace line
    sed -i "s/^plugins=.*/plugins=( $current )/" "$ZSHRC"
  else
    echo "plugins=(git docker docker-compose npm nvm zsh-autosuggestions zsh-syntax-highlighting)" >> "$ZSHRC"
  fi

  # Ensure zsh-syntax-highlighting is sourced last
  if ! tail -n 20 "$ZSHRC" | grep -q "zsh-syntax-highlighting"; then
    echo "# Source zsh-syntax-highlighting (must be last)" >> "$ZSHRC"
    echo "source $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> "$ZSHRC"
  fi

  echo "Zsh + Oh My Zsh configured. To start using Zsh, either run 'zsh' or make it your default shell with 'chsh -s $(command -v zsh)'."
}

post_install_notes() {
  echo
  echo "==> Post-install notes"
  echo "- You probably need to log out and log back in (or run: newgrp docker) for docker group membership to take effect."
  echo "- If you're running WSL without systemd, Docker may need a separate Docker Desktop or a background docker daemon. See: https://docs.docker.com/desktop/windows/wsl/"
  echo "- Oh My Zsh configuration updated in $HOME_DIR/.zshrc. zsh-syntax-highlighting is sourced at the end of the file."
}

main() {
  apt_update
  install_packages
  install_docker
  install_nvm_and_node
  install_zsh_and_oh_my_zsh
  post_install_notes
  echo "==> Done."
}

main "$@"
