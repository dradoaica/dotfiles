#!/bin/bash
# Check that every outside source the installer downloads from still works for this Ubuntu release:
# the PPAs and APT repositories, the Docker Desktop, JetBrains Toolbox, nvm and Flathub
# downloads, and the GitHub releases in github-debs.sh. Installs nothing. CI runs it every week.

# No `set -e`: a source that fails must not stop the checks after it
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
source /etc/os-release

# Fetch only the first byte, so large files are not downloaded
url_exists() { curl -fsSL --retry 2 --range 0-0 -o /dev/null "$1"; }

jetbrains_toolbox_has_download() {
  curl -fsS "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
    | jq -e '.TBA[0].downloads.linux.link | strings'
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
check "JetBrains Toolbox download link" jetbrains_toolbox_has_download
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

if [ "$failed_checks" -gt 0 ]; then
  echo "$failed_checks source(s) failed" >&2
  exit 1
fi
echo "Every source works"
