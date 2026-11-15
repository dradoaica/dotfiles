#!/bin/bash
# Test `gnome.sh load` and `gnome.sh dump` on an empty settings database: a private D-Bus session with its own home
# directory, so the settings of the machine it runs on are never read or changed. Works on a copy of the repository,
# so `dump` does not write into this one. Needs dconf-cli and dbus-daemon; CI runs it, and so does `make test`.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${GNOME_TEST_DIR:-}" ]; then
  GNOME_TEST_DIR="$(mktemp -d)"
  trap 'rm -rf "$GNOME_TEST_DIR"' EXIT
  mkdir -p "$GNOME_TEST_DIR/home/.config" "$GNOME_TEST_DIR/repo" "$GNOME_TEST_DIR/bin"
  mkdir -m 700 "$GNOME_TEST_DIR/run"
  cp -r "$ROOT_DIR/scripts" "$ROOT_DIR/gnome" "$ROOT_DIR/packages" "$GNOME_TEST_DIR/repo/"
  # There is no GNOME Shell to list the extensions of; asking would start its services on the private session
  printf '#!/bin/sh\nexit 1\n' > "$GNOME_TEST_DIR/bin/gnome-extensions"
  chmod +x "$GNOME_TEST_DIR/bin/gnome-extensions"
  # dconf keeps the database in XDG_CONFIG_HOME and talks to its service through XDG_RUNTIME_DIR
  env -u DBUS_SESSION_BUS_ADDRESS -u DCONF_PROFILE GNOME_TEST_DIR="$GNOME_TEST_DIR" HOME="$GNOME_TEST_DIR/home" \
    PATH="$GNOME_TEST_DIR/bin:$PATH" \
    XDG_CONFIG_HOME="$GNOME_TEST_DIR/home/.config" XDG_RUNTIME_DIR="$GNOME_TEST_DIR/run" \
    dbus-run-session -- bash "${BASH_SOURCE[0]}"
  exit
fi

GNOME_SH="$GNOME_TEST_DIR/repo/scripts/gnome.sh"
DASH_TO_PANEL=/org/gnome/shell/extensions/dash-to-panel

fail() {
  echo "FAIL  $1" >&2
  exit 1
}
# expect <description> <key> <value>: the key must hold exactly that value (empty: the key must not be set)
expect() {
  local value
  value="$(dconf read "$2")"
  [ "$value" = "$3" ] || fail "$1: $2 is ${value:-not set}, expected ${3:-not set}"
  echo "ok    $1"
}

# Print each setting in a dconf dump as <section><key>=<value>, which leaves out the sections without settings
settings() {
  awk '/^\[/ { section = $0; next } /=/ { print section $0 }' "$1"
}

# Stop here if this is not the private database after all
[ -z "$(dconf dump /)" ] || fail "the settings database is not empty, so this is not a private session"

echo "== Load without a GNOME session to read the primary monitor from"
dconf write /org/gnome/desktop/interface/no-longer-saved "'value'"
dconf write /org/gnome/shell/extensions/bingwallpaper/state "'running'"
dconf write "$DASH_TO_PANEL/panel-sizes" "'{\"OLD-1\":32}'"
GNOME_PRIMARY_MONITOR="" bash "$GNOME_SH" load
expect "a key that is no longer saved is reset" /org/gnome/desktop/interface/no-longer-saved ""
expect "a key that holds runtime state is kept" /org/gnome/shell/extensions/bingwallpaper/state "'running'"
expect "a setting kept per monitor is left as it was" "$DASH_TO_PANEL/panel-sizes" "'{\"OLD-1\":32}'"
if dconf dump / | grep -qF '{primary-monitor}'; then
  fail "the placeholder for the primary monitor was loaded as it is"
fi
echo "ok    the placeholder for the primary monitor is not loaded"
diff <(dconf dump /org/gnome/desktop/interface/) "$ROOT_DIR/gnome/dconf/desktop-interface.dconf" \
  || fail "the interface settings differ from the saved ones"
echo "ok    the saved settings are loaded"

echo "== Load with a primary monitor"
GNOME_PRIMARY_MONITOR=TST-123 bash "$GNOME_SH" load
expect "the primary monitor is this machine's" "$DASH_TO_PANEL/primary-monitor" "'TST-123'"
dconf read "$DASH_TO_PANEL/panel-sizes" | grep -qF '"TST-123":' \
  || fail "the settings kept per monitor do not name the primary monitor"
echo "ok    the settings kept per monitor name the primary monitor"

echo "== Dump"
# The extensions cannot be listed, which keeps the saved list
GNOME_PRIMARY_MONITOR=TST-123 bash "$GNOME_SH" dump
for file in "$ROOT_DIR"/gnome/dconf/*.dconf; do
  diff <(settings "$GNOME_TEST_DIR/repo/gnome/dconf/${file##*/}") <(settings "$file") \
    || fail "saving the loaded settings changes ${file##*/}"
done
diff "$GNOME_TEST_DIR/repo/gnome/extensions.txt" "$ROOT_DIR/gnome/extensions.txt" \
  || fail "saving without GNOME Shell changes the list of extensions"
echo "ok    saving the loaded settings gives back the saved ones"

echo "== Check"
GNOME_PRIMARY_MONITOR=TST-123 bash "$GNOME_SH" check > /dev/null || fail "the settings differ from the ones just saved"
echo "ok    nothing differs after a dump"
dconf write /org/gnome/desktop/interface/changed-since "'value'"
if GNOME_PRIMARY_MONITOR=TST-123 bash "$GNOME_SH" check > /dev/null 2>&1; then
  fail "a changed setting was not reported"
fi
echo "ok    a changed setting is reported"
