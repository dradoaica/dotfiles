#!/bin/bash
# Remove packages, caches and old snap and Flatpak revisions that are no longer needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

apt_get autoremove -y
apt_get autoclean -y
# Keep two revisions of each snap and remove the disabled older ones
sudo snap set system refresh.retain=2
snap list --all | awk '/disabled/{print $1, $3}' | while IFS=' ' read -r snap rev; do
  sudo snap remove --revision="$rev" "$snap"
done
sudo flatpak uninstall --unused -y
