#!/bin/bash
# Update everything the installer set up: the APT, Snap and Flatpak packages, each tool in scripts/components/ (see
# COMPONENTS in lib.sh) and the GNOME extensions. It ends with the checks of doctor.sh. Every step runs even if an
# earlier one failed; the failed steps are listed at the end.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
start_log update

step APT upgrade_apt
step Snap upgrade_snaps
step Flatpak upgrade_flatpaks
run_components update
step "GNOME extensions" bash "$SCRIPT_DIR/gnome.sh" update
step Cleanup bash "$SCRIPT_DIR/cleanup.sh"
# Report what an update changed that it should not have, such as a dotfile replaced with a regular file, and the
# settings that are not saved yet
step Doctor bash "$SCRIPT_DIR/doctor.sh"

# Ubuntu creates this file when an update (a new kernel, glibc, systemd...) needs a restart to take effect
# and lists the packages that asked for it in reboot-required.pkgs
if [ -f /var/run/reboot-required ]; then
  echo "Restart to finish the update."
  if [ -s /var/run/reboot-required.pkgs ]; then
    echo "Needed by: $(sort -u /var/run/reboot-required.pkgs | paste -sd' ')"
  fi
fi

finish "Done. Log out and back in if GNOME extensions or Node were updated."
