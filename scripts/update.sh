#!/bin/bash
# Update everything the installer set up: system packages, firmware, Docker Desktop, the apps from
# GitHub releases, Homebrew, pipx tools, GNOME extensions, the Rust toolchain, nvm and Node 24.
# Every step runs even if an earlier one failed; the failed steps are listed at the end.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

apt_packages() {
  sudo apt-get update
  sudo apt-get upgrade -y
}

snap_packages() {
  sudo snap refresh
}

flatpak_packages() {
  sudo flatpak update -y
}

firmware() {
  command -v fwupdmgr > /dev/null || { echo "fwupdmgr is not installed, skipping"; return; }
  sudo fwupdmgr refresh --force
  # Exit code 2 means there was nothing to update; never reboot from here
  sudo fwupdmgr update --assume-yes --no-reboot-check || [ $? -eq 2 ]
}

docker_desktop() {
  dpkg-query -W docker-desktop > /dev/null 2>&1 || { echo "Docker Desktop is not installed, skipping"; return; }
  bash "$SCRIPT_DIR/docker-desktop.sh"
}

github_debs() {
  bash "$SCRIPT_DIR/github-debs.sh"
}

homebrew() {
  local brew
  for brew in /home/linuxbrew/.linuxbrew/bin/brew ~/.linuxbrew/bin/brew; do
    if [ -x "$brew" ]; then
      eval "$("$brew" shellenv)"
      brew update
      brew upgrade
      brew cleanup
      return
    fi
  done
  echo "Homebrew is not installed, skipping"
}

pipx_tools() {
  command -v pipx > /dev/null || { echo "pipx is not installed, skipping"; return; }
  pipx upgrade-all
}

gnome_extensions() {
  bash "$SCRIPT_DIR/gnome.sh" update
}

rust() {
  command -v rustup > /dev/null || { echo "rustup is not installed, skipping"; return; }
  rustup update
}

node_js() {
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] || { echo "nvm is not installed, skipping"; return; }
  # nvm is a Git checkout; move it to its newest release tag
  git -C "$NVM_DIR" fetch --tags --quiet
  git -C "$NVM_DIR" -c advice.detachedHead=false checkout --quiet \
    "$(git -C "$NVM_DIR" describe --abbrev=0 --tags --match 'v[0-9]*' "$(git -C "$NVM_DIR" rev-list --tags --max-count=1)")"
  # nvm is not written for `set -u`
  set +u
  . "$NVM_DIR/nvm.sh"
  local current latest
  current="$(nvm version default)"
  latest="$(nvm version-remote 24)"
  if [ "$current" = "$latest" ]; then
    # nvm refuses to reinstall packages from the version it is installing, so there is nothing to do
    echo "Node $current is up to date"
  elif [ "$current" = N/A ]; then
    nvm install 24
  else
    # Install the latest Node 24, carrying over the global npm packages
    nvm install 24 --reinstall-packages-from=default
  fi
  nvm alias default 24
}

cleanup() {
  bash "$SCRIPT_DIR/cleanup.sh"
}

# Report dotfiles that an update replaced with a regular file
dotfiles() {
  bash "$SCRIPT_DIR/link.sh" --check
}

step APT apt_packages
step Snap snap_packages
step Flatpak flatpak_packages
step Firmware firmware
step "Docker Desktop" docker_desktop
step "GitHub releases" github_debs
step Homebrew homebrew
step pipx pipx_tools
step "GNOME extensions" gnome_extensions
step Rust rust
step Node node_js
step Cleanup cleanup
step Dotfiles dotfiles

finish "Done. Log out and back in if GNOME extensions were updated."
