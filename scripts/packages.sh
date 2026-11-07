#!/bin/bash
# Add the APT, Snap and Flatpak sources, then install the packages listed in packages/ and set up the
# toolchains and applications. Every step runs even if an earlier one failed; the failed steps are
# listed at the end, so one broken source does not stop the rest of a fresh install.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
source /etc/os-release
# Snaps install their commands here, and this shell started before they existed
export PATH="$PATH:/snap/bin"

prerequisites() {
  sudo apt-get update
  sudo apt-get install -y "${PREREQUISITES[@]}"
}

# write_sources <name> <URI> <suite> <components> <keyring file>: write /etc/apt/sources.list.d/<name>.sources in
# the deb822 format, so apt trusts that key for this repository only, and remove the one-line <name>.list that
# earlier versions of this script wrote
write_sources() {
  local name="$1" uri="$2" suite="$3" components="$4" keyring="$5"
  sudo rm -f "/etc/apt/sources.list.d/$name.list"
  sudo tee "/etc/apt/sources.list.d/$name.sources" > /dev/null <<EOF
Types: deb
URIs: $uri
Suites: $suite
Components: $components
Architectures: $(dpkg --print-architecture)
Signed-By: $keyring
EOF
}

# add_keyed_repository <name> <signing key URL> <keyring file> <URI> <suite> <components>: save the repository's
# signing key and write its sources file
add_keyed_repository() {
  local name="$1" key_url="$2" keyring="$3"
  shift 3
  sudo curl -fsSL "$key_url" -o "$keyring"
  sudo chmod a+r "$keyring"
  write_sources "$name" "$@" "$keyring"
}

# Google Chrome's repository, written as the same .sources file the Chrome package keeps up to date. Its key is
# published armored, so dearmor it rather than saving it as it is.
add_chrome_repository() {
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/google-chrome.gpg
  write_sources google-chrome https://dl.google.com/linux/chrome-stable/deb/ stable main \
    /usr/share/keyrings/google-chrome.gpg
}

sources() {
  # Steam needs 32-bit libraries
  sudo dpkg --add-architecture i386

  sudo add-apt-repository -y ppa:agornostal/ulauncher
  sudo add-apt-repository -y ppa:openrazer/stable
  sudo add-apt-repository -y ppa:polychromatic/stable
  sudo add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
  sudo add-apt-repository -y ppa:s4solutionsllc/nexis

  sudo install -m 0755 -d /usr/share/keyrings /etc/apt/keyrings
  add_keyed_repository docker https://download.docker.com/linux/ubuntu/gpg /etc/apt/keyrings/docker.asc \
    https://download.docker.com/linux/ubuntu "$VERSION_CODENAME" stable
  add_keyed_repository github-cli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages stable main
  add_chrome_repository

  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

  # Sources that machines set up by an earlier version of this script have, but that are no longer used.
  # OpenLogi replaces Solaar for Logitech devices:
  if compgen -G "/etc/apt/sources.list.d/solaar-unifying-*" > /dev/null; then
    sudo add-apt-repository -y --remove ppa:solaar-unifying/stable
  fi
  # .NET comes from Ubuntu's archive, and nothing else needs Microsoft's repository (purging
  # packages-microsoft-prod removes its sources entry and key):
  if dpkg -s packages-microsoft-prod > /dev/null 2>&1; then
    sudo apt-get purge -y packages-microsoft-prod
  fi
}

upgrade() {
  upgrade_apt
  upgrade_snaps
  upgrade_flatpaks
}

apt_packages() {
  local packages package missing=()
  mapfile -t packages < <(read_list apt.txt)
  # One apt-get call is much faster, but fails as a whole if a single package cannot be installed. Then
  # install them one by one, so the rest still get installed, and report the ones that could not be.
  if ! sudo apt-get install -y "${packages[@]}"; then
    for package in "${packages[@]}"; do
      sudo apt-get install -y "$package" || missing+=("$package")
    done
  fi
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Could not install: ${missing[*]}" >&2
    return 1
  fi
}

