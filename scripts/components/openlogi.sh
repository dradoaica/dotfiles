#!/bin/bash
# OpenLogi, for Logitech devices, replaces Solaar, and does not work while Solaar is installed: both drive the same
# devices. So Solaar is removed. OpenLogi itself comes from packages/github-debs.txt and its config from
# app-settings/openlogi/; remove this component too if you remove it from there.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="OpenLogi"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_install() {
  if deb_installed solaar; then
    apt_get purge -y solaar
  fi
}

on_doctor() {
  check "Solaar is not installed (OpenLogi does not work with it)" deb_not_installed solaar
}

component_main "$@"
