#!/bin/bash
# The Craft apps (document, spreadsheet, presentation, PDF and image editors) replace LibreOffice, which comes with
# Ubuntu, so LibreOffice is removed. ArtCraft Launcher, which installs and updates the Craft apps, comes from
# packages/github-debs.txt; remove this component too if you remove it from there.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Craft apps"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_install() {
  # Purging these two removes every LibreOffice package, since they all depend on them; `apt-get autoremove`
  # (scripts/cleanup.sh) then removes the libraries they pulled in.
  if deb_installed libreoffice-common; then
    apt_get purge -y libreoffice-common libreoffice-core
  fi
}

on_doctor() {
  check "LibreOffice is not installed (the Craft apps replace it)" deb_not_installed libreoffice-common
}

component_main "$@"
