#!/bin/bash
# Save or restore app settings that cannot be symlinked: the apps rewrite the files, or the files hold
# machine-specific names. They are kept in app-settings/, one section below per app.
# Usage: app-settings.sh dump   save the settings of every app in APPS into the repository
#        app-settings.sh load   apply them to this machine
#        app-settings.sh check  report the ones that differ from the saved ones, changing nothing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# The apps whose settings are saved, in the order they are saved and loaded. Each has a section below with save_<app>
# and load_<app>, which write and read the saved copy in SAVED_DIR.
APPS=(openlogi claude default_apps vscode helm)
# app-settings/, or a temporary copy of it for `check`
SAVED_DIR="$ROOT_DIR/app-settings"

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

# --- OpenLogi: the Logitech button bindings, DPI and gestures, copied in and out ------------------------------------

OPENLOGI_CONFIG="$HOME/.config/openlogi/config.toml"

save_openlogi() {
  save_file "$OPENLOGI_CONFIG" "$SAVED_DIR/openlogi/config.toml" "OpenLogi config"
}

load_openlogi() {
  restore_file "$SAVED_DIR/openlogi/config.toml" "$OPENLOGI_CONFIG" "OpenLogi config" \
    "restart OpenLogi if it is running"
}

# --- Claude Code: the settings in CLAUDE_SAVED_KEYS -----------------------------------------------------------------

CLAUDE_SETTINGS="$HOME/.claude/settings.json"
# The settings that are saved. Anything else in the file, such as an env block holding an API token, is left out, and
# kept as it is on this machine when the saved ones are loaded. The repository is public: add a key here only when
# what it holds is safe to publish.
CLAUDE_SAVED_KEYS='["model", "modelSettings", "theme", "enabledPlugins", "extraKnownMarketplaces", "autoMode"]'
# The settings name files in the home directory by their full path. They are saved with this in its place, and loaded
# with the home directory of the user who loads them.
HOME_PLACEHOLDER="{home}"

save_claude() {
  [ -f "$CLAUDE_SETTINGS" ] || return 0
  local settings left_out
  # Read first, so a file that is not valid JSON cannot empty the saved one
  settings="$(jq --argjson keys "$CLAUDE_SAVED_KEYS" 'with_entries(select(.key | IN($keys[])))' "$CLAUDE_SETTINGS")"
  left_out="$(jq -r --argjson keys "$CLAUDE_SAVED_KEYS" 'keys_unsorted - $keys | join(", ")' "$CLAUDE_SETTINGS")"
  mkdir -p "$SAVED_DIR/claude"
  replace "$HOME" "$HOME_PLACEHOLDER" <<< "$settings" > "$SAVED_DIR/claude/settings.json"
  echo "Saved the Claude Code settings"
  if [ -n "$left_out" ]; then
    echo "Left these Claude Code settings out, as they are not in CLAUDE_SAVED_KEYS in" \
      "scripts/app-settings.sh: $left_out" >&2
  fi
}

load_claude() {
  [ -f "$SAVED_DIR/claude/settings.json" ] || return 0
  local merged current='{}'
  merged="$(mktemp)"
  [ ! -s "$CLAUDE_SETTINGS" ] || current="$(cat "$CLAUDE_SETTINGS")"
  # The saved settings, after the ones of this machine that are not saved
  replace "$HOME_PLACEHOLDER" "$HOME" < "$SAVED_DIR/claude/settings.json" \
    | jq --argjson current "$current" --argjson keys "$CLAUDE_SAVED_KEYS" \
      '($current | with_entries(select(.key | IN($keys[]) | not))) + .' > "$merged"
  restore_file "$merged" "$CLAUDE_SETTINGS" "Claude Code settings" "they apply to new Claude Code sessions"
  rm -f "$merged"
}

# --- Default apps: the [Default Applications] of mimeapps.list, applied with xdg-mime -------------------------------

