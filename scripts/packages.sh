#!/bin/bash
# Add the APT, Snap and Flatpak sources, then install the packages, toolchains and applications.

set -euo pipefail
IFS=$'\n\t'
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install pre-requisite packages
sudo apt-get update
sudo apt-get install -y wget curl software-properties-common stow

# Add APT repositories
source /etc/os-release
# Steam needs 32-bit libraries
sudo dpkg --add-architecture i386
sudo add-apt-repository -y ppa:agornostal/ulauncher
sudo add-apt-repository -y ppa:openrazer/stable
sudo add-apt-repository -y ppa:polychromatic/stable
sudo add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
sudo add-apt-repository -y ppa:s4solutionsllc/nexis
# Solaar and OpenLogi (an optional app, see the README) both drive Logitech devices; keep only OpenLogi if it is installed
if ! dpkg-query -W openlogi > /dev/null 2>&1; then
  sudo add-apt-repository -y ppa:solaar-unifying/stable
fi
sudo install -m 0755 -d /usr/share/keyrings
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/google-chrome.gpg
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
curl -fsSL "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb" -o /tmp/packages-microsoft-prod.deb
sudo dpkg -i /tmp/packages-microsoft-prod.deb
rm -f /tmp/packages-microsoft-prod.deb
# The same file the Chrome package keeps up to date (it migrates an older google-chrome.list into it)
sudo rm -f /etc/apt/sources.list.d/google-chrome.list
printf '%s\n' "Types: deb" "URIs: https://dl.google.com/linux/chrome-stable/deb/" "Suites: stable" "Components: main" \
  "Architectures: amd64" "Signed-By: /usr/share/keyrings/google-chrome.gpg" | sudo tee /etc/apt/sources.list.d/google-chrome.sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list

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
sudo apt-get install -y ca-certificates gnupg2 pass build-essential git gh file jq procps net-tools libfuse2t64 pipx shellcheck
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
sudo apt-get install -y php php-cli php-common php-curl php-mbstring php-xml php-zip
# Install and set up Ruby
sudo apt-get install -y ruby-full
# Install and set up nvm
# PROFILE=/dev/null stops the installer editing ~/.bashrc; home/bash/.bashrc.d/nvm.sh loads nvm instead
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | PROFILE=/dev/null bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
# Track the latest Node 24 and make it the default for new shells
nvm install 24
nvm alias default 24
# Install and set up Postman
sudo snap install postman
# Install and set up Docker Desktop
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# Downloaded only once; update.sh installs newer builds
if ! dpkg-query -W docker-desktop > /dev/null 2>&1; then
  curl -fL https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb -o /tmp/docker-desktop-amd64.deb
  sudo apt-get install -y /tmp/docker-desktop-amd64.deb
  rm -f /tmp/docker-desktop-amd64.deb
fi
# Send docker commands to Docker Desktop rather than to Docker Engine's root-owned socket,
# and start Docker Desktop at login so that context always answers
if ! docker context inspect desktop-linux > /dev/null 2>&1; then
  docker context create desktop-linux --description "Docker Desktop" --docker "host=unix://$HOME/.docker/desktop/docker.sock"
fi
docker context use desktop-linux
systemctl --user enable docker-desktop
# Docker Desktop runs its own engine in a VM, so keep Docker Engine installed but stopped
sudo systemctl disable --now docker.service docker.socket containerd.service
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
sudo microk8s start
sudo microk8s status --wait-ready
# The redirect runs as the user on purpose, so the file is owned by the user
# shellcheck disable=SC2024
sudo microk8s config > ~/.kube/config
# Don't keep Kubernetes running in the background: `microk8s stop` also stops it starting at boot.
# Run `microk8s start` when you need it.
sudo microk8s stop
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
# Install JetBrains Toolbox (only once: it updates itself)
if [ ! -x /opt/jetbrains-toolbox/bin/jetbrains-toolbox ]; then
  JETBRAINS_TOOLBOX_URL=$(curl -fsS "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | jq -r '.TBA[0].downloads.linux.link')
fi
if [ -n "${JETBRAINS_TOOLBOX_URL:-}" ] && [ "$JETBRAINS_TOOLBOX_URL" != "null" ]; then
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
# Keep the virus definitions the daemon scans with up to date
sudo systemctl enable --now clamav-freshclam
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
if ! dpkg-query -W openlogi > /dev/null 2>&1; then
  sudo apt-get install -y solaar
fi
sudo apt-get install -y steam
sudo apt-get install -y ulauncher
sudo apt-get install -y vlc
sudo snap install acrordrdc
sudo snap install firefox
sudo snap install gimp
sudo snap install gnome-chess
sudo flatpak install -y flathub me.timschneeberger.GalaxyBudsClient
sudo flatpak install -y flathub com.github.dail8859.NotepadNext
# balenaEtcher and Wayland Scroll Factor, from their GitHub releases
bash "$SCRIPT_DIR/github-debs.sh"
# Slow down touchpad scrolling on Wayland; takes effect after the next login
wsf set --scroll-vertical 0.30 --scroll-horizontal 0.30 --pinch-zoom 1.00 --pinch-rotate 1.00
wsf enable

# Cleanup
bash "$SCRIPT_DIR/cleanup.sh"
