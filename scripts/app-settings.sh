#!/bin/bash
# Save or restore app settings that cannot be symlinked: the apps rewrite the files, or the files hold
# machine-specific names. They are kept in app-settings/.
# Usage: app-settings.sh dump   save the OpenLogi config, Claude Code settings, default apps, VS Code extensions and
#                               Helm repositories
#        app-settings.sh load   apply them to this machine
#        app-settings.sh check  report the ones that differ from the saved ones, changing nothing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

OPENLOGI_CONFIG="$HOME/.config/openlogi/config.toml"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
MIMEAPPS="$HOME/.config/mimeapps.list"
# The Claude Code settings name files in the home directory by their full path. They are saved with this in its
# place, and loaded with the home directory of the user who loads them.
HOME_PLACEHOLDER="{home}"
# The Claude Code settings that are saved. Anything else in the file, such as an env block holding an API token, is
# left out, and kept as it is on this machine when the saved ones are loaded. The repository is public: add a key
# here only when what it holds is safe to publish.
CLAUDE_SAVED_KEYS='["model", "modelSettings", "theme", "enabledPlugins", "extraKnownMarketplaces", "autoMode"]'

# use_saved_dir <folder>: save to and load from that folder
use_saved_dir() {
  SAVED_DIR="$1"
  SAVED_OPENLOGI_CONFIG="$SAVED_DIR/openlogi/config.toml"
  SAVED_CLAUDE_SETTINGS="$SAVED_DIR/claude/settings.json"
  DEFAULT_APPS_FILE="$SAVED_DIR/default-apps.txt"
  VSCODE_EXTENSIONS_FILE="$SAVED_DIR/vscode-extensions.txt"
  HELM_REPOS_FILE="$SAVED_DIR/helm-repositories.txt"
}
use_saved_dir "$ROOT_DIR/app-settings"

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
  mkdir -p "$SAVED_DIR"

  save_file "$OPENLOGI_CONFIG" "$SAVED_OPENLOGI_CONFIG" "OpenLogi config"
  if [ -f "$CLAUDE_SETTINGS" ]; then
    local settings left_out
    # Read first, so a file that is not valid JSON cannot empty the saved one
    settings="$(jq --argjson keys "$CLAUDE_SAVED_KEYS" 'with_entries(select(.key | IN($keys[])))' "$CLAUDE_SETTINGS")"
    left_out="$(jq -r --argjson keys "$CLAUDE_SAVED_KEYS" 'keys_unsorted - $keys | join(", ")' "$CLAUDE_SETTINGS")"
    mkdir -p "$(dirname "$SAVED_CLAUDE_SETTINGS")"
    replace "$HOME" "$HOME_PLACEHOLDER" <<< "$settings" > "$SAVED_CLAUDE_SETTINGS"
    echo "Saved the Claude Code settings"
    if [ -n "$left_out" ]; then
      echo "Left these Claude Code settings out, as they are not in CLAUDE_SAVED_KEYS in" \
        "scripts/app-settings.sh: $left_out" >&2
    fi
  fi

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
  restore_file "$SAVED_OPENLOGI_CONFIG" "$OPENLOGI_CONFIG" "OpenLogi config" \
    "restart OpenLogi if it is running"
  if [ -f "$SAVED_CLAUDE_SETTINGS" ]; then
    local claude_settings current='{}'
    claude_settings="$(mktemp)"
    [ ! -s "$CLAUDE_SETTINGS" ] || current="$(cat "$CLAUDE_SETTINGS")"
    # The saved settings, after the ones of this machine that are not saved
    replace "$HOME_PLACEHOLDER" "$HOME" < "$SAVED_CLAUDE_SETTINGS" \
      | jq --argjson current "$current" --argjson keys "$CLAUDE_SAVED_KEYS" \
        '($current | with_entries(select(.key | IN($keys[]) | not))) + .' > "$claude_settings"
    restore_file "$claude_settings" "$CLAUDE_SETTINGS" "Claude Code settings" \
      "they apply to new Claude Code sessions"
    rm -f "$claude_settings"
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

# Save the settings of this machine to a temporary folder and compare them with the saved ones
check_saved() {
  local saved_dir="$SAVED_DIR"
  CHECK_DIR="$(mktemp -d)"
  trap 'rm -rf "$CHECK_DIR"' EXIT
  # Start from the saved files: dump keeps the ones whose app is not installed here
  cp -r "$saved_dir/." "$CHECK_DIR"
  use_saved_dir "$CHECK_DIR"
  dump > /dev/null
  differences "$saved_dir" "$CHECK_DIR"
  echo "The app settings are the saved ones"
}

case "${1:-}" in
  dump) dump ;;
  load) load ;;
  check) check_saved ;;
  *) echo "Usage: $(basename "$0") dump|load|check" >&2; exit 1 ;;
esac
