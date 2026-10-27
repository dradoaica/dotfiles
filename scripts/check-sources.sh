#!/bin/bash
# Check that every outside source the installer downloads from still works for this Ubuntu release:
# the PPAs and APT repositories, the Microsoft, Docker Desktop, JetBrains Toolbox, nvm and Flathub
# downloads, and the GitHub releases in github-debs.sh. Installs nothing. CI runs it every week.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source /etc/os-release

failures=0
# check <description> <command...>: run the command quietly and report whether it succeeded
check() {
  local description="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "ok    $description"
  else
    echo "FAIL  $description"
    failures=$((failures + 1))
  fi
}

# Fetch only the first byte, so large files are not downloaded
url_exists() { curl -fsSL --retry 2 --range 0-0 -o /dev/null "$1"; }

jetbrains_toolbox_has_download() {
  curl -fsS "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
    | jq -e '.TBA[0].downloads.linux.link | strings'
}

echo "== PPAs for Ubuntu $VERSION_ID ($VERSION_CODENAME)"
# The same list packages.sh adds, so the two never drift apart
while read -r ppa; do
  owner="${ppa%%/*}"
  name="${ppa#*/}"
  check "ppa:$ppa" url_exists "https://ppa.launchpadcontent.net/$owner/$name/ubuntu/dists/$VERSION_CODENAME/Release"
done < <(grep -oE '^sudo add-apt-repository -y ppa:[^ ]+' "$SCRIPT_DIR/packages.sh" | sed 's/.*ppa://')

echo "== APT repositories"
check "Docker ($VERSION_CODENAME)" url_exists "https://download.docker.com/linux/ubuntu/dists/$VERSION_CODENAME/Release"
check "GitHub CLI" url_exists https://cli.github.com/packages/dists/stable/Release
check "Google Chrome" url_exists https://dl.google.com/linux/chrome-stable/deb/dists/stable/Release
check "Microsoft (packages-microsoft-prod.deb for $VERSION_ID)" \
  url_exists "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb"

echo "== Downloads"
check "Docker Desktop latest build and its checksum" bash "$SCRIPT_DIR/docker-desktop.sh" --check
check "JetBrains Toolbox download link" jetbrains_toolbox_has_download
nvm_installer="$(grep -oE 'https://raw.githubusercontent.com/nvm-sh/nvm/[^ ]+/install.sh' "$SCRIPT_DIR/packages.sh")"
nvm_version="${nvm_installer#*nvm-sh/nvm/}"
check "nvm installer (${nvm_version%%/*})" url_exists "$nvm_installer"
check "Flathub repository" url_exists https://flathub.org/repo/flathub.flatpakrepo
check "Homebrew installer" url_exists https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

echo "== GitHub releases"
if bash "$SCRIPT_DIR/github-debs.sh" --check; then
  echo "ok    every release in github-debs.sh has a matching .deb"
else
  echo "FAIL  a release in github-debs.sh has no matching .deb"
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures source(s) failed" >&2
  exit 1
fi
echo "Every source works"
