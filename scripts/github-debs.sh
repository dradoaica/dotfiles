#!/bin/bash
# Install the apps published as .deb files on GitHub releases, or upgrade them when there is a newer release.
# Uses the GitHub API directly, so it works before `gh auth login`.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# <owner/repo> <package> <regex matching the release asset>
PACKAGES=(
  "balena-io/etcher balena-etcher ^balena-etcher_.*_amd64\.deb$"
  "daniel-g-carrasco/wayland-scroll-factor wayland-scroll-factor ^wayland-scroll-factor_.*_amd64\.deb$"
)

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
# apt runs as _apt and must be able to read the downloaded files
chmod 755 "$TMP_DIR"

install_latest() {
  local repo="$1" package="$2" pattern="$3"
  local release latest asset installed deb digest

  release="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")"
  latest="$(jq -r '.tag_name | ltrimstr("v")' <<< "$release")"
  asset="$(jq -c --arg pattern "$pattern" '[.assets[] | select(.name | test($pattern))][0] // empty' <<< "$release")"
  if [ -z "$asset" ]; then
    echo "No asset matching $pattern in the latest $repo release" >&2
    return 1
  fi

  installed="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)"
  if [ -n "$installed" ] && ! dpkg --compare-versions "$installed" lt "$latest"; then
    echo "$package is up to date ($installed)"
    return 0
  fi

  deb="$TMP_DIR/$(jq -r '.name' <<< "$asset")"
  curl -fL "$(jq -r '.browser_download_url' <<< "$asset")" -o "$deb"
  # GitHub publishes a SHA-256 digest for each release asset; check it when there is one
  digest="$(jq -r '.digest // empty' <<< "$asset")"
  if [ -n "$digest" ]; then
    echo "${digest#sha256:}  $deb" | sha256sum --check --quiet
  fi
  chmod 644 "$deb"
  sudo apt-get install -y "$deb"
}

for entry in "${PACKAGES[@]}"; do
  IFS=' ' read -r repo package pattern <<< "$entry"
  install_latest "$repo" "$package" "$pattern"
done
