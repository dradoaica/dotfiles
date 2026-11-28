#!/bin/bash
# Check that every outside source the installer downloads from still works for this Ubuntu release: the PPAs, APT
# repositories and Flathub, that they still offer every package in packages/, and what each tool in
# scripts/components/ downloads (their on_sources). Installs nothing, and needs no root. CI runs it every week.

# No `set -e`: a source that fails must not stop the checks after it
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
source /etc/os-release

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

echo "== PPAs for Ubuntu $VERSION_ID ($VERSION_CODENAME)"
# The lists packages.sh adds the sources from
mapfile -t ppas < <(read_list ppas.txt | awk '{ print $1 }' | sed 's/^ppa://')
mapfile -t repositories < <(read_list repositories.txt | sed "s/{codename}/$VERSION_CODENAME/g")
for ppa in "${ppas[@]}"; do
  owner="${ppa%%/*}"
  name="${ppa#*/}"
  check "ppa:$ppa" url_exists "https://ppa.launchpadcontent.net/$owner/$name/ubuntu/dists/$VERSION_CODENAME/Release"
done

echo "== APT repositories and Flathub"
for repository in "${repositories[@]}"; do
  read -r name key_url _ uri suite _ <<< "$repository"
  check "$name ($suite)" url_exists "${uri%/}/dists/$suite/Release"
  check "$name signing key" url_exists "$key_url"
done

check "Flathub repository" url_exists https://flathub.org/repo/flathub.flatpakrepo

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
for repository in "${repositories[@]}"; do
  read -r name _ _ uri suite components <<< "$repository"
  for component in $components; do
    check "$name $component" add_apt_index "${uri%/}/dists/$suite/$component"
  done
done

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

run_components sources

if [ "$failed_checks" -gt 0 ]; then
  echo "$failed_checks check(s) failed" >&2
  exit 1
fi
echo "Every source and package works"
