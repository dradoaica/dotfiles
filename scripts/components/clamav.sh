#!/bin/bash
# ClamAV (from packages/apt.txt): keep its virus definitions up to date, but do not keep its daemon running, which
# holds about 1 GB of signatures in memory. ClamTk scans on demand with clamscan, without it.
# shellcheck disable=SC2034 # read by run_components in lib.sh
TITLE="ClamAV"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

on_install() {
  sudo systemctl enable --now clamav-freshclam
  # Its socket would start it again on the first connection
  sudo systemctl disable --now clamav-daemon.socket clamav-daemon.service
}

disabled() { [ "$(systemctl is-enabled "$1" 2> /dev/null)" != enabled ]; }
daemon_disabled() { disabled clamav-daemon.socket && disabled clamav-daemon.service; }

on_doctor() {
  check "ClamAV virus definitions are kept up to date (clamav-freshclam)" systemctl is-active --quiet clamav-freshclam
  check "the ClamAV daemon does not run in the background" daemon_disabled
}

component_main "$@"
