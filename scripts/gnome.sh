#!/bin/bash
# Save or restore GNOME extensions (gnome/extensions.txt) and selected settings (gnome/dconf/).
# Usage: gnome.sh dump         save the installed extensions and current settings into the repository
#        gnome.sh extensions   install the extensions listed in gnome/extensions.txt
#        gnome.sh update       update the user-installed extensions
#        gnome.sh load         apply the saved settings to this session
#        gnome.sh check        report the extensions and settings that differ from the saved ones, changing nothing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
DCONF_DIR="$ROOT_DIR/gnome/dconf"
EXTENSIONS_FILE="$ROOT_DIR/gnome/extensions.txt"

# File name (without .dconf) -> dconf directory
declare -A DCONF_PATHS=(
  [desktop-calendar]=/org/gnome/desktop/calendar/
  [desktop-input-sources]=/org/gnome/desktop/input-sources/
  [desktop-interface]=/org/gnome/desktop/interface/
  [desktop-peripherals]=/org/gnome/desktop/peripherals/
  [desktop-privacy]=/org/gnome/desktop/privacy/
  [desktop-session]=/org/gnome/desktop/session/
  [desktop-sound]=/org/gnome/desktop/sound/
  [desktop-wm-keybindings]=/org/gnome/desktop/wm/keybindings/
  [desktop-wm-preferences]=/org/gnome/desktop/wm/preferences/
  [media-keys]=/org/gnome/settings-daemon/plugins/media-keys/
  [mutter]=/org/gnome/mutter/
  [power]=/org/gnome/settings-daemon/plugins/power/
  [shell-keybindings]=/org/gnome/shell/keybindings/
  [deja-dup]=/org/gnome/deja-dup/
  [extension-appindicator]=/org/gnome/shell/extensions/appindicator/
  [extension-arcmenu]=/org/gnome/shell/extensions/arcmenu/
  [extension-battery-health-charging]=/org/gnome/shell/extensions/Battery-Health-Charging/
  [extension-bingwallpaper]=/org/gnome/shell/extensions/bingwallpaper/
  [extension-burn-my-windows]=/org/gnome/shell/extensions/burn-my-windows/
  [extension-compiz-windows-effect]=/org/gnome/shell/extensions/com/github/hermes83/compiz-windows-effect/
  [extension-dash-to-panel]=/org/gnome/shell/extensions/dash-to-panel/
  [extension-ding]=/org/gnome/shell/extensions/ding/
  [extension-tilingshell]=/org/gnome/shell/extensions/tilingshell/
  [extension-user-theme]=/org/gnome/shell/extensions/user-theme/
  [nautilus]=/org/gnome/nautilus/preferences/
  [ptyxis]=/org/gnome/Ptyxis/
  [text-editor]=/org/gnome/TextEditor/
)

# Keys that hold runtime state or machine-specific paths rather than preferences: never saved or reset
VOLATILE_KEYS=(
  active-profile
  bing-json
  folder
  last-extension-version
  last-prefs-version
  last-save-directory
  last-version
  last-version-name-installed
  migrated-gtk-settings
  mru-sources
  numlock-state
  periodic-timestamp
  prefs-open-count
  prompt-check
  recently-installed-apps
  selected-image
  state
  window-height
  window-width
)
# Matches a "key=value" line of a dconf dump for any of them
VOLATILE_PATTERN="^($(IFS='|'; echo "${VOLATILE_KEYS[*]}"))="

# Dash to Panel keeps its per-monitor settings under each monitor's ID (<vendor>-<serial>, e.g. DEL-ABC1234), which
# differs on every machine. The ID of the primary monitor is saved as this placeholder, and loading puts the ID of
# the primary monitor of the machine it runs on in its place.
MONITOR_PLACEHOLDER="{primary-monitor}"

# Print the ID Dash to Panel knows the primary monitor by. Prints nothing when there is no GNOME session to ask, or
# when the monitor reports no vendor or serial number, which Dash to Panel builds the ID from.
# Set GNOME_PRIMARY_MONITOR to use that ID instead of asking.
primary_monitor() {
  if [ -n "${GNOME_PRIMARY_MONITOR+set}" ]; then
    echo "$GNOME_PRIMARY_MONITOR"
    return
  fi
  python3 - 2> /dev/null << 'EOF' || true
from gi.repository import Gio

state = Gio.bus_get_sync(Gio.BusType.SESSION).call_sync(
    "org.gnome.Mutter.DisplayConfig", "/org/gnome/Mutter/DisplayConfig", "org.gnome.Mutter.DisplayConfig",
    "GetCurrentState", None, None, Gio.DBusCallFlags.NONE, 2000, None).unpack()
# Logical monitors: (x, y, scale, transform, primary, [(connector, vendor, product, serial)], properties)
for monitor in state[2]:
    _, vendor, _, serial = monitor[5][0]
    if monitor[4] and vendor and serial:
        print(f"{vendor}-{serial}")
        break
EOF
}

