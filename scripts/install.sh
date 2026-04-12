#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Add APT repositories
sudo add-apt-repository -y ppa:solaar-unifying/stable
sudo add-apt-repository -y ppa:openrazer/stable
sudo add-apt-repository -y ppa:polychromatic/stable
sudo install -m 0755 -d /usr/share/keyrings
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update/Upgrade
sudo apt-get update && sudo apt-get upgrade -y

# Install Flatpak package manager alongside APT and Snap
sudo apt-get install -y flatpak flatpak-builder

# Add Flatpak repositories
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install my fonts
sudo cp -rv "$ROOT_DIR/fonts/"* /usr/local/share/fonts/
sudo fc-cache -fv

# Install my cursors
sudo apt-get install -y bibata-cursor-theme
sudo apt-get install -y phinger-cursor-theme

# Install the toolchains and supporting tooling for setting up an efficient development environment
sudo apt-get install -y apt-transport-https ca-certificates gnupg2 pass build-essential git file jq procps curl grpcurl net-tools libfuse2
# Install and set up Python
sudo apt-get install -y python3-full
sudo apt-get install -y python3-pip python3-pip-whl
sudo apt-get install -y python3-venv
# Install and set up Go
sudo apt-get install -y golang-go 
export PATH=$PATH:/usr/local/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
# Install and set up Rust
sudo apt-get install -y cargo
sudo snap install rustup --classic
export PATH=$PATH:/snap/bin
echo 'export PATH=$PATH:/snap/bin' >> ~/.bashrc
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
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 24.14.0
nvm use 24.14.0
# Install and set up Postman
sudo snap install postman
# Install and set up Docker Desktop
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
curl -L https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb -o /tmp/docker-desktop-amd64.deb
sudo apt-get install -y /tmp/docker-desktop-amd64.deb
sudo rm -rf /tmp/docker-desktop-amd64.deb
if [ ! -d "$HOME/.password-store" ]; then
  GPG_KEY_ID=$(gpg --list-keys --with-colons "Docker Desktop" | awk -F: '/^pub/ { print $5; exit }')
  if [ -z "$GPG_KEY_ID" ]; then
    gpg --batch --passphrase "" --quick-gen-key "Docker Desktop" default default
    GPG_KEY_ID=$(gpg --list-keys --with-colons "Docker Desktop" | awk -F: '/^pub/ { print $5; exit }')
  fi
  pass init "$GPG_KEY_ID"
fi
# Install and set up Microk8s
sudo snap install microk8s --classic
sudo snap install kubectl --classic
sudo usermod -a -G microk8s $USER
mkdir -p ~/.kube
sudo chown -R $USER ~/.kube
newgrp microk8s
microk8s config > ~/.kube/config
# Install and set up Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "")
if [ -n "$BREW_PREFIX" ]; then
  echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >> ~/.bashrc
  brew install helm
  brew install norwoodj/tap/helm-docs
  brew install derailed/k9s/k9s
fi
# Install and set up GitKraken
sudo snap install gitkraken --classic
# Install and set up VS Code
sudo snap install code --classic
# Install JetBrains Toolbox App
JETBRAINS_TOOLBOX_URL=$(curl -s "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | jq -r '.TBA[0].downloads.linux.link')
if [ -n "$JETBRAINS_TOOLBOX_URL" ]; then
  sudo mkdir -p /opt/jetbrains-toolbox
  curl -L "$JETBRAINS_TOOLBOX_URL" -o /tmp/jetbrains-toolbox.tar.gz
  sudo tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
  sudo rm -rf /tmp/jetbrains-toolbox.tar.gz
  sudo chmod +x /opt/jetbrains-toolbox/jetbrains-toolbox
  /opt/jetbrains-toolbox/jetbrains-toolbox &
  sleep 5
  pkill jetbrains-toolbox || true
fi

# Install the applications
sudo apt-get install -y bleachbit
sudo snap install gimp
sudo apt-get install -y gnome-shell-extensions
sudo apt-get install -y gnome-tweaks
sudo apt-get install -y google-chrome-stable
sudo apt-get install -y ksnip
sudo apt-get install -y libreoffice
sudo apt-get install -y openrazer-meta
sudo apt-get install -y polychromatic
sudo apt-get install -y solaar
sudo apt-get install -y transmission-gtk
sudo apt-get install -y vlc
sudo flatpak install me.timschneeberger.GalaxyBudsClient

# Set up autostart for the applications
cat <<EOF > ~/.config/autostart/ksnip.desktop
[Desktop Entry]
Type=Application
Exec=bash -c "sleep 5 && ksnip"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Ksnip
Comment=Start Ksnip Screenshot Tool
EOF
mkdir -p ~/.config/autostart
cat <<EOF > ~/.config/autostart/transmission-gtk.desktop
[Desktop Entry]
Type=Application
Exec=bash -c "sleep 5 && transmission-gtk --minimized"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Transmission
Comment=Start Transmission Minimized
EOF
cat <<EOF > ~/.config/autostart/galaxybudsclient.desktop
[Desktop Entry]
Type=Application
Exec=bash -c "sleep 5 && flatpak run me.timschneeberger.GalaxyBudsClient /StartMinimized"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Galaxy Buds Client
Comment=Start Galaxy Buds Client Minimized
EOF

# Cleanup
sudo apt-get autoremove -y
sudo apt-get autoclean -y
sudo flatpak uninstall --unused -y
sudo flatpak repair
