#!/bin/bash
# Update everything the installer set up: system packages, firmware, Docker Desktop, the apps from
# GitHub releases, IDplug Classic, Homebrew, pipx tools, GNOME extensions, the Rust toolchain, nvm and Node 24.
# It ends with the checks of doctor.sh. Every step runs even if an earlier one failed; the failed steps are listed
# at the end.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
start_log update

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

# Installs the version pinned in idplug.sh when it changes, and keeps the browsers' copy of the module current
electronic_id() {
  dpkg-query -W idplugclassic > /dev/null 2>&1 || { echo "IDplug Classic is not installed, skipping"; return; }
  bash "$SCRIPT_DIR/idplug.sh"
}

homebrew() {
  load_homebrew || { echo "Homebrew is not installed, skipping"; return; }
  brew update
  brew upgrade
  brew cleanup
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
  # nvm is a Git checkout; move it forward to its newest release tag that is at least 7 days old, the same wait
  # as for the releases the installer downloads (see github_release in lib.sh)
  local tags oldest_allowed newest_tag
  git -C "$NVM_DIR" fetch --tags --quiet
  tags="$(git -C "$NVM_DIR" for-each-ref --sort=-creatordate --format='%(creatordate:unix) %(refname:short)' \
    'refs/tags/v[0-9]*')"
  oldest_allowed="$(($(date +%s) - ${GITHUB_RELEASE_MIN_AGE_DAYS:-7} * 86400))"
  newest_tag="$(awk -v oldest_allowed="$oldest_allowed" '$1 <= oldest_allowed { print $2; exit }' <<< "$tags")"
  if [ -n "$newest_tag" ] && git -C "$NVM_DIR" merge-base --is-ancestor HEAD "$newest_tag"; then
    git -C "$NVM_DIR" -c advice.detachedHead=false checkout --quiet "$newest_tag"
  fi
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
  # Remove the older Node 24 releases; other major versions stay. nvm refuses to remove the active version,
  # which a parent shell's PATH can make one of the old ones, so switch to the newest first.
  nvm use --silent "$latest"
  local version
  for version in "$NVM_DIR"/versions/node/v24.*; do
    version="${version##*/}"
    [ "$version" = "$latest" ] || nvm uninstall "$version"
  done
}

cleanup() {
  bash "$SCRIPT_DIR/cleanup.sh"
}

# Report what an update changed that it should not have, such as a dotfile replaced with a regular file, and the
# settings that are not saved yet
doctor() {
  bash "$SCRIPT_DIR/doctor.sh"
}

step APT upgrade_apt
step Snap upgrade_snaps
step Flatpak upgrade_flatpaks
step Firmware firmware
step "Docker Desktop" docker_desktop
step "GitHub releases" github_debs
step "Electronic ID" electronic_id
step Homebrew homebrew
step pipx pipx_tools
step "GNOME extensions" gnome_extensions
step Rust rust
step Node node_js
step Cleanup cleanup
step Doctor doctor

# Ubuntu creates this file when an update (a new kernel, glibc, systemd...) needs a restart to take effect
# and lists the packages that asked for it in reboot-required.pkgs
if [ -f /var/run/reboot-required ]; then
  echo "Restart to finish the update."
  if [ -s /var/run/reboot-required.pkgs ]; then
    echo "Needed by: $(sort -u /var/run/reboot-required.pkgs | paste -sd' ')"
  fi
fi

finish "Done. Log out and back in if GNOME extensions or Node were updated."
