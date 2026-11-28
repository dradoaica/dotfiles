#!/bin/bash
# The snaps in packages/snap.txt, each line a snap followed by any `snap install` options. Snaps refresh on their
# own; installing and updating refresh them first anyway, so everything is current when the scripts finish.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Snaps"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_install() {
  sudo snap refresh
  install_each snap.txt sudo snap install
}

on_update() {
  sudo snap refresh
}

exists() { url_found -H 'Snap-Device-Series: 16' "https://api.snapcraft.io/v2/snaps/info/$1"; }

on_sources() {
  local snap
  while read -r snap _; do
    check "$snap" exists "$snap"
  done < <(read_list snap.txt)
}

installed_names() { snap list | awk 'NR > 1 { print $1 }'; }

on_doctor() {
  check "every snap in packages/snap.txt is installed" all_installed snap.txt installed_names
}

on_tracked() {
  read_list snap.txt | awk '{ print "snap:" $1 }'
}

component_main "$@"
