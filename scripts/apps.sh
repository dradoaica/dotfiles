#!/bin/bash
# Save or restore app settings that cannot be symlinked: the apps rewrite the files, or the
# files hold machine-specific names. They are kept in apps/.
# Usage: apps.sh dump   save the OpenLogi config, default apps and Helm repositories into the repository
#        apps.sh load   apply them to this machine

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
APPS_DIR="$ROOT_DIR/apps"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

OPENLOGI_CONFIG="$HOME/.config/openlogi/config.toml"
MIMEAPPS="$HOME/.config/mimeapps.list"
DEFAULT_APPS_FILE="$APPS_DIR/default-apps.txt"
HELM_REPOS_FILE="$APPS_DIR/helm-repositories.txt"

# Where desktop entries are installed (user, system, snap, Flatpak)
DESKTOP_DIRS=(
  "$HOME/.local/share/applications"
  /usr/share/applications
  /usr/local/share/applications
  /var/lib/snapd/desktop/applications
  /var/lib/flatpak/exports/share/applications
  "$HOME/.local/share/flatpak/exports/share/applications"
)

# Homebrew installs helm
load_homebrew || true

dump() {
  mkdir -p "$APPS_DIR"

  if [ -f "$OPENLOGI_CONFIG" ]; then
    mkdir -p "$APPS_DIR/openlogi"
    cp "$OPENLOGI_CONFIG" "$APPS_DIR/openlogi/config.toml"
    echo "Saved the OpenLogi config"
  fi

  if [ -f "$MIMEAPPS" ]; then
    # The [Default Applications] section as mime-type=desktop-entry lines. JetBrains IDE entries carry an
    # ID that differs per installation (jetbrains-rider-<uuid>.desktop), so save them as a pattern.
    awk '/^\[/ { section = $0; next } section == "[Default Applications]" && /=/' "$MIMEAPPS" \
      | sed -E 's/^(.*=jetbrains-[a-z]+)-[0-9a-f-]{36}\.desktop$/\1-*.desktop/' > "$DEFAULT_APPS_FILE"
    echo "Saved the default apps"
  fi

  if command -v helm > /dev/null; then
    helm repo list -o json 2>/dev/null | jq -r '.[] | "\(.name) \(.url)"' > "$HELM_REPOS_FILE" || true
    echo "Saved the Helm repositories"
  fi
}

# Print the desktop entry matching a name or pattern, e.g. jetbrains-rider-*.desktop
find_desktop_entry() {
  local dir match
  for dir in "${DESKTOP_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    match="$(find "$dir" -maxdepth 1 -name "$1" -printf '%f\n' | sort | tail -1)"
    if [ -n "$match" ]; then
      echo "$match"
      return
    fi
  done
}

load() {
  if [ -f "$APPS_DIR/openlogi/config.toml" ]; then
    if ! cmp -s "$APPS_DIR/openlogi/config.toml" "$OPENLOGI_CONFIG"; then
      if [ -f "$OPENLOGI_CONFIG" ]; then
        mkdir -p "$BACKUP_DIR/.config/openlogi"
        cp "$OPENLOGI_CONFIG" "$BACKUP_DIR/.config/openlogi/config.toml"
        echo "Backed up ~/.config/openlogi/config.toml to $BACKUP_DIR"
      fi
      mkdir -p "$(dirname "$OPENLOGI_CONFIG")"
      cp "$APPS_DIR/openlogi/config.toml" "$OPENLOGI_CONFIG"
      echo "Loaded the OpenLogi config; restart OpenLogi if it is running"
    fi
  fi

  if [ -f "$DEFAULT_APPS_FILE" ] && command -v xdg-mime > /dev/null; then
    local mime pattern entry
    while IFS='=' read -r mime pattern; do
      [ -n "$mime" ] || continue
      entry="$(find_desktop_entry "$pattern")"
      if [ -n "$entry" ]; then
        xdg-mime default "$entry" "$mime"
      else
        echo "Skipped the default app for $mime: $pattern is not installed"
      fi
    done < "$DEFAULT_APPS_FILE"
    echo "Loaded the default apps"
  fi

  if [ -s "$HELM_REPOS_FILE" ] && command -v helm > /dev/null; then
    local name url
    while IFS=' ' read -r name url; do
      [ -n "$name" ] || continue
      helm repo add --force-update "$name" "$url"
    done < "$HELM_REPOS_FILE"
  fi
}

case "${1:-}" in
  dump) dump ;;
  load) load ;;
  *) echo "Usage: $(basename "$0") dump|load" >&2; exit 1 ;;
esac
