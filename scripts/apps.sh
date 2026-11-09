#!/bin/bash
# Save or restore app settings that cannot be symlinked: the apps rewrite the files, or the
# files hold machine-specific names. They are kept in apps/.
# Usage: apps.sh dump   save the OpenLogi config, Claude Code settings, default apps, VS Code extensions and Helm
#                       repositories
#        apps.sh load   apply them to this machine

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
APPS_DIR="$ROOT_DIR/apps"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

OPENLOGI_CONFIG="$HOME/.config/openlogi/config.toml"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
MIMEAPPS="$HOME/.config/mimeapps.list"
DEFAULT_APPS_FILE="$APPS_DIR/default-apps.txt"
VSCODE_EXTENSIONS_FILE="$APPS_DIR/vscode-extensions.txt"
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
# Snaps install their commands here (VS Code is one), and on a fresh install this shell started before they existed
export PATH="$PATH:/snap/bin"

# save_file <file> <saved copy> <description>: copy an app's file into the repository, if the app has one
save_file() {
  [ -f "$1" ] || return 0
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  echo "Saved the $3"
}

# restore_file <saved copy> <file> <description> <what to do next>: put the saved file in place, backing up the one
# it replaces. Readable only by you, as both apps keep these files.
restore_file() {
  local saved="$1" target="$2" relative="${2#"$HOME"/}"
  [ -f "$saved" ] || return 0
  cmp -s "$saved" "$target" && return 0
  if [ -f "$target" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
    cp "$target" "$BACKUP_DIR/$relative"
    echo "Backed up ~/$relative to $BACKUP_DIR"
  fi
  install -D -m 0600 "$saved" "$target"
  echo "Loaded the $3; $4"
}

dump() {
  mkdir -p "$APPS_DIR"

  save_file "$OPENLOGI_CONFIG" "$APPS_DIR/openlogi/config.toml" "OpenLogi config"
  save_file "$CLAUDE_SETTINGS" "$APPS_DIR/claude/settings.json" "Claude Code settings"

  if [ -f "$MIMEAPPS" ]; then
    # The [Default Applications] section as mime-type=desktop-entry lines. JetBrains IDE entries carry an
    # ID that differs per installation (jetbrains-rider-<uuid>.desktop), so save them as a pattern.
    awk '/^\[/ { section = $0; next } section == "[Default Applications]" && /=/' "$MIMEAPPS" \
      | sed -E 's/^(.*=jetbrains-[a-z]+)-[0-9a-f-]{36}\.desktop$/\1-*.desktop/' > "$DEFAULT_APPS_FILE"
    echo "Saved the default apps"
  fi

  if command -v code > /dev/null; then
    local extensions
    # Read first, so a failure cannot empty the saved list
    extensions="$(code --list-extensions)"
    sort <<< "$extensions" > "$VSCODE_EXTENSIONS_FILE"
    echo "Saved the VS Code extensions"
  fi

  if command -v helm > /dev/null; then
    local repositories
    # Read first, so a failure cannot empty the saved list (with no repositories, helm prints [])
    if repositories="$(helm repo list -o json)"; then
      jq -r '.[] | "\(.name) \(.url)"' <<< "$repositories" > "$HELM_REPOS_FILE"
      echo "Saved the Helm repositories"
    else
      echo "Could not list the Helm repositories; kept the saved list" >&2
    fi
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
  restore_file "$APPS_DIR/openlogi/config.toml" "$OPENLOGI_CONFIG" "OpenLogi config" \
    "restart OpenLogi if it is running"
  restore_file "$APPS_DIR/claude/settings.json" "$CLAUDE_SETTINGS" "Claude Code settings" \
    "they apply to new Claude Code sessions"

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

  if [ -s "$VSCODE_EXTENSIONS_FILE" ] && command -v code > /dev/null; then
    local installed extension
    installed="$(code --list-extensions)"
    while read -r extension; do
      [ -n "$extension" ] || continue
      grep -qixF "$extension" <<< "$installed" && continue
      # Keep going after a failure, and stop `code` reading the rest of the list from stdin
      code --install-extension "$extension" < /dev/null || echo "Could not install the VS Code extension $extension" >&2
    done < "$VSCODE_EXTENSIONS_FILE"
    echo "Loaded the VS Code extensions"
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
