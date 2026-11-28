#!/bin/bash
# Flathub, and the Flatpak apps from it in packages/flatpak.txt, one application ID per line. Flatpak itself is one of
# the PREREQUISITES in lib.sh.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Flatpak apps"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

FLATHUB=https://flathub.org/repo/flathub.flatpakrepo

on_install() {
  sudo flatpak remote-add --if-not-exists flathub "$FLATHUB"
  sudo flatpak update -y
  install_each flatpak.txt sudo flatpak install -y flathub
}

on_update() {
  sudo flatpak update -y
}

exists() { url_found "https://flathub.org/api/v2/appstream/$1"; }

on_sources() {
  check "Flathub repository" url_exists "$FLATHUB"
  local app
  while read -r app; do
    check "$app" exists "$app"
  done < <(read_list flatpak.txt)
}

installed_names() { flatpak list --app --columns=application; }

on_doctor() {
  check "every app in packages/flatpak.txt is installed" all_installed flatpak.txt installed_names
}

on_tracked() {
  read_list flatpak.txt | sed 's/^/flatpak:/'
}

component_main "$@"
