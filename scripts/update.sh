#!/bin/bash
# Update everything the installer set up: system packages, Docker Desktop, Homebrew,
# pipx tools, GNOME extensions, the Rust toolchain and Node 24.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== APT"
sudo apt-get update
sudo apt-get upgrade -y

echo "== Snap"
sudo snap refresh

echo "== Flatpak"
sudo flatpak update -y

# Docker Desktop is installed from a downloaded .deb, not a repository, so APT never upgrades it
if dpkg-query -W docker-desktop > /dev/null 2>&1; then
  echo "== Docker Desktop"
  # The installed version ends in the build number, e.g. 4.89.0-238018
  installed_build="$(dpkg-query -W -f='${Version}' docker-desktop)"
  installed_build="${installed_build##*-}"
  # The update feed links each release as .../amd64/<build>/docker-desktop-amd64.deb
  latest_build="$(curl -fsSL https://desktop.docker.com/linux/main/amd64/appcast.xml \
    | grep -oE 'amd64/[0-9]+/docker-desktop-amd64\.deb' | cut -d/ -f2 | sort -n | tail -1)"
  if [ -n "$latest_build" ] && [ "$latest_build" -gt "$installed_build" ]; then
    curl -fL "https://desktop.docker.com/linux/main/amd64/$latest_build/docker-desktop-amd64.deb" -o /tmp/docker-desktop-amd64.deb
    sudo apt-get install -y /tmp/docker-desktop-amd64.deb
    rm -f /tmp/docker-desktop-amd64.deb
  else
    echo "Docker Desktop is up to date (build $installed_build)"
  fi
fi

for brew in /home/linuxbrew/.linuxbrew/bin/brew ~/.linuxbrew/bin/brew; do
  if [ -x "$brew" ]; then
    echo "== Homebrew"
    eval "$("$brew" shellenv)"
    brew update
    brew upgrade
    brew cleanup
    break
  fi
done

if command -v pipx > /dev/null; then
  echo "== pipx"
  pipx upgrade-all
fi

echo "== GNOME extensions"
bash "$SCRIPT_DIR/gnome.sh" update

if command -v rustup > /dev/null; then
  echo "== Rust"
  rustup update
fi

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  echo "== Node"
  # nvm is not written for `set -u`
  set +u
  . "$NVM_DIR/nvm.sh"
  # Install the latest Node 24, carrying over the global npm packages
  nvm install 24 --reinstall-packages-from=default
  nvm alias default 24
  set -u
fi

echo "== Cleanup"
bash "$SCRIPT_DIR/cleanup.sh"

echo "Done. Log out and back in if GNOME extensions were updated."
