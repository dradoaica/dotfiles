#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
export DEBIAN_FRONTEND=noninteractive

# Install pre-requisite packages
sudo apt-get update
sudo apt-get install -y wget curl software-properties-common stow

# Add APT repositories
source /etc/os-release
sudo add-apt-repository -y ppa:agornostal/ulauncher
sudo add-apt-repository -y ppa:openrazer/stable
sudo add-apt-repository -y ppa:polychromatic/stable
sudo add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
sudo add-apt-repository -y ppa:s4solutionsllc/nexis
sudo add-apt-repository -y ppa:solaar-unifying/stable
sudo install -m 0755 -d /usr/share/keyrings
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/google-chrome.gpg
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
curl -fsSL "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb" -o /tmp/packages-microsoft-prod.deb
sudo dpkg -i /tmp/packages-microsoft-prod.deb
rm -f /tmp/packages-microsoft-prod.deb
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update/Upgrade
sudo apt-get update && sudo apt-get upgrade -y
sudo snap refresh

# Install Flatpak package manager alongside APT and Snap
sudo apt-get install -y flatpak flatpak-builder

# Add Flatpak repositories
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Update Flatpak
sudo flatpak update -y

# Install my fonts
sudo apt-get install -y fonts-inter fonts-inter-variable fonts-jetbrains-mono

# Install my cursors
sudo apt-get install -y bibata-cursor-theme
sudo apt-get install -y phinger-cursor-theme
sudo apt-get install -y breeze-cursor-theme

# Install the toolchains and supporting tooling for setting up an efficient development environment
sudo apt-get install -y ca-certificates gnupg2 pass build-essential git file jq procps net-tools libfuse2t64 pipx
# Install and set up Python
sudo apt-get install -y python3-full
sudo apt-get install -y python3-pip python3-pip-whl
sudo apt-get install -y python3-venv
# Install and set up Go
sudo apt-get install -y golang-go
# Install and set up Rust
sudo snap install rustup --classic
export PATH=$PATH:/snap/bin
rustup install stable
# Install and set up GCC
sudo apt-get install -y gcc g++
# Install and set up Clang
sudo apt-get install -y clang
# Install and set up .NET
sudo apt-get install -y dotnet-sdk-10.0
# Install and set up Java
sudo apt-get install -y default-jdk
# Install and set up PHP
sudo apt-get install -y php php-cli php-common php-curl php-json php-mbstring php-xml php-zip php-fileinfo
# Install and set up Ruby
sudo apt-get install -y ruby-full
# Install and set up nvm
# PROFILE=/dev/null stops the installer editing ~/.bashrc; home/bash/.bashrc.d/nvm.sh loads nvm instead
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | PROFILE=/dev/null bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 24.21.0
nvm use 24.21.0
# Install and set up Postman
sudo snap install postman
# Install and set up Docker Desktop
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
curl -fL https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb -o /tmp/docker-desktop-amd64.deb
sudo apt-get install -y /tmp/docker-desktop-amd64.deb
rm -f /tmp/docker-desktop-amd64.deb
if [ ! -d "$HOME/.password-store" ]; then
  GPG_KEY_ID=$(gpg --list-keys --with-colons "Docker Desktop" 2>/dev/null | awk -F: '/^pub/ { print $5; exit }' || true)
  if [ -z "$GPG_KEY_ID" ]; then
    gpg --batch --passphrase "" --quick-gen-key "Docker Desktop" default default
    GPG_KEY_ID=$(gpg --list-keys --with-colons "Docker Desktop" 2>/dev/null | awk -F: '/^pub/ { print $5; exit }' || true)
  fi
  pass init "$GPG_KEY_ID"
fi
# Install and set up Multipass
sudo snap install multipass
# Install and set up Microk8s
sudo snap install microk8s --classic
sudo snap install kubectl --classic
sudo usermod -a -G microk8s "$USER"
mkdir -p ~/.kube
sudo chown -R "$USER" ~/.kube
# Group membership applies after the next login, so use sudo here instead of newgrp
sudo microk8s status --wait-ready
# The redirect runs as the user on purpose, so the file is owned by the user
# shellcheck disable=SC2024
sudo microk8s config > ~/.kube/config
# Install and set up Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ -d ~/.linuxbrew ]; then eval "$(~/.linuxbrew/bin/brew shellenv)"; fi
if [ -d /home/linuxbrew/.linuxbrew ]; then eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; fi
BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "")
if [ -n "$BREW_PREFIX" ]; then
  brew install helm
  brew install norwoodj/tap/helm-docs
  brew install derailed/k9s/k9s
  brew install --cask claude-code
fi
# Install and set up GitKraken
sudo snap install gitkraken --classic
# Install and set up VS Code
sudo snap install code --classic
# Install JetBrains Toolbox
JETBRAINS_TOOLBOX_URL=$(curl -fsS "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | jq -r '.TBA[0].downloads.linux.link')
if [ -n "$JETBRAINS_TOOLBOX_URL" ] && [ "$JETBRAINS_TOOLBOX_URL" != "null" ]; then
  sudo mkdir -p /opt/jetbrains-toolbox
  curl -fL "$JETBRAINS_TOOLBOX_URL" -o /tmp/jetbrains-toolbox.tar.gz
  sudo tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
  rm -f /tmp/jetbrains-toolbox.tar.gz
  sudo chmod +x /opt/jetbrains-toolbox/bin/jetbrains-toolbox
  # First launch registers the desktop entry and autostart
  /opt/jetbrains-toolbox/bin/jetbrains-toolbox &
  sleep 5
  pkill jetbrains-toolbox || true
fi

# Install applications
sudo apt-get install -y clamav clamtk clamav-daemon
sudo apt-get install -y deja-dup
sudo apt-get install -y file-roller
sudo apt-get install -y gnome-shell-extensions
sudo apt-get install -y gnome-tweaks
sudo apt-get install -y google-chrome-stable
sudo apt-get install -y ksnip
sudo apt-get install -y libreoffice
sudo apt-get install -y nexis
sudo apt-get install -y openrazer-meta
sudo apt-get install -y polychromatic
sudo apt-get install -y qbittorrent
sudo apt-get install -y solaar
sudo apt-get install -y steam
sudo apt-get install -y ulauncher
sudo apt-get install -y vlc
sudo snap install acrordrdc
sudo snap install firefox
sudo snap install gimp
sudo snap install gnome-chess
sudo flatpak install -y flathub me.timschneeberger.GalaxyBudsClient
sudo flatpak install -y flathub com.github.dail8859.NotepadNext

# Cleanup
sudo apt-get autoremove -y
sudo apt-get autoclean -y
sudo snap set system refresh.retain=2
snap list --all | awk '/disabled/{print $1, $3}' | while IFS=' ' read -r snap rev; do
    sudo snap remove --revision="$rev" "$snap"
done
sudo flatpak uninstall --unused -y
sudo flatpak repair