dump() {
  local name primary
  primary="$(primary_monitor)"
  if [ -z "$primary" ]; then
    echo "Could not find the primary monitor, so the monitor IDs in the settings are saved as they are" >&2
  fi
  mkdir -p "$DCONF_DIR"
  for name in "${!DCONF_PATHS[@]}"; do
    # With no primary monitor, this replaces the placeholder with itself
    dconf dump "${DCONF_PATHS[$name]}" | { grep -vE "$VOLATILE_PATTERN" || true; } \
      | replace "${primary:-$MONITOR_PLACEHOLDER}" "$MONITOR_PLACEHOLDER" > "$DCONF_DIR/$name.dconf"
  done
  # Only the enabled extensions and the apps pinned to the panel from /org/gnome/shell/, not the whole tree
  local key value
  echo '[/]' > "$DCONF_DIR/shell.dconf"
  for key in enabled-extensions favorite-apps; do
    # Empty if it was never changed from its default, and `dconf load` rejects a key without a value
    value="$(dconf read "/org/gnome/shell/$key")"
    [ -z "$value" ] || echo "$key=$value" >> "$DCONF_DIR/shell.dconf"
  done
  echo "Saved GNOME settings to $DCONF_DIR"
  # Only the enabled ones: an extension that is installed but turned off is not part of the setup, and
  # `make doctor` expects every listed extension to be enabled. Read first, so a failure cannot empty the list.
  # Not the ones a package also installs for everyone: those need no download, and shell.dconf keeps them enabled.
  local extensions uuid
  if extensions="$(gnome-extensions list --user --enabled)"; then
    while read -r uuid; do
      [ -d "/usr/share/gnome-shell/extensions/$uuid" ] || echo "$uuid"
    done < <(sort <<< "$extensions") > "$EXTENSIONS_FILE"
    echo "Saved the enabled extensions to $EXTENSIONS_FILE"
  else
    echo "Could not list the GNOME extensions; kept $EXTENSIONS_FILE" >&2
  fi
}

# Print the path to gext (gnome-extensions-cli), installing it with pipx if needed
gext_bin() {
  if ! command -v pipx > /dev/null; then
    apt_get install -y pipx
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
  mapfile -t uuids < <(list_entries "$EXTENSIONS_FILE")
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

# Print each key in a dconf dump read from stdin, relative to the dumped directory (e.g. custom0/binding)
dconf_keys() {
  awk '/^\[/ { section = substr($0, 2, length($0) - 2); next }
       /=/ { key = substr($0, 1, index($0, "=") - 1); print (section == "/" ? "" : section "/") key }'
}

load() {
  local name path file key primary skipped=false
  primary="$(primary_monitor)"
  for name in "${!DCONF_PATHS[@]}"; do
    path="${DCONF_PATHS[$name]}"
    file="$DCONF_DIR/$name.dconf"
    [ -f "$file" ] || continue
    # dconf load only adds and changes keys. Reset the keys set here that are no longer saved, so a setting
    # put back to its default on the machine that saved it goes back to its default here too.
    while read -r key; do
      dconf reset "$path$key"
    done < <(LC_ALL=C comm -23 \
      <(dconf dump "$path" | { grep -vE "$VOLATILE_PATTERN" || true; } | dconf_keys | LC_ALL=C sort) \
      <(dconf_keys < "$file" | LC_ALL=C sort))
    if [ -n "$primary" ]; then
      replace "$MONITOR_PLACEHOLDER" "$primary" < "$file" | dconf load "$path"
    else
      # With no monitor to name, leave the settings kept per monitor as they are on this machine
      ! grep -qF "$MONITOR_PLACEHOLDER" "$file" || skipped=true
      { grep -vF "$MONITOR_PLACEHOLDER" "$file" || true; } | dconf load "$path"
    fi
  done
  if [ -f "$DCONF_DIR/shell.dconf" ]; then
    dconf load /org/gnome/shell/ < "$DCONF_DIR/shell.dconf"
  fi
  echo "Loaded GNOME settings from $DCONF_DIR"
  if [ "$skipped" = true ]; then
    echo "Could not find the primary monitor, so the settings Dash to Panel keeps per monitor were not loaded." \
      "Run this again from a GNOME session." >&2
  fi
}

# Save the extensions and settings of this machine to a temporary folder and compare them with the saved ones
check_saved() {
  CHECK_DIR="$(mktemp -d)"
  trap 'rm -rf "$CHECK_DIR"' EXIT
  # Start from the saved files: dump keeps the list of extensions when it cannot read them
  cp -r "$ROOT_DIR/gnome/." "$CHECK_DIR"
  DCONF_DIR="$CHECK_DIR/dconf"
  EXTENSIONS_FILE="$CHECK_DIR/extensions.txt"
  dump > /dev/null
  differences "$ROOT_DIR/gnome" "$CHECK_DIR"
  echo "The GNOME extensions and settings are the saved ones"
}

case "${1:-}" in
  dump) dump ;;
  extensions) extensions ;;
  update) update ;;
  load) load ;;
  check) check_saved ;;
  *) echo "Usage: $(basename "$0") dump|extensions|update|load|check" >&2; exit 1 ;;
esac
