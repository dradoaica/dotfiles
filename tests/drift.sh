#!/bin/bash
# Test drift.sh on a copy of the scripts with made-up package lists, and stand-ins for the package managers that
# answer with a made-up machine. Nothing on the machine it runs on is read. CI runs it, and so does `make test`.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/repo/packages" "$TEST_DIR/bin"
cp -r "$ROOT_DIR/scripts" "$TEST_DIR/repo/"
LISTS="$TEST_DIR/repo/packages"

# What a fresh install would have
echo "git  # a comment" > "$LISTS/apt.txt"
echo "code --classic" > "$LISTS/snap.txt"
echo "org.example.Listed" > "$LISTS/flatpak.txt"
printf '%s\n' helm owner/tap/tapped "--cask claude-code" > "$LISTS/brew.txt"
echo "owner/repo from-github ^from-github_.*\.deb$" > "$LISTS/github-debs.txt"
printf '%s\n' "apt:ignored-.*" "snap:core[0-9]*" > "$LISTS/ignore.txt"

# The machine: everything listed, what Ubuntu installed itself, and one package installed by hand per manager
cat > "$TEST_DIR/bin/stand-in" << 'EOF'
#!/bin/sh
case "$(basename "$0") $*" in
  "apt-mark showmanual")
    # curl is a prerequisite of the installer; steam:i386 is listed without its architecture
    printf '%s\n' git curl from-github docker-desktop idplugclassic ignored-thing by-hand:i386 \
      bash gnome-shell third-party
    ;;
  "dpkg-query "*"ubuntu-*") echo "installed ubuntu-desktop-minimal" ;;
  "dpkg-query "*) printf '%s\n' "bash required yes" "by-hand optional no" "third-party required no" ;;
  "apt-cache policy "*)
    # third-party claims to be required, but does not come from Ubuntu
    cat << 'POLICY'
bash:
  Installed: 1
  Version table:
 *** 1 500
        500 http://archive.ubuntu.com/ubuntu resolute/main amd64 Packages
third-party:
  Installed: 1
  Version table:
 *** 1 500
        500 https://example.invalid/apt stable/main amd64 Packages
POLICY
    ;;
  "apt-cache depends "*)
    printf '%s\n' ubuntu-desktop-minimal "  Depends: gnome-shell" "  Recommends: <a-virtual-one>"
    ;;
  "snap list") printf '%s\n' "Name Version Rev" "code 1 1" "core22 1 1" "extra-snap 1 1" ;;
  "flatpak list "*) printf '%s\n' org.example.Listed org.example.Extra ;;
  "brew leaves "*) printf '%s\n' helm owner/tap/tapped extra-formula ;;
  "brew list --cask") echo claude-code ;;
  *) echo "unexpected call: $(basename "$0") $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/stand-in"
for name in apt-mark apt-cache brew dpkg-query flatpak snap; do
  ln -s stand-in "$TEST_DIR/bin/$name"
done
export PATH="$TEST_DIR/bin:$PATH"

expected="Installed but not listed in packages/ (add to the matching list, or to packages/ignore.txt):
  apt:by-hand
  apt:third-party
  brew:extra-formula
  flatpak:org.example.Extra
  snap:extra-snap"
output="$(bash "$TEST_DIR/repo/scripts/drift.sh")"
if [ "$output" != "$expected" ]; then
  diff <(echo "$expected") <(echo "$output") >&2 || true
  echo "FAIL  drift.sh reports something other than the packages installed by hand" >&2
  exit 1
fi
echo "ok    only the packages installed by hand are reported"

printf '%s\n' "apt:(by-hand|third-party)" "brew:extra-formula" "flatpak:org.example.Extra" "snap:extra-snap" \
  >> "$LISTS/ignore.txt"
output="$(bash "$TEST_DIR/repo/scripts/drift.sh")"
[ "$output" = "Everything installed is listed in packages/" ] || {
  echo "FAIL  drift.sh still reports ignored packages: $output" >&2
  exit 1
}
echo "ok    ignored packages are not reported"
