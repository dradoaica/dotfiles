#!/bin/bash
# Add the APT, Snap and Flatpak sources, install the packages listed in packages/, then set up each tool in
# scripts/components/ (see COMPONENTS in lib.sh). Every step runs even if an earlier one failed; the failed steps are
# listed at the end, so one broken source does not stop the rest of a fresh install.
# Usage: packages.sh [--simulate]
#   --simulate  only add the APT sources and check that apt can install every package in packages/apt.txt
#               together, without installing them. CI runs this in a container of the release.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

simulate=false
case "${1:-}" in
  --simulate) simulate=true ;;
  "") ;;
  *) echo "Usage: $(basename "$0") [--simulate]" >&2; exit 1 ;;
esac

start_log packages
source /etc/os-release
# Snaps install their commands here, and this shell started before they existed
export PATH="$PATH:/snap/bin"

prerequisites() {
  apt_get update
  apt_get install -y "${PREREQUISITES[@]}"
}

# write_sources <name> <URI> <suite> <components> <keyring file>: write /etc/apt/sources.list.d/<name>.sources in
# the deb822 format, so apt trusts that key for this repository only
write_sources() {
  local name="$1" uri="$2" suite="$3" components="$4" keyring="$5"
  sudo tee "/etc/apt/sources.list.d/$name.sources" > /dev/null << EOF
Types: deb
URIs: $uri
Suites: $suite
Components: $components
Architectures: $(dpkg --print-architecture)
Signed-By: $keyring
EOF
}

# save_signing_key <URL> <keyring file>: download a repository's signing key. apt reads a .asc file as it is
# published, but a .gpg file must be a binary keyring, so an armored key saved as .gpg is dearmored first.
save_signing_key() {
  local key
  key="$(mktemp)"
  curl -fsSL "$1" -o "$key"
  if [[ "$2" == *.gpg ]] && grep -q -- '-----BEGIN PGP PUBLIC KEY BLOCK-----' "$key"; then
    sudo gpg --batch --yes --dearmor -o "$2" "$key"
  else
    sudo install -m 0644 "$key" "$2"
  fi
  rm -f "$key"
  sudo chmod a+r "$2"
}

apt_sources() {
  # Steam needs 32-bit libraries
  sudo dpkg --add-architecture i386

  local ppas ppa repositories repository name key_url keyring uri suite components
  # The first word of each line; the rest are the packages wanted from the PPA
  mapfile -t ppas < <(read_list ppas.txt | awk '{ print $1 }')
  for ppa in "${ppas[@]}"; do
    sudo add-apt-repository -y "$ppa"
  done
  # Keep each PPA to those packages, so it cannot replace a package from Ubuntu's archive
  ppa_preferences | sudo install -m 0644 /dev/stdin /etc/apt/preferences.d/dotfiles-ppas

  # The repositories with their own signing key, with {codename} replaced by this release's code name
  sudo install -m 0755 -d /usr/share/keyrings /etc/apt/keyrings
  mapfile -t repositories < <(read_list repositories.txt)
  for repository in "${repositories[@]}"; do
    read -r name key_url keyring uri suite components <<< "${repository//"{codename}"/$VERSION_CODENAME}"
    save_signing_key "$key_url" "$keyring"
    write_sources "$name" "$uri" "$suite" "$components" "$keyring"
  done
}

sources() {
  apt_sources
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

upgrade() {
  upgrade_apt
  upgrade_snaps
  upgrade_flatpaks
}

apt_packages() {
  local packages
  mapfile -t packages < <(read_list apt.txt)
  # One apt-get call is much faster, but fails as a whole if a single package cannot be installed. Then install them
  # one by one, so the rest still get installed, and report the ones that could not be.
  apt_get install -y "${packages[@]}" || install_each apt.txt apt_get install -y
}

# Check that apt can install every package in apt.txt together from the sources above, without installing them: a
# package that the sources still offer stops being installable when one of its dependencies is renamed or removed.
# The simulation lists every package it would install; show its output only when it fails, without that list.
simulate_apt_packages() {
  local packages simulation
  mapfile -t packages < <(read_list apt.txt)
  apt_get update
  if ! simulation="$(apt-get install --simulate "${packages[@]}" 2>&1)"; then
    grep -vE '^(Inst|Conf) ' <<< "$simulation" >&2
    return 1
  fi
  echo "apt can install the ${#packages[@]} packages in apt.txt together"
}

snap_packages() { install_each snap.txt sudo snap install; }
flatpak_packages() { install_each flatpak.txt sudo flatpak install -y flathub; }

if [ "$simulate" = true ]; then
  step Prerequisites prerequisites
  step "APT sources" apt_sources
  step "APT packages (simulated)" simulate_apt_packages
  finish "Done."
  exit 0
fi

step Prerequisites prerequisites
step Migrations bash "$SCRIPT_DIR/migrations.sh"
step Sources sources
step Upgrade upgrade
step "APT packages" apt_packages
step Snaps snap_packages
step Flatpak flatpak_packages
run_components install
step Cleanup bash "$SCRIPT_DIR/cleanup.sh"

finish "Done."
