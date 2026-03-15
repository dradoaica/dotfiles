#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$SCRIPT_DIR")"

# Add repositories
sudo add-apt-repository -y ppa:solaar-unifying/stable
sudo add-apt-repository -y ppa:openrazer/stable
sudo add-apt-repository -y ppa:polychromatic/stable
sudo add-apt-repository -y ppa:libreoffice/ppa
sudo add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
if ! [ -f /etc/apt/sources.list.d/google-chrome.list ]; then
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg --import
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
fi

sudo apt-get update && sudo apt-get upgrade -y

# Install my fonts
sudo cp -rv "$DOTFILES_ROOT/.fonts/"* /usr/local/share/fonts/
sudo fc-cache -fv

# Install the toolchains and supporting tooling for setting up an efficient development environment
sudo apt-get install -y build-essential procps curl file git
# Install and set up Python
sudo apt-get install -y python3-full
sudo apt-get install -y python3-pip python3-pip-whl
# Install and set up Go
sudo apt-get install -y golang-go
export PATH=$PATH:/usr/local/go/bin
# Install and set up Rust
sudo apt-get install -y cargo
sudo snap install --classic rustup
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
# Install and set up Microk8s
sudo snap install --classic microk8s
# Install and set up Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
brew install helm
brew install norwoodj/tap/helm-docs
# Install and set up Git UI
sudo apt-get install -y git-cola

# Install the applications
sudo apt-get install -y bleachbit
sudo snap install gimp
sudo apt-get install -y gnome-shell-extension-manager
sudo apt-get install -y gnome-tweaks
sudo apt-get install -y google-chrome-stable
sudo apt-get install -y libreoffice
sudo apt-get install -y openrazer-meta
sudo apt-get install -y polychromatic
sudo apt-get install -y qbittorrent
sudo apt-get install -y solaar
sudo apt-get install -y vlc