MIMEAPPS="$HOME/.config/mimeapps.list"
# Where desktop entries are installed (user, system, snap, Flatpak)
DESKTOP_DIRS=(
  "$HOME/.local/share/applications"
  /usr/share/applications
  /usr/local/share/applications
  /var/lib/snapd/desktop/applications
  /var/lib/flatpak/exports/share/applications
  "$HOME/.local/share/flatpak/exports/share/applications"
)

save_default_apps() {
  [ -f "$MIMEAPPS" ] || return 0
  # As mime-type=desktop-entry lines. JetBrains IDE entries carry an ID that differs per installation
  # (jetbrains-rider-<uuid>.desktop), so save them as a pattern.
  awk '/^\[/ { section = $0; next } section == "[Default Applications]" && /=/' "$MIMEAPPS" \
    | sed -E 's/^(.*=jetbrains-[a-z]+)-[0-9a-f-]{36}\.desktop$/\1-*.desktop/' > "$SAVED_DIR/default-apps.txt"
  echo "Saved the default apps"
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

load_default_apps() {
  [ -f "$SAVED_DIR/default-apps.txt" ] && command -v xdg-mime > /dev/null || return 0
  local mime pattern entry
  while IFS='=' read -r mime pattern; do
    [ -n "$mime" ] || continue
    entry="$(find_desktop_entry "$pattern")"
    if [ -n "$entry" ]; then
      xdg-mime default "$entry" "$mime"
    else
      echo "Skipped the default app for $mime: $pattern is not installed"
    fi
  done < "$SAVED_DIR/default-apps.txt"
  echo "Loaded the default apps"
}

# --- VS Code: the installed extensions; loading installs the missing ones -------------------------------------------

save_vscode() {
  command -v code > /dev/null || return 0
  local extensions
  # Read first, so a failure cannot empty the saved list
  extensions="$(code --list-extensions)"
  sort <<< "$extensions" > "$SAVED_DIR/vscode-extensions.txt"
  echo "Saved the VS Code extensions"
}

load_vscode() {
  [ -s "$SAVED_DIR/vscode-extensions.txt" ] && command -v code > /dev/null || return 0
  local installed extension
  installed="$(code --list-extensions)"
  while read -r extension; do
    [ -n "$extension" ] || continue
    grep -qixF "$extension" <<< "$installed" && continue
    # Keep going after a failure, and stop `code` reading the rest of the list from stdin
    code --install-extension "$extension" < /dev/null || echo "Could not install the VS Code extension $extension" >&2
  done < "$SAVED_DIR/vscode-extensions.txt"
  echo "Loaded the VS Code extensions"
}

# --- Helm: the repositories, by name and URL ------------------------------------------------------------------------

save_helm() {
  command -v helm > /dev/null || return 0
  local repositories
  # Read first, so a failure cannot empty the saved list (with no repositories, helm prints [])
  if repositories="$(helm repo list -o json)"; then
    jq -r '.[] | "\(.name) \(.url)"' <<< "$repositories" > "$SAVED_DIR/helm-repositories.txt"
    echo "Saved the Helm repositories"
  else
    echo "Could not list the Helm repositories; kept the saved list" >&2
  fi
}

load_helm() {
  [ -s "$SAVED_DIR/helm-repositories.txt" ] && command -v helm > /dev/null || return 0
  local name url
  while IFS=' ' read -r name url; do
    [ -n "$name" ] || continue
    helm repo add --force-update "$name" "$url"
  done < "$SAVED_DIR/helm-repositories.txt"
}

# --- Every app ------------------------------------------------------------------------------------------------------

dump() {
  local app
  mkdir -p "$SAVED_DIR"
  for app in "${APPS[@]}"; do
    "save_$app"
  done
}

load() {
  local app
  for app in "${APPS[@]}"; do
    "load_$app"
  done
}

# Save the settings of this machine to a temporary folder and compare them with the saved ones
check_saved() {
  local saved_dir="$SAVED_DIR"
  CHECK_DIR="$(mktemp -d)"
  trap 'rm -rf "$CHECK_DIR"' EXIT
  # Start from the saved files: dump keeps the ones whose app is not installed here
  cp -r "$saved_dir/." "$CHECK_DIR"
  SAVED_DIR="$CHECK_DIR"
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
