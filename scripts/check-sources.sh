#!/bin/bash
# Check that every outside source the installer downloads from still works for this Ubuntu release:
# the PPAs and APT repositories, the Docker Desktop, JetBrains Toolbox, IDplug Classic, nvm and Flathub
# downloads, the GitHub releases in github-debs.sh, and that those sources still offer every package
# in packages/. Installs nothing, and needs no root. CI runs it every week.

# No `set -e`: a source that fails must not stop the checks after it
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
source /etc/os-release

# curl retries a rate limit (HTTP 429) and server errors, waiting longer each time (1, 2, 4... seconds, or as long as
# the server asks), which the Snap Store needs when many checks run in a row. A server that stops answering fails the
# check instead of holding up the others.
CURL_RETRY=(--retry 5 --retry-max-time 120 --max-time 60)

# Fetch only the first byte, so large files are not downloaded
url_exists() { curl -fsSL "${CURL_RETRY[@]}" --range 0-0 -o /dev/null "$1"; }

url_found() { curl -fsSL "${CURL_RETRY[@]}" -o /dev/null "$@"; }

apt_index="$(mktemp)"
trap 'rm -f "$apt_index"' EXIT

# add_apt_index <URL of a repository component> [architecture]: add the names its packages install or provide
# to apt_index
add_apt_index() {
  curl -fsSL --retry 2 "$1/binary-${2:-amd64}/Packages.gz" | gzip -dc | awk '
    /^Package: / { print $2 }
    /^Provides: / {
      sub(/^Provides: /, "")
      count = split($0, provided, /, */)
      for (i = 1; i <= count; i++) { sub(/ .*/, "", provided[i]); print provided[i] }
    }' >> "$apt_index"
}

in_apt_index() { grep -qxF "$1" "$apt_index"; }
snap_exists() { url_found -H 'Snap-Device-Series: 16' "https://api.snapcraft.io/v2/snaps/info/$1"; }
flatpak_exists() { url_found "https://flathub.org/api/v2/appstream/$1"; }

# brew_exists <line of brew.txt>: a cask, a formula from a tap (owner/tap/name) or a core formula
brew_exists() {
  case "$1" in
    "--cask "*) url_found "https://formulae.brew.sh/api/cask/${1#--cask }.json" ;;
    */*/*)
      local owner="${1%%/*}" name="${1##*/}" tap="${1#*/}"
      url_found "https://raw.githubusercontent.com/$owner/homebrew-${tap%%/*}/HEAD/Formula/$name.rb"
      ;;
    *) url_found "https://formulae.brew.sh/api/formula/$1.json" ;;
  esac
}

jetbrains_toolbox_has_download() {
  curl -fsS "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
    | jq -e '.TBA[0].downloads.linux | (.link | strings) and (.checksumLink | strings)'
}

echo "== PPAs for Ubuntu $VERSION_ID ($VERSION_CODENAME)"
# The same list packages.sh adds (not the ones it removes), so the two never drift apart
mapfile -t ppas < <(grep -oE '^[[:space:]]*sudo add-apt-repository -y ppa:[^ ]+' "$SCRIPT_DIR/packages.sh" \
  | sed 's/.*ppa://')
# Finding none means the search above no longer matches packages.sh, not that there is nothing to check
check "found the PPAs in packages.sh (${#ppas[@]})" test "${#ppas[@]}" -gt 0
for ppa in "${ppas[@]}"; do
  owner="${ppa%%/*}"
  name="${ppa#*/}"
  check "ppa:$ppa" url_exists "https://ppa.launchpadcontent.net/$owner/$name/ubuntu/dists/$VERSION_CODENAME/Release"
done

echo "== APT repositories"
check "Docker ($VERSION_CODENAME)" url_exists "https://download.docker.com/linux/ubuntu/dists/$VERSION_CODENAME/Release"
check "GitHub CLI" url_exists https://cli.github.com/packages/dists/stable/Release
check "Google Chrome" url_exists https://dl.google.com/linux/chrome-stable/deb/dists/stable/Release

echo "== Downloads"
check "Docker Desktop latest build and its checksum" bash "$SCRIPT_DIR/docker-desktop.sh" --check
check "JetBrains Toolbox download link and checksum" jetbrains_toolbox_has_download
check "IDplug Classic download still matches its pinned checksum" bash "$SCRIPT_DIR/idplug.sh" --check
nvm_tag="$(github_api repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name // empty')"
check "nvm installer (latest release: ${nvm_tag:-not found})" \
  url_exists "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_tag:-missing}/install.sh"
check "Flathub repository" url_exists https://flathub.org/repo/flathub.flatpakrepo
check "Homebrew installer" url_exists https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

echo "== GitHub releases"
if bash "$SCRIPT_DIR/github-debs.sh" --check; then
  echo "ok    every release in github-debs.sh has a matching .deb"
else
  echo "FAIL  a release in github-debs.sh has no matching .deb"
  failed_checks=$((failed_checks + 1))
fi

echo "== Package indexes"
for component in main restricted universe multiverse; do
  for suite in "$VERSION_CODENAME" "$VERSION_CODENAME-updates"; do
    check "Ubuntu $suite $component" add_apt_index "http://archive.ubuntu.com/ubuntu/dists/$suite/$component"
  done
done
# Steam is 32-bit only; packages.sh enables that architecture for it
check "Ubuntu $VERSION_CODENAME multiverse (i386)" add_apt_index \
  "http://archive.ubuntu.com/ubuntu/dists/$VERSION_CODENAME/multiverse" i386
for ppa in "${ppas[@]}"; do
  owner="${ppa%%/*}"
  name="${ppa#*/}"
  check "ppa:$ppa" add_apt_index "https://ppa.launchpadcontent.net/$owner/$name/ubuntu/dists/$VERSION_CODENAME/main"
done
check "Docker" add_apt_index "https://download.docker.com/linux/ubuntu/dists/$VERSION_CODENAME/stable"
check "GitHub CLI" add_apt_index https://cli.github.com/packages/dists/stable/main
check "Google Chrome" add_apt_index https://dl.google.com/linux/chrome-stable/deb/dists/stable/main

echo "== APT packages"
mapfile -t apt_packages < <(read_list apt.txt)
for package in "${PREREQUISITES[@]}" "${apt_packages[@]}"; do
  check "$package" in_apt_index "$package"
done

echo "== Snaps"
mapfile -t snaps < <(read_list snap.txt | awk '{ print $1 }')
for snap in "${snaps[@]}"; do
  check "$snap" snap_exists "$snap"
done

echo "== Flatpak apps"
mapfile -t flatpaks < <(read_list flatpak.txt)
for app in "${flatpaks[@]}"; do
  check "$app" flatpak_exists "$app"
done

echo "== Homebrew"
mapfile -t brews < <(read_list brew.txt)
for brew in "${brews[@]}"; do
  check "$brew" brew_exists "$brew"
done

if [ "$failed_checks" -gt 0 ]; then
  echo "$failed_checks check(s) failed" >&2
  exit 1
fi
echo "Every source and package works"
