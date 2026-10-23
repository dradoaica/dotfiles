#!/bin/bash
# Update everything the installer set up: system packages, Homebrew, pipx tools,
# GNOME extensions, the Rust toolchain and Node 24.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== APT"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoremove -y
sudo apt-get autoclean -y

echo "== Snap"
sudo snap refresh
# Keep two revisions of each snap and remove the disabled older ones
sudo snap set system refresh.retain=2
snap list --all | awk '/disabled/{print $1, $3}' | while IFS=' ' read -r snap rev; do
  sudo snap remove --revision="$rev" "$snap"
done

echo "== Flatpak"
sudo flatpak update -y
sudo flatpak uninstall --unused -y
sudo flatpak repair

if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  echo "== Homebrew"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  brew update
  brew upgrade
  brew cleanup
fi

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

echo "Done. Log out and back in if GNOME extensions were updated."
