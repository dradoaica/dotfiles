#!/bin/bash
# The tools installed with pipx, such as gnome-extensions-cli (which scripts/gnome.sh installs).
# shellcheck disable=SC2034 # read by run_components in lib.sh
TITLE="pipx"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_update() {
  command -v pipx > /dev/null || { echo "pipx is not installed, skipping"; return; }
  pipx upgrade-all
}

component_main "$@"
