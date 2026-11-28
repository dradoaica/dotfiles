#!/bin/bash
# Test when scripts/components/docker-desktop.sh installs a build from Docker's update feed: only once it is
# RELEASE_MIN_AGE_DAYS old, only when it is newer than the installed one, and only when it matches its checksum. With
# stand-ins for curl (serving a made-up feed), dpkg-query, sudo, docker and systemctl, which record how they were
# called, so nothing is downloaded, installed or changed. CI runs it, and so does `make test`.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT_DIR/tests/lib.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/home" "$TEST_DIR/bin" "$TEST_DIR/state"
COMPONENT="$ROOT_DIR/scripts/components/docker-desktop.sh"
export HOME="$TEST_DIR/home" CALLS="$TEST_DIR/calls" STATE="$TEST_DIR/state"
unset RELEASE_MIN_AGE_DAYS

cat > "$TEST_DIR/bin/stand-in" << 'EOF'
#!/bin/sh
name="$(basename "$0")"
echo "$name $*" >> "$CALLS"
case "$name" in
  curl)
    out=""
    url=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -o) out="$2"; shift ;;
        http*) url="$1" ;;
      esac
      shift
    done
    case "$url" in
      */appcast.xml) body="$(cat "$STATE/appcast.xml")" ;;
      */checksums.txt) body="$(cat "$STATE/checksums.txt")" ;;
      *.deb) body="a deb" ;;
      *) exit 22 ;;
    esac
    if [ -n "$out" ]; then printf '%s' "$body" > "$out"; else printf '%s\n' "$body"; fi
    ;;
  dpkg-query) [ -f "$STATE/installed" ] && cat "$STATE/installed" || exit 1 ;;
esac
EOF
chmod +x "$TEST_DIR/bin/stand-in"
for name in curl dpkg-query sudo docker systemctl; do
  ln -s stand-in "$TEST_DIR/bin/$name"
done
export PATH="$TEST_DIR/bin:$PATH"

DEB_SHA256="$(printf '%s' 'a deb' | sha256sum | cut -d' ' -f1)"
# feed <build> <published this many days ago> [SHA-256]: what the update feed and checksums.txt say
feed() {
  cat > "$STATE/appcast.xml" << EOF
<rss><channel><item>
  <pubDate>$(date -u -d "-$2 days" +%Y-%m-%dT%H:%M:%SZ)</pubDate>
  <enclosure url="https://desktop.docker.com/linux/main/amd64/$1/docker-desktop-amd64.deb"></enclosure>
</item></channel></rss>
EOF
  echo "${3:-$DEB_SHA256} *docker-desktop-amd64.deb" > "$STATE/checksums.txt"
}
# installed <build>: Docker Desktop is installed at that build; with no build, it is not installed
installed() {
  if [ -n "${1:-}" ]; then echo "4.99.0-$1" > "$STATE/installed"; else rm -f "$STATE/installed"; fi
}
# run <action>: run the component with no calls recorded yet, keeping its output and exit status
run() {
  : > "$CALLS"
  status=0
  output="$(bash "$COMPONENT" "$1" 2>&1)" || status=$?
}
apt_installed() { grep -qE '^sudo .*apt-get .*install -y .*package\.deb$' "$CALLS"; }

echo "== Update"
installed 300
feed 300 10
run update
{ [ "$status" -eq 0 ] && grep -q "up to date (build 300)" <<< "$output" && ! apt_installed; } \
  || fail "the installed build was not seen as up to date: $output"
ok "the installed build is kept when the feed has no newer one"

installed 200
feed 300 3
run update
{ [ "$status" -eq 0 ] && grep -q "keeping build 200" <<< "$output" && ! apt_installed; } \
  || fail "a build only 3 days old was not held back: $output"
ok "a newer build is held back until it is 7 days old"

feed 300 10
run update
{ [ "$status" -eq 0 ] && apt_installed; } || fail "a build 10 days old was not installed: $output"
ok "a newer build is installed once it is 7 days old"

feed 300 10 0000000000000000000000000000000000000000000000000000000000000000
run update
{ [ "$status" -ne 0 ] && ! apt_installed; } || fail "a download that does not match its checksum was installed: $output"
ok "a download that does not match its checksum is not installed"

echo "== Install on a machine without Docker Desktop"
installed
feed 300 3
run install
{ [ "$status" -ne 0 ] && grep -q "Run this again once it is 7 days old" <<< "$output" && ! apt_installed; } \
  || fail "a fresh install did not wait for a build only 3 days old: $output"
ok "a fresh install stops, saying when to run it again, while the only build is too new"

export RELEASE_MIN_AGE_DAYS=0
run install
{ [ "$status" -eq 0 ] && apt_installed; } || fail "RELEASE_MIN_AGE_DAYS=0 did not install the newest build: $output"
grep -qx "docker context use desktop-linux" "$CALLS" || fail "docker was not pointed at Docker Desktop"
grep -qx "systemctl --user disable docker-desktop" "$CALLS" || fail "Docker Desktop still starts at login"
jq -e '.AutoStart == false and .OpenUIOnStartupDisabled == true' "$HOME/.docker/desktop/settings-store.json" \
  > /dev/null || fail "Docker Desktop's settings were not changed"
ok "RELEASE_MIN_AGE_DAYS=0 installs the newest build, and the install sets up docker and the login settings"
