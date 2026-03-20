#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$SCRIPT_DIR")"

# Add repositories
sudo add-apt-repository -y ppa:solaar-unifying/stable
sudo add-apt-repository -y ppa:openrazer/stable
sudo add-apt-repository -y ppa:polychromatic/stable
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg --import
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

sudo apt-get update && sudo apt-get upgrade -y

# Install my fonts
sudo cp -rv "$DOTFILES_ROOT/.fonts/"* /usr/local/share/fonts/
sudo fc-cache -fv

# Install my cursors
sudo apt-get install bibata-cursor-theme
sudo apt-get install phinger-cursor-theme

# Install the toolchains and supporting tooling for setting up an efficient development environment
sudo apt-get install -y build-essential procps curl file git libfuse2 jq
# Install and set up Python
sudo apt-get install -y python3-full
sudo apt-get install -y python3-pip python3-pip-whl
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
# Install and set up nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 24.14.0
nvm use 24.14.0
# Install and set up Postman
sudo snap install postman
# Install and set up Microk8s
sudo snap install microk8s --classic
sudo snap install kubectl --classic
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
# Install and set up Git GUI
sudo snap install gitkraken --classic
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
sudo apt-get install -y libreoffice
sudo apt-get install -y openrazer-meta
sudo apt-get install -y polychromatic
sudo apt-get install -y solaar
sudo apt-get install -y transmission-gtk
sudo apt-get install -y vlc