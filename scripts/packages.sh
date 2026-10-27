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

sources() {
  # Steam needs 32-bit libraries
  sudo dpkg --add-architecture i386
  sudo add-apt-repository -y ppa:agornostal/ulauncher
  sudo add-apt-repository -y ppa:openrazer/stable
  sudo add-apt-repository -y ppa:polychromatic/stable
  sudo add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
  sudo add-apt-repository -y ppa:s4solutionsllc/nexis
  # OpenLogi replaces Solaar for Logitech devices; remove Solaar's PPA from machines set up before
  if compgen -G "/etc/apt/sources.list.d/solaar-unifying-*" > /dev/null; then
    sudo add-apt-repository -y --remove ppa:solaar-unifying/stable
  fi
  sudo install -m 0755 -d /usr/share/keyrings
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/google-chrome.gpg
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  sudo curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  # .NET comes from Ubuntu's archive and nothing else installed needs Microsoft's repository; remove it from
  # machines set up before (purging packages-microsoft-prod removes its sources entry and key)
  if dpkg -s packages-microsoft-prod > /dev/null 2>&1; then
    sudo apt-get purge -y packages-microsoft-prod
  fi
  # The same file the Chrome package keeps up to date (it migrates an older google-chrome.list into it)
  sudo rm -f /etc/apt/sources.list.d/google-chrome.list
  printf '%s\n' "Types: deb" "URIs: https://dl.google.com/linux/chrome-stable/deb/" "Suites: stable" "Components: main" \
    "Architectures: amd64" "Signed-By: /usr/share/keyrings/google-chrome.gpg" | sudo tee /etc/apt/sources.list.d/google-chrome.sources
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

upgrade() {
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo snap refresh
  sudo flatpak update -y
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
  nvm_tag="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')"
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
  # Send docker commands to Docker Desktop rather than to Docker Engine's root-owned socket,
  # and start Docker Desktop at login so that context always answers
  if ! docker context inspect desktop-linux > /dev/null 2>&1; then
    docker context create desktop-linux --description "Docker Desktop" --docker "host=unix://$HOME/.docker/desktop/docker.sock"
  fi
  docker context use desktop-linux
  systemctl --user enable docker-desktop
  # Start in the tray without opening the Dashboard, and keep Docker Desktop's own "start when you sign in"
  # setting in line with the systemd unit enabled above
  local docker_settings="$HOME/.docker/desktop/settings-store.json"
  mkdir -p "$(dirname "$docker_settings")"
  [ -s "$docker_settings" ] || echo '{}' > "$docker_settings"
  jq '.AutoStart = true | .OpenUIOnStartupDisabled = true' "$docker_settings" > "$docker_settings.new"
  mv "$docker_settings.new" "$docker_settings"
  # Docker Desktop runs its own engine in a VM, so keep Docker Engine installed but stopped
  sudo systemctl disable --now docker.service docker.socket containerd.service
  # Docker Desktop stores registry credentials with pass, which needs a GPG key
  if [ ! -d "$HOME/.password-store" ]; then
    local gpg_key_id
    gpg_key_id=$(gpg --list-keys --with-colons "Docker Desktop" 2>/dev/null | awk -F: '/^pub/ { print $5; exit }' || true)
    if [ -z "$gpg_key_id" ]; then
      gpg --batch --passphrase "" --quick-gen-key "Docker Desktop" default default
      gpg_key_id=$(gpg --list-keys --with-colons "Docker Desktop" 2>/dev/null | awk -F: '/^pub/ { print $5; exit }' || true)
    fi
    pass init "$gpg_key_id"
  fi
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
  local brew line args missing=()
  for brew in /home/linuxbrew/.linuxbrew/bin/brew ~/.linuxbrew/bin/brew; do
    if [ -x "$brew" ]; then
      eval "$("$brew" shellenv)"
      break
    fi
  done
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
  local url
  url=$(curl -fsS "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | jq -r '.TBA[0].downloads.linux.link')
  sudo mkdir -p /opt/jetbrains-toolbox
  curl -fL "$url" -o /tmp/jetbrains-toolbox.tar.gz
  sudo tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
  rm -f /tmp/jetbrains-toolbox.tar.gz
  sudo chmod +x /opt/jetbrains-toolbox/bin/jetbrains-toolbox
  # First launch registers the desktop entry and autostart
  /opt/jetbrains-toolbox/bin/jetbrains-toolbox &
  sleep 5
  pkill jetbrains-toolbox || true
}

services() {
  # Keep the virus definitions the ClamAV daemon scans with up to date
  sudo systemctl enable --now clamav-freshclam
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
step Kubernetes kubernetes
step Homebrew homebrew
step "JetBrains Toolbox" jetbrains_toolbox
step Services services
step "GitHub releases" github_releases
step Cleanup cleanup

finish "Done."
