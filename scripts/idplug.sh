#!/bin/bash
# Install IDplug Classic, IDEMIA's middleware for the Romanian electronic identity card (CEI), and register its
# PKCS#11 module with Chrome and the Firefox snap, so websites such as hub.mai.gov.ro can see the card's
# certificates. The package only makes them visible to IDplug Manager. MAI publishes neither a checksum nor an
# update feed, so the download is pinned to the file it served for this version: when MAI replaces it, the checksum
# fails and the pin needs updating.
# Usage: idplug.sh [--check]
#   --check  only confirm that the download still serves the pinned file, without installing anything

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

URL="https://hub.mai.gov.ro/cei/info/descarca-middleware?versiune=450linux"
VERSION="4.5.0.487"
SHA256="4d084400dcd80535fcbf5e2b3194e996039ec96199241573b1d63af7bfeb0484"
MODULE_NAME="IDEMIA IDPlug"
MODULE_LIBRARY="/usr/lib/idplugclassic/libidplug-pkcs11.so"
# Chrome's certificate and security module database
NSS_DB="sql:$HOME/.pki/nssdb"

check_only=false
case "${1:-}" in
  --check) check_only=true ;;
  "") ;;
  *) echo "Usage: $(basename "$0") [--check]" >&2; exit 1 ;;
esac

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
# apt runs as _apt and must be able to read the download
chmod 755 "$tmp_dir"
deb="$tmp_dir/idplugclassic.deb"

download() {
  curl -fsSL --retry 2 "$URL" -o "$deb"
  echo "$SHA256  $deb" | sha256sum --check --quiet
}

if [ "$check_only" = true ]; then
  download
  echo "IDplug Classic $(dpkg-deb -f "$deb" Version) (sha256:$SHA256)"
  exit 0
fi

installed="$(dpkg-query -W -f='${Version}' idplugclassic 2>/dev/null || true)"
if [ -n "$installed" ] && ! dpkg --compare-versions "$installed" lt "$VERSION"; then
  echo "IDplug Classic is up to date ($installed)"
else
  download
  chmod 644 "$deb"
  sudo apt-get install -y "$deb"
fi

# Chrome creates the database on its first start; create it now if Chrome has not run yet
if [ ! -f "$HOME/.pki/nssdb/cert9.db" ]; then
  mkdir -p "$HOME/.pki/nssdb"
  chmod 700 "$HOME/.pki" "$HOME/.pki/nssdb"
  certutil -d "$NSS_DB" -N --empty-password
fi
# -rawlist reads the registration without loading the module; -list <name> fails while the card is not inserted.
# Read into a variable first: under pipefail, `grep -q` stopping at the first match can fail the pipeline.
modules="$(modutil -dbdir "$NSS_DB" -rawlist)"
if grep -qF "library=\"$MODULE_LIBRARY\" name=\"$MODULE_NAME\"" <<< "$modules"; then
  echo "Chrome already has the $MODULE_NAME module"
else
  # -force skips the prompt to close the browser; a running Chrome sees the module after a restart
  modutil -dbdir "$NSS_DB" -add "$MODULE_NAME" -libfile "$MODULE_LIBRARY" -force
fi

# The Firefox snap cannot see /usr/lib, and may only load libraries from its own folder in ~/snap, so copy the
# module there (its own dependencies come from the snap's runtime). Firefox loads it through a policy, which also
# covers profiles that do not exist yet; it applies from the next start of Firefox.
if snap list firefox > /dev/null 2>&1; then
  firefox_library="$HOME/snap/firefox/common/pkcs11/${MODULE_LIBRARY##*/}"
  cmp -s "$MODULE_LIBRARY" "$firefox_library" || install -D -m 0644 "$MODULE_LIBRARY" "$firefox_library"
  # Lets Firefox reach the card reader through pcscd
  sudo snap connect firefox:pcscd
  policies=/etc/firefox/policies/policies.json
  if [ -s "$policies" ]; then
    current="$(cat "$policies")"
  else
    current='{}'
  fi
  jq --arg name "$MODULE_NAME" --arg path "$firefox_library" '.policies.SecurityDevices.Add[$name] = $path' \
    <<< "$current" | sudo install -D -m 0644 /dev/stdin "$policies"
fi
