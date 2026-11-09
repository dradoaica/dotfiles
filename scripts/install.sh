#!/bin/bash
# Set up a fresh machine: install packages, link the dotfiles, install the GNOME extensions, then apply the GNOME and
# app settings. Every step runs even if an earlier one failed; the failed steps are listed at the end.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
start_log install

step Packages bash "$SCRIPT_DIR/packages.sh"
step Dotfiles bash "$SCRIPT_DIR/link.sh"
# Check commits to this repository for secrets before they can be pushed (.githooks/pre-commit)
step "Git hooks" git -C "$ROOT_DIR" config core.hooksPath .githooks
step "GNOME extensions" bash "$SCRIPT_DIR/gnome.sh" extensions
step "GNOME settings" bash "$SCRIPT_DIR/gnome.sh" load
step "App settings" bash "$SCRIPT_DIR/apps.sh" load

finish "Done."
