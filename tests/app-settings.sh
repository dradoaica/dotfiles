#!/bin/bash
# Test `app-settings.sh load`, `dump` and `check` in an empty home directory, on a copy of the repository, with
# stand-ins for VS Code, Helm, Homebrew and xdg-mime that only record how they were called. Nothing on the machine it
# runs on is read or changed. CI runs it, and so does `make test`.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT_DIR/tests/lib.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/home" "$TEST_DIR/repo" "$TEST_DIR/bin"
cp -r "$ROOT_DIR/scripts" "$ROOT_DIR/app-settings" "$ROOT_DIR/packages" "$TEST_DIR/repo/"
APP_SETTINGS_SH="$TEST_DIR/repo/scripts/app-settings.sh"
SAVED="$TEST_DIR/repo/app-settings"

export HOME="$TEST_DIR/home" CALLS="$TEST_DIR/calls" STATE="$TEST_DIR/state"
unset XDG_CONFIG_HOME XDG_DATA_HOME
mkdir -p "$STATE"
touch "$CALLS"

# One stand-in under four names: it records its arguments, and answers the two questions app-settings.sh asks
cat > "$TEST_DIR/bin/stand-in" << 'EOF'
#!/bin/sh
name="$(basename "$0")"
echo "$name $*" >> "$CALLS"
case "$name $*" in
  "code --list-extensions") cat "$STATE/code-extensions" ;;
  "code --install-extension "*) echo "$2" >> "$STATE/code-extensions" ;;
  "helm repo list -o json") cat "$STATE/helm-repositories.json" ;;
esac
EOF
chmod +x "$TEST_DIR/bin/stand-in"
for name in brew code helm xdg-mime; do
  ln -s stand-in "$TEST_DIR/bin/$name"
done
export PATH="$TEST_DIR/bin:$PATH"

called() { grep -qxF "$1" "$CALLS" || fail "expected the call: $1"; }

# The lists to load, in place of the saved ones
printf '%s\n' 'text/plain=jetbrains-rider-*.desktop' 'x-test/missing=not-installed.desktop' > "$SAVED/default-apps.txt"
printf '%s\n' a.one b.two > "$SAVED/vscode-extensions.txt"
echo "charts https://example.invalid/charts" > "$SAVED/helm-repositories.txt"
# What the machine has: one of the two extensions, the Helm repository, an IDE and Claude Code settings to replace
echo a.one > "$STATE/code-extensions"
echo '[{"name":"charts","url":"https://example.invalid/charts"}]' > "$STATE/helm-repositories.json"
mkdir -p "$HOME/.local/share/applications" "$HOME/.claude"
touch "$HOME/.local/share/applications/jetbrains-rider-0b1c2d3e-0000-4000-8000-123456789abc.desktop"
# A setting that is not saved, such as a token, must stay on this machine, neither replaced nor saved
echo '{"old": true, "env": {"API_TOKEN": "not-for-the-repository"}}' > "$HOME/.claude/settings.json"
cp "$HOME/.claude/settings.json" "$TEST_DIR/claude-settings-before"

echo "== Load"
output="$(bash "$APP_SETTINGS_SH" load)"
cmp -s "$SAVED/openlogi/config.toml" "$HOME/.config/openlogi/config.toml" || fail "the OpenLogi config was not loaded"
[ "$(stat -c '%a' "$HOME/.config/openlogi/config.toml")" = 600 ] || fail "the OpenLogi config is readable by others"
ok "the OpenLogi config is loaded, readable only by its owner"
grep -qF "\"$HOME/" "$HOME/.claude/settings.json" || fail "the Claude Code settings do not name this home directory"
! grep -qF '{home}' "$HOME/.claude/settings.json" || fail "the placeholder for the home directory was loaded as it is"
ok "the Claude Code settings name this home directory"
cmp -s "$TEST_DIR/claude-settings-before" "$HOME"/.dotfiles-backup/*/.claude/settings.json \
  || fail "the replaced settings were not backed up"
ok "the replaced Claude Code settings are backed up"
jq -e '.old == true and .env.API_TOKEN == "not-for-the-repository"' "$HOME/.claude/settings.json" > /dev/null \
  || fail "the Claude Code settings that are not saved were not kept"
ok "the Claude Code settings that are not saved are kept"
called "xdg-mime default jetbrains-rider-0b1c2d3e-0000-4000-8000-123456789abc.desktop text/plain"
grep -qF "Skipped the default app for x-test/missing" <<< "$output" || fail "a missing app was not skipped"
ok "default apps are matched by pattern, and skipped when not installed"
called "code --install-extension b.two"
! grep -qxF "code --install-extension a.one" "$CALLS" || fail "an installed extension was installed again"
ok "only the missing VS Code extension is installed"
called "helm repo add --force-update charts https://example.invalid/charts"
ok "the Helm repository is added"

echo "== Load again"
output="$(bash "$APP_SETTINGS_SH" load)"
! grep -qE "Backed up|Loaded the (OpenLogi|Claude)" <<< "$output" || fail "a second load replaced files again"
ok "a second load replaces nothing"

echo "== Check and dump"
bash "$APP_SETTINGS_SH" check || fail "the loaded settings differ from the saved ones"
ok "the loaded settings are the saved ones"
echo "# changed" >> "$HOME/.config/openlogi/config.toml"
printf '%s\n' '[Default Applications]' \
  'text/plain=jetbrains-rider-0b1c2d3e-0000-4000-8000-123456789abc.desktop' \
  '[Added Associations]' 'x-test/added=other.desktop' > "$HOME/.config/mimeapps.list"
if bash "$APP_SETTINGS_SH" check > /dev/null 2>&1; then
  fail "a changed setting was not reported"
fi
ok "a changed setting is reported"
cp -r "$SAVED" "$TEST_DIR/before"
bash "$APP_SETTINGS_SH" check > /dev/null 2>&1 || true
diff -r "$TEST_DIR/before" "$SAVED" || fail "check changed the saved files"
ok "check does not change the saved files"
bash "$APP_SETTINGS_SH" dump > /dev/null
cmp -s "$HOME/.config/openlogi/config.toml" "$SAVED/openlogi/config.toml" || fail "the OpenLogi config was not saved"
! grep -qF "$HOME" "$SAVED/claude/settings.json" || fail "the Claude Code settings were saved with the home directory"
[ "$(cat "$SAVED/default-apps.txt")" = 'text/plain=jetbrains-rider-*.desktop' ] \
  || fail "the default apps were saved as: $(cat "$SAVED/default-apps.txt")"
! grep -qF "not-for-the-repository" "$SAVED/claude/settings.json" || fail "a setting that is not saved was saved"
ok "dump saves the changes, without the home directory, the IDE's ID or the settings that are not saved"
bash "$APP_SETTINGS_SH" check > /dev/null || fail "the saved settings differ from the ones just saved"
ok "nothing differs after a dump"