snap_packages() {
  local line args missing=()
  while read -r line; do
    IFS=' ' read -r -a args <<< "$line"
    sudo snap install "${args[@]}" || missing+=("${args[0]}")
  done < <(read_list snap.txt)
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Could not install: ${missing[*]}" >&2
    return 1
  fi
}

flatpak_packages() {
  local app missing=()
  while read -r app; do
    sudo flatpak install -y flathub "$app" || missing+=("$app")
  done < <(read_list flatpak.txt)
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Could not install: ${missing[*]}" >&2
    return 1
  fi
}

rust() {
  rustup install stable
}

node_js() {
  # The newest nvm release; PROFILE=/dev/null stops the installer editing ~/.bashrc, since
  # home/bash/.bashrc.d/nvm.sh loads nvm instead. On a machine that has nvm, this updates it.
  local nvm_tag
  nvm_tag="$(github_api repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_tag/install.sh" | PROFILE=/dev/null bash
  export NVM_DIR="$HOME/.nvm"
  # nvm is not written for `set -u`
  set +u
  . "$NVM_DIR/nvm.sh"
  # Track the latest Node 24 and make it the default for new shells
  nvm install 24
  nvm alias default 24
}

docker_setup() {
  bash "$SCRIPT_DIR/docker-desktop.sh"
  # Send docker commands to Docker Desktop rather than to Docker Engine's root-owned socket
  if ! docker context inspect desktop-linux > /dev/null 2>&1; then
    docker context create desktop-linux --description "Docker Desktop" \
      --docker "host=unix://$HOME/.docker/desktop/docker.sock"
  fi
  docker context use desktop-linux
  # Do not start Docker Desktop at login: disable its systemd unit and its own "start when you sign in" setting,
  # which would enable the unit again. When it is started, it opens in the tray without the Dashboard
  systemctl --user disable docker-desktop
  local docker_settings="$HOME/.docker/desktop/settings-store.json"
  mkdir -p "$(dirname "$docker_settings")"
  [ -s "$docker_settings" ] || echo '{}' > "$docker_settings"
  jq '.AutoStart = false | .OpenUIOnStartupDisabled = true' "$docker_settings" > "$docker_settings.new"
  mv "$docker_settings.new" "$docker_settings"
  # Docker Desktop runs its own engine in a VM, so keep Docker Engine installed but stopped
  sudo systemctl disable --now docker.service docker.socket containerd.service
}

# gpg_key_id <name>: print the ID of the GPG key with that name, if there is one
gpg_key_id() {
  gpg --list-keys --with-colons "$1" 2> /dev/null | awk -F: '/^pub/ { print $5; exit }' || true
}

docker_credentials() {
  # Docker Desktop stores registry credentials with pass, which needs a GPG key
  if [ -d "$HOME/.password-store" ]; then
    echo "pass is already set up"
    return
  fi
  local key_id
  key_id="$(gpg_key_id "Docker Desktop")"
  if [ -z "$key_id" ]; then
    gpg --batch --passphrase "" --quick-gen-key "Docker Desktop" default default
    key_id="$(gpg_key_id "Docker Desktop")"
  fi
  pass init "$key_id"
}

kubernetes() {
  sudo usermod -a -G microk8s "$USER"
  mkdir -p ~/.kube
  sudo chown -R "$USER" ~/.kube
  # Group membership applies after the next login, so use sudo here instead of newgrp
  sudo microk8s start
  sudo microk8s status --wait-ready
  # Merge the MicroK8s cluster into ~/.kube/config, keeping any other clusters and the current context
  local microk8s_config current_context
  microk8s_config="$(mktemp ~/.kube/microk8s.XXXXXX)"
  # The redirect runs as the user on purpose, so the file is owned by the user
  # shellcheck disable=SC2024
  sudo microk8s config > "$microk8s_config"
  if [ -s ~/.kube/config ]; then
    current_context="$(kubectl config current-context 2>/dev/null || true)"
    # For entries in both files the first file wins, so fresh MicroK8s credentials replace stale ones
    KUBECONFIG="$microk8s_config:$HOME/.kube/config" kubectl config view --flatten > "$microk8s_config.merged"
    mv "$microk8s_config.merged" ~/.kube/config
    if [ -n "$current_context" ]; then
      kubectl config use-context "$current_context" > /dev/null
    fi
  else
    cp "$microk8s_config" ~/.kube/config
  fi
  rm -f "$microk8s_config"
  # It holds cluster credentials
  chmod 600 ~/.kube/config
  # Don't keep Kubernetes running in the background: `microk8s stop` also stops it starting at boot.
  # Run `microk8s start` when you need it.
  sudo microk8s stop
}

