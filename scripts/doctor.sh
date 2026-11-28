#!/bin/bash
# Check that this machine is still set up the way the installer left it, without changing anything: the checks below,
# then each tool's own in scripts/components/ (their on_doctor). Exits with an error if any check fails.

# No `set -e`: a check that fails must not stop the checks after it
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

# Lets Homebrew's commands (gitleaks) be found below
load_homebrew || true

secrets_hook_enabled() {
  [ "$(git -C "$ROOT_DIR" config --get core.hooksPath)" = .githooks ] \
    || { echo "enable it with: git -C $ROOT_DIR config core.hooksPath .githooks" >&2; return 1; }
  command -v gitleaks > /dev/null || { echo "gitleaks is not installed: brew install gitleaks" >&2; return 1; }
}
commits_signed() {
  if [ "$(git config --global --includes --get commit.gpgsign)" != true ] \
    || [ ! -f "$(git config --global --includes --get user.signingkey)" ]; then
    echo "set it up with: make signing" >&2
    return 1
  fi
}
# The preferences that keep each PPA to the packages listed for it in packages/ppas.txt
ppas_pinned() {
  ppa_preferences | cmp -s - /etc/apt/preferences.d/dotfiles-ppas \
    || { echo "write them with: make packages" >&2; return 1; }
}
apt_installed() { dpkg-query -W -f='${db:Status-Status} ${Package}\n' | awk '$1 == "installed" { print $2 }'; }
snaps_installed() { snap list | awk 'NR > 1 { print $1 }'; }
flatpaks_installed() { flatpak list --app --columns=application; }
extensions_enabled() {
  local enabled uuid
  enabled="$(gnome-extensions list --enabled)"
  while read -r uuid; do
    grep -qxF "$uuid" <<< "$enabled" || { echo "not enabled: $uuid" >&2; return 1; }
  done < <(list_entries "$ROOT_DIR/gnome/extensions.txt")
}

echo "== Dotfiles"
check "every dotfile is linked" bash "$SCRIPT_DIR/link.sh" --check

echo "== Security"
check "GitHub CLI is logged in" gh auth status
check "Git signs commits and tags with an SSH key" commits_signed
check "commits to this repository are checked for secrets first (gitleaks pre-commit hook)" secrets_hook_enabled

echo "== Packages"
check "every package in packages/apt.txt is installed" all_installed apt.txt apt_installed
check "every snap in packages/snap.txt is installed" all_installed snap.txt snaps_installed
check "every app in packages/flatpak.txt is installed" all_installed flatpak.txt flatpaks_installed
check "the PPAs can only replace the packages listed for them in packages/ppas.txt" ppas_pinned
check "LibreOffice is not installed (the Craft apps replace it)" deb_not_installed libreoffice-common

run_components doctor

echo "== GNOME"
check "every extension in gnome/extensions.txt is enabled" extensions_enabled

# Settings changed on this machine and not saved, which a fresh install would not get
echo "== Settings"
check "the GNOME extensions and settings are the ones saved in gnome/" bash "$SCRIPT_DIR/gnome.sh" check
check "the app settings are the ones saved in apps/" bash "$SCRIPT_DIR/apps.sh" check

if [ "$failed_checks" -gt 0 ]; then
  echo "$failed_checks check(s) failed" >&2
  exit 1
fi
echo "Everything checks out"
