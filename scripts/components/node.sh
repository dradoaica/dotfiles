#!/bin/bash
# nvm, and the newest Node of NODE_MAJOR as the default for new shells (home/bash/.bashrc.d/nvm.sh puts it on PATH).
# nvm comes from its newest release that is at least RELEASE_MIN_AGE_DAYS old (see lib.sh). Updating keeps the global
# npm packages and removes the older releases of NODE_MAJOR; other major versions stay.
# shellcheck disable=SC2034 # read by component_main in lib.sh
TITLE="Node"

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# The Node major version to keep up to date. To move to another one, change it here and run `make update`.
NODE_MAJOR=24
export NVM_DIR="$HOME/.nvm"

load_nvm() {
  # nvm is not written for `set -u`
  set +u
  . "$NVM_DIR/nvm.sh"
}

# Print the newest nvm release tag that is old enough, or nothing
nvm_tag() {
  github_release nvm-sh/nvm | jq -r '.tag_name // empty'
}

on_install() {
  local tag
  tag="$(nvm_tag)"
  [ -n "$tag" ] || { echo "Found no nvm release to install" >&2; return 1; }
  # PROFILE=/dev/null stops the installer editing ~/.bashrc, since home/bash/.bashrc.d/nvm.sh loads nvm instead. On a
  # machine that has nvm, this updates it.
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$tag/install.sh" | PROFILE=/dev/null bash
  load_nvm
  nvm install "$NODE_MAJOR"
  nvm alias default "$NODE_MAJOR"
}

on_update() {
  [ -s "$NVM_DIR/nvm.sh" ] || { echo "nvm is not installed, skipping"; return; }
  # nvm is a Git checkout: move it forward to its newest release tag that is old enough, never back
  local tags newest_tag
  git -C "$NVM_DIR" fetch --tags --quiet
  tags="$(git -C "$NVM_DIR" for-each-ref --sort=-creatordate --format='%(creatordate:unix) %(refname:short)' \
    'refs/tags/v[0-9]*')"
  newest_tag="$(awk -v cutoff="$(release_cutoff)" '$1 <= cutoff { print $2; exit }' <<< "$tags")"
  if [ -n "$newest_tag" ] && git -C "$NVM_DIR" merge-base --is-ancestor HEAD "$newest_tag"; then
    git -C "$NVM_DIR" -c advice.detachedHead=false checkout --quiet "$newest_tag"
  fi
  load_nvm
  local current latest version
  current="$(nvm version default)"
  latest="$(nvm version-remote "$NODE_MAJOR")"
  if [ "$current" = "$latest" ]; then
    # nvm refuses to reinstall packages from the version it is installing, so there is nothing to do
    echo "Node $current is up to date"
  elif [ "$current" = N/A ]; then
    nvm install "$NODE_MAJOR"
  else
    # Carry over the global npm packages
    nvm install "$NODE_MAJOR" --reinstall-packages-from=default
  fi
  nvm alias default "$NODE_MAJOR"
  # nvm refuses to remove the active version, which a parent shell's PATH can make one of the old ones, so switch to
  # the newest first
  nvm use --silent "$latest"
  for version in "$NVM_DIR/versions/node/v$NODE_MAJOR".*; do
    version="${version##*/}"
    [ "$version" = "$latest" ] || nvm uninstall "$version"
  done
}

on_sources() {
  local tag
  tag="$(nvm_tag)" || true
  check "nvm installer (release: ${tag:-not found})" \
    url_exists "https://raw.githubusercontent.com/nvm-sh/nvm/${tag:-missing}/install.sh"
}

component_main "$@"