homebrew() {
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew
  local line args missing=()
  while read -r line; do
    IFS=' ' read -r -a args <<< "$line"
    brew install "${args[@]}" || missing+=("$line")
  done < <(read_list brew.txt)
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Could not install: ${missing[*]}" >&2
    return 1
  fi
}

jetbrains_toolbox() {
  # Installed only once: it updates itself
  if [ -x /opt/jetbrains-toolbox/bin/jetbrains-toolbox ]; then
    echo "JetBrains Toolbox is already installed"
    return
  fi
  local download url checksum archive
  download="$(curl -fsS "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
    | jq -c '.TBA[0].downloads.linux')"
  url="$(jq -r '.link' <<< "$download")"
  # JetBrains publishes a SHA-256 file ("<hash> *<file name>") next to each download
  checksum="$(curl -fsSL "$(jq -r '.checksumLink' <<< "$download")" | awk '{ print $1 }')"
  archive="$(mktemp --suffix=.tar.gz)"
  # The step runs in a subshell, so this trap fires when the step ends, even if a command below fails.
  # Expanded now: $archive is local, and gone by the time the trap runs.
  # shellcheck disable=SC2064
  trap "rm -f '$archive'" EXIT
  sudo mkdir -p /opt/jetbrains-toolbox
  curl -fL "$url" -o "$archive"
  echo "$checksum  $archive" | sha256sum --check --quiet
  sudo tar -xzf "$archive" -C /opt/jetbrains-toolbox --strip-components=1
  sudo chmod +x /opt/jetbrains-toolbox/bin/jetbrains-toolbox
  # First launch registers the desktop entry and autostart
  /opt/jetbrains-toolbox/bin/jetbrains-toolbox &
  sleep 5
  pkill jetbrains-toolbox || true
}

services() {
  # Keep the virus definitions up to date
  sudo systemctl enable --now clamav-freshclam
  # ClamTk scans on demand with clamscan, so do not keep the ClamAV daemon running: it holds about 1 GB of
  # signatures in memory. Its socket would start it again on the first connection.
  sudo systemctl disable --now clamav-daemon.socket clamav-daemon.service
}

# System files that cannot be symlinked from home/
udev_rules() {
  sudo install -m 0644 -t /etc/udev/rules.d "$ROOT_DIR"/system/udev/*.rules
  sudo udevadm control --reload-rules
  sudo udevadm trigger --subsystem-match=hidraw
}

github_releases() {
  # OpenLogi replaces Solaar, which both drive the same Logitech devices
  if dpkg -s solaar > /dev/null 2>&1; then
    sudo apt-get purge -y solaar
  fi
  # balenaEtcher, OpenLogi and Wayland Scroll Factor (packages/github-debs.txt)
  bash "$SCRIPT_DIR/github-debs.sh"
  # Slow down touchpad scrolling on Wayland; takes effect after the next login
  wsf set --scroll-vertical 0.30 --scroll-horizontal 0.30 --pinch-zoom 1.00 --pinch-rotate 1.00
  wsf enable
}

cleanup() {
  bash "$SCRIPT_DIR/cleanup.sh"
}

step Prerequisites prerequisites
step Sources sources
step Upgrade upgrade
step "APT packages" apt_packages
step Snaps snap_packages
step Flatpak flatpak_packages
step Rust rust
step Node node_js
step Docker docker_setup
step "Docker credentials" docker_credentials
step Kubernetes kubernetes
step Homebrew homebrew
step "JetBrains Toolbox" jetbrains_toolbox
step Services services
step "udev rules" udev_rules
step "GitHub releases" github_releases
step Cleanup cleanup

finish "Done."
