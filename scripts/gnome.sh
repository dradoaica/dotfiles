#!/bin/bash
# Save or restore GNOME extensions (gnome/extensions.txt) and selected settings (gnome/dconf/).
# Usage: gnome.sh dump         save the installed extensions and current settings into the repository
#        gnome.sh extensions   install the extensions listed in gnome/extensions.txt
#        gnome.sh update       update the user-installed extensions
#        gnome.sh load         apply the saved settings to this session

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DCONF_DIR="$ROOT_DIR/gnome/dconf"
EXTENSIONS_FILE="$ROOT_DIR/gnome/extensions.txt"
USER_EXTENSIONS_DIR="$HOME/.local/share/gnome-shell/extensions"

# File name (without .dconf) -> dconf directory
declare -A DCONF_PATHS=(
  [desktop-interface]=/org/gnome/desktop/interface/
  [desktop-peripherals]=/org/gnome/desktop/peripherals/
  [desktop-wm-keybindings]=/org/gnome/desktop/wm/keybindings/
  [desktop-wm-preferences]=/org/gnome/desktop/wm/preferences/
  [media-keys]=/org/gnome/settings-daemon/plugins/media-keys/
  [mutter]=/org/gnome/mutter/
  [shell-keybindings]=/org/gnome/shell/keybindings/
  [extension-arcmenu]=/org/gnome/shell/extensions/arcmenu/
  [extension-battery-health-charging]=/org/gnome/shell/extensions/Battery-Health-Charging/
  [extension-bingwallpaper]=/org/gnome/shell/extensions/bingwallpaper/
  [extension-burn-my-windows]=/org/gnome/shell/extensions/burn-my-windows/
  [extension-dash-to-panel]=/org/gnome/shell/extensions/dash-to-panel/
  [extension-tilingshell]=/org/gnome/shell/extensions/tilingshell/
  [nautilus]=/org/gnome/nautilus/preferences/
  [ptyxis]=/org/gnome/Ptyxis/
  [text-editor]=/org/gnome/TextEditor/
)

# Keys that hold runtime state or machine-specific paths rather than preferences
VOLATILE_KEYS='^(active-profile|bing-json|last-extension-version|last-prefs-version|last-save-directory|migrated-gtk-settings|numlock-state|prefs-open-count|selected-image|state)='

dump() {
  mkdir -p "$DCONF_DIR"
  for name in "${!DCONF_PATHS[@]}"; do
    dconf dump "${DCONF_PATHS[$name]}" | { grep -vE "$VOLATILE_KEYS" || true; } > "$DCONF_DIR/$name.dconf"
  done
  # Only the list of enabled extensions from /org/gnome/shell/, not the whole tree
  printf '[/]\nenabled-extensions=%s\n' "$(dconf read /org/gnome/shell/enabled-extensions)" > "$DCONF_DIR/shell.dconf"
  echo "Saved GNOME settings to $DCONF_DIR"
  if [ -d "$USER_EXTENSIONS_DIR" ]; then
    find "$USER_EXTENSIONS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort > "$EXTENSIONS_FILE"
    echo "Saved the installed extensions to $EXTENSIONS_FILE"
  fi
}

# Print the path to gext (gnome-extensions-cli), installing it with pipx if needed
gext_bin() {
  if ! command -v pipx > /dev/null; then
    sudo apt-get install -y pipx
  fi
  local gext
  gext="$(pipx environment --value PIPX_BIN_DIR)/gext"
  if [ ! -x "$gext" ]; then
    pipx install gnome-extensions-cli --system-site-packages >&2
  fi
  echo "$gext"
}

extensions() {
  local gext uuids
  gext="$(gext_bin)"
  mapfile -t uuids < <(grep -vE '^[[:space:]]*(#|$)' "$EXTENSIONS_FILE")
  # The filesystem backend installs without a confirmation dialog per extension;
  # new extensions become active after the next login
  "$gext" --filesystem install "${uuids[@]}"
}

update() {
  local gext
  gext="$(gext_bin)"
  # Only the user-installed extensions; the system ones come from apt
  "$gext" --filesystem update --user --yes
}

load() {
  for name in "${!DCONF_PATHS[@]}"; do
    if [ -f "$DCONF_DIR/$name.dconf" ]; then
      dconf load "${DCONF_PATHS[$name]}" < "$DCONF_DIR/$name.dconf"
    fi
  done
  if [ -f "$DCONF_DIR/shell.dconf" ]; then
    dconf load /org/gnome/shell/ < "$DCONF_DIR/shell.dconf"
  fi
  echo "Loaded GNOME settings from $DCONF_DIR"
}

case "${1:-}" in
  dump) dump ;;
  extensions) extensions ;;
  update) update ;;
  load) load ;;
  *) echo "Usage: $(basename "$0") dump|extensions|update|load" >&2; exit 1 ;;
esac
