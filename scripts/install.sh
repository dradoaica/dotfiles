#!/bin/bash
# Set up a fresh machine: install packages, link the dotfiles, install the GNOME extensions, then apply the GNOME and
# app settings.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/packages.sh"
bash "$SCRIPT_DIR/link.sh"
bash "$SCRIPT_DIR/gnome.sh" extensions
bash "$SCRIPT_DIR/gnome.sh" load
bash "$SCRIPT_DIR/apps.sh" load
