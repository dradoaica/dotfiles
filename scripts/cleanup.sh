#!/bin/bash
# Remove packages, caches and old snap and Flatpak revisions that are no longer needed.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get autoremove -y
sudo apt-get autoclean -y
# Keep two revisions of each snap and remove the disabled older ones
sudo snap set system refresh.retain=2
snap list --all | awk '/disabled/{print $1, $3}' | while IFS=' ' read -r snap rev; do
  sudo snap remove --revision="$rev" "$snap"
done
sudo flatpak uninstall --unused -y
sudo flatpak repair
