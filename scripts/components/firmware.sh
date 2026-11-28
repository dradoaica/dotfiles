#!/bin/bash
# Firmware updates from LVFS, with fwupdmgr. It never reboots: restart yourself when it asks.
# shellcheck disable=SC2034 # read by run_components in lib.sh
TITLE="Firmware"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_update() {
  command -v fwupdmgr > /dev/null || { echo "fwupdmgr is not installed, skipping"; return; }
  sudo fwupdmgr refresh --force
  # Exit code 2 means there was nothing to update
  sudo fwupdmgr update --assume-yes --no-reboot-check || [ $? -eq 2 ]
}

component_main "$@"
