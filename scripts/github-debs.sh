#!/bin/bash
# Install the apps published as .deb files on GitHub releases, or upgrade them when there is a newer release.
# Uses the GitHub API directly, so it works before `gh auth login`. Each download is checked against the SHA-256
# digest GitHub publishes for it, and a release asset without one is not installed.
# That digest comes from the same place as the file, so it does not help when a maintainer's account is taken over
# and a release is replaced. For that, a release is only installed once it is 7 days old, which gives a bad one
# time to be noticed and withdrawn. Set GITHUB_DEBS_MIN_AGE_DAYS to change the wait; 0 installs the newest release.
# Usage: github-debs.sh [--check]
#   --check  only confirm that each app still has a release with a matching .deb and a digest, without installing

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
# Lines of <owner/repo> <package> <regex matching the release asset>
mapfile -t PACKAGES < <(read_list github-debs.txt)
MIN_AGE_DAYS="${GITHUB_DEBS_MIN_AGE_DAYS:-7}"

check_only=false
case "${1:-}" in
  --check) check_only=true ;;
  "") ;;
  *) echo "Usage: $(basename "$0") [--check]" >&2; exit 1 ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
# apt runs as _apt and must be able to read the downloaded files
chmod 755 "$TMP_DIR"

install_latest() {
  local repo="$1" package="$2" pattern="$3"
  local release latest asset installed deb digest

  # The newest release that is old enough, leaving out drafts and pre-releases
  release="$(github_api "repos/$repo/releases?per_page=30" | jq -c --argjson days "$MIN_AGE_DAYS" '
    [.[] | select((.draft or .prerelease) | not)
         | select((.published_at | fromdateiso8601) <= now - $days * 86400)]
    | sort_by(.published_at) | last // empty')"
  if [ -z "$release" ]; then
    echo "$repo has no release that is at least $MIN_AGE_DAYS days old" >&2
    return 1
  fi
  latest="$(jq -r '.tag_name | ltrimstr("v")' <<< "$release")"
  asset="$(jq -c --arg pattern "$pattern" '[.assets[] | select(.name | test($pattern))][0] // empty' <<< "$release")"
  if [ -z "$asset" ]; then
    echo "No asset matching $pattern in the $repo $latest release" >&2
    return 1
  fi
  # GitHub publishes a SHA-256 digest for each release asset uploaded since mid-2025
  digest="$(jq -r '.digest // empty' <<< "$asset")"
  if [ -z "$digest" ]; then
    echo "$repo $latest: $(jq -r '.name' <<< "$asset") has no SHA-256 digest to check it against" >&2
    return 1
  fi
  if [ "$check_only" = true ]; then
    echo "$repo $latest: $(jq -r '.name' <<< "$asset") ($digest)"
    return 0
  fi

  installed="$(dpkg-query -W -f='${Version}' "$package" 2> /dev/null || true)"
  if [ -n "$installed" ] && ! dpkg --compare-versions "$installed" lt "$latest"; then
    echo "$package is up to date ($installed)"
    return 0
  fi

  deb="$TMP_DIR/$(jq -r '.name' <<< "$asset")"
  curl -fL "$(jq -r '.browser_download_url' <<< "$asset")" -o "$deb"
  echo "${digest#sha256:}  $deb" | sha256sum --check --quiet
  chmod 644 "$deb"
  sudo apt-get install -y "$deb"
}

# Keep going after an app fails, so one broken release does not hold back the others
failed=()
for entry in "${PACKAGES[@]}"; do
  IFS=' ' read -r repo package pattern <<< "$entry"
  # In a subshell with `set -e` in force, which it would not be as an `||` condition
  set +e
  (set -e; install_latest "$repo" "$package" "$pattern")
  status=$?
  set -e
  [ "$status" -eq 0 ] || failed+=("$package")
done
if [ "${#failed[@]}" -gt 0 ]; then
  echo "Failed: ${failed[*]}" >&2
  exit 1
fi
