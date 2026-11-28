# shellcheck shell=bash
# Helpers shared by the scripts in scripts/ and scripts/components/. Source it; it sets ROOT_DIR to the repository.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Installed before anything else: what packages.sh needs to add the other sources
# shellcheck disable=SC2034 # used by the scripts that source this file
PREREQUISITES=(curl flatpak jq software-properties-common stow wget)

# list_entries <file>: print the entries of a list, without comments and blank lines
list_entries() {
  grep -vE '^[[:space:]]*(#|$)' "$1" | sed -E 's/[[:space:]]+#.*$//'
}

# Print the entries of a list in packages/
read_list() {
  list_entries "$ROOT_DIR/packages/$1"
}

# replace <text> <replacement>: copy stdin to stdout with every <text> replaced, both taken literally
replace() {
  local text
  # The x keeps the newlines at the end, which $(...) would drop
  text="$(cat; printf x)"
  text="${text%x}"
  printf '%s' "${text//"$1"/"$2"}"
}

# Print the APT preferences that keep each PPA in packages/ppas.txt to its own packages. Everything a PPA offers
# gets priority 100, below the 500 of Ubuntu's archive: it can still be installed when nothing else provides it,
# but never replaces a package from Ubuntu. Only the packages listed after the PPA keep priority 500.
ppa_preferences() {
  local ppa packages origin
  echo "# Written by scripts/packages.sh from packages/ppas.txt; changes made here are overwritten"
  while read -r ppa packages; do
    # Launchpad names the origin LP-PPA-<owner>-<name>, without the name when it is "ppa"
    origin="${ppa#ppa:}"
    origin="LP-PPA-${origin%/ppa}"
    origin="${origin//\//-}"
    printf '\nPackage: *\nPin: release o=%s\nPin-Priority: 100\n' "$origin"
    [ -z "$packages" ] || printf '\nPackage: %s\nPin: release o=%s\nPin-Priority: 500\n' "$packages" "$origin"
  done < <(read_list ppas.txt)
}

# Put Homebrew on PATH for this script; fails if it is not installed
load_homebrew() {
  # Homebrew 7 asks before `brew install` and `brew upgrade` by default; scripts must not stop for that.
  # (Older versions ignore the variable, but would reject a --yes flag.)
  export HOMEBREW_NO_ASK=1
  # The shell that started this script may have loaded it already
  ! command -v brew > /dev/null || return 0
  local brew
  for brew in /home/linuxbrew/.linuxbrew/bin/brew ~/.linuxbrew/bin/brew; do
    if [ -x "$brew" ]; then
      eval "$("$brew" shellenv)"
      return 0
    fi
  done
  return 1
}

# github_api <path>: print the GitHub API response for a path such as repos/nvm-sh/nvm/releases/latest.
# Uses GITHUB_TOKEN when it is set, which raises the rate limit that shared CI runners can otherwise hit.
github_api() {
  local auth=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  curl -fsSL "${auth[@]}" "https://api.github.com/$1"
}

# What the installer downloads from outside Ubuntu's archive and the PPAs (GitHub releases, nvm, the Homebrew
# installer, Docker Desktop, JetBrains Toolbox) is only installed once it is this many days old. A release published
# from a maintainer's hijacked account then has a week to be noticed and withdrawn before it is installed here.
# Set RELEASE_MIN_AGE_DAYS to change the wait; 0 installs the newest release.
RELEASE_MIN_AGE_DAYS="${RELEASE_MIN_AGE_DAYS:-7}"

# Print the time, in seconds since 1970, that a release must have been published by to be installed
release_cutoff() {
  echo "$(($(date +%s) - RELEASE_MIN_AGE_DAYS * 86400))"
}

# github_release <owner/repo>: print, as JSON, the newest release of a repository that is at least
# RELEASE_MIN_AGE_DAYS old, leaving out drafts and pre-releases, or nothing when there is none
github_release() {
  github_api "repos/$1/releases?per_page=30" | jq -c --argjson cutoff "$(release_cutoff)" '
    [.[] | select((.draft or .prerelease) | not)
         | select((.published_at | fromdateiso8601) <= $cutoff)]
    | sort_by(.published_at) | last // empty'
}

# github_commit <owner/repo> <path>: print the ID of the newest commit that changed a file and is at least
# RELEASE_MIN_AGE_DAYS old, or nothing when there is none. For installers that are published from a branch rather
# than as releases, such as Homebrew's.
github_commit() {
  local until
  until="$(date -u -d "@$(release_cutoff)" +%Y-%m-%dT%H:%M:%SZ)"
  github_api "repos/$1/commits?path=$2&until=$until&per_page=1" | jq -r '.[0].sha // empty'
}

# differences <saved folder> <folder>: print what differs between the saved files and the same files as they are
# on this machine now, as a diff without the lines around each change; fails when there are differences
differences() {
  local changes links
  links="$(mktemp -d)"
  # Through links, so the diff names the files saved/... and now/... instead of by their full paths
  ln -s "$1" "$links/saved"
  ln -s "$2" "$links/now"
  if changes="$(cd "$links" && diff -r -U0 saved now)"; then
    rm -rf "$links"
    return 0
  fi
  rm -rf "$links"
  # Without the command diff prints for each file, and the time after each file name
  sed -E '/^diff /d; s/^((---|\+\+\+) [^\t]*)\t.*/\1/' <<< "$changes"
  echo "Save these changes with \`make dump\`, or undo them with \`make load\`" >&2
  return 1
}

failed_checks=0
# check <description> <command...>: run the command quietly and print "ok" or "FAIL" for it, with the command's
# output indented below a failure so it says why. Count failures in failed_checks instead of stopping, so every
# check runs.
check() {
  local description="$1" output
  shift
  if output="$("$@" 2>&1)"; then
    echo "ok    $description"
  else
    echo "FAIL  $description"
    [ -z "$output" ] || echo "        ${output//$'\n'/$'\n'        }"
    failed_checks=$((failed_checks + 1))
  fi
}

# apt_get <arguments...>: run apt-get as root without stopping for a question. sudo leaves DEBIAN_FRONTEND out of the
# environment it passes on, so it is given on the command line. dpkg still asks what to do with a config file that was
# changed here when the package brings a new one, even then: keep the changed file, and take the new one only when the
# file was not changed.
apt_get() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"
}

# The upgrade that packages.sh and update.sh both run
upgrade_apt() {
  apt_get update
  apt_get upgrade -y --with-new-pkgs
}

failed_steps=()
# step <name> <function>: run a step in a subshell with `set -e` in force (it would be ignored if the step
# ran as an `if` or `||` condition), and remember it if it fails instead of stopping
step() {
  local name="$1" status
  shift
  echo "== $name"
  set +e
  (set -e; "$@")
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    echo "!! $name failed (exit code $status)" >&2
    failed_steps+=("$name")
  fi
}

# start_log <name>: also write everything the script prints to ~/.local/state/dotfiles/<name>-<time>.log, so the
# errors of a long run can still be read after they scroll away. A script started by one that already logs, like
# packages.sh by install.sh, writes to the same log. Keeps the 10 newest logs of each name.
log_started=false
start_log() {
  [ -z "${DOTFILES_LOG:-}" ] || return 0
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  install -d -m 0700 "$dir"
  find "$dir" -maxdepth 1 -name "$1-*.log" -printf '%f\n' | sort -r | tail -n +10 | sed "s|^|$dir/|" \
    | xargs -r rm -f --
  DOTFILES_LOG="$dir/$1-$(date +%Y%m%d-%H%M%S).log"
  export DOTFILES_LOG
  exec > >(tee -a "$DOTFILES_LOG") 2>&1
  log_pid=$!
  log_started=true
  # Wait for tee to write the last lines, so the log is complete and the prompt does not come back before them
  trap 'exec >&- 2>&-; wait "$log_pid"' EXIT
}

# finish <message>: print the message, or list the failed steps and exit with an error
finish() {
  if [ "${#failed_steps[@]}" -gt 0 ]; then
    echo "Done, but these steps failed: ${failed_steps[*]}. Scroll up for their errors." >&2
    [ "$log_started" = false ] || echo "The whole output is saved in $DOTFILES_LOG" >&2
    exit 1
  fi
  echo "$1"
  [ "$log_started" = false ] || echo "The whole output is saved in $DOTFILES_LOG"
}

# deb_installed <package>: succeed when an APT package is installed
deb_installed() { dpkg-query -W -f='${Status}' "$1" 2> /dev/null | grep -q 'install ok installed'; }
deb_not_installed() { ! deb_installed "$1"; }

# all_installed <list in packages/> <command printing what is installed>: every entry of the list must be among
# them. The first word of an entry is its name, without the options before it or the tap it comes from.
all_installed() {
  local list="$1" installed_names name missing=0
  shift
  installed_names="$("$@")" || return 1
  while read -r name; do
    grep -qxF "$name" <<< "$installed_names" || { echo "not installed: $name" >&2; missing=1; }
  done < <(read_list "$list" | sed -E 's/^--[a-z]+[[:space:]]+//' | awk '{ print $1 }' | sed 's|.*/||')
  return "$missing"
}

# install_each <list in packages/> <command...>: run the command once for each entry of the list, with the words of
# the entry after it (an entry can carry options, such as `code --classic`). Carries on past an entry that fails, and
# fails at the end, naming them.
install_each() {
  local list="$1" entry words missing=()
  shift
  while read -r entry; do
    read -r -a words <<< "$entry"
    # From /dev/null, so the command cannot read the rest of the list
    "$@" "${words[@]}" < /dev/null || missing+=("$entry")
  done < <(read_list "$list")
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Could not install: ${missing[*]}" >&2
    return 1
  fi
}

# download_verified <URL> <SHA-256> <file>: download a file and check it against its SHA-256; a file that does not
# match is removed
download_verified() {
  curl -fL --retry 2 "$1" -o "$3" || return 1
  echo "$2  $3" | sha256sum --check --quiet || { rm -f "$3"; return 1; }
}

# install_deb <URL> <SHA-256>: download a .deb, check it against its SHA-256 and install it with its dependencies
install_deb() {
  local dir status=0
  dir="$(mktemp -d)"
  # apt runs as _apt and must be able to read the download
  chmod 755 "$dir"
  if download_verified "$1" "$2" "$dir/package.deb"; then
    chmod 644 "$dir/package.deb"
    apt_get install -y "$dir/package.deb" || status=$?
  else
    status=1
  fi
  rm -rf "$dir"
  return "$status"
}

# curl retries a rate limit (HTTP 429), a server error and a connection that fails before the server answers, waiting
# longer each time (1, 2, 4... seconds, or as long as the server asks). The Snap Store has both rate-limited the source
# checks and closed the TLS handshake when many of them run in a row. A server that stops answering fails the check
# instead of holding up the others.
CURL_RETRY=(--retry 5 --retry-all-errors --retry-max-time 120 --max-time 60)

# url_found <curl arguments...>: succeed when the server answers with a 2xx status. Not with --fail, which would make
# --retry-all-errors retry a 404 too, though that answer means the source is gone.
url_found() {
  local status
  status="$(curl -sSL "${CURL_RETRY[@]}" -o /dev/null -w '%{http_code}' "$@")" || return
  if [[ "$status" != 2?? ]]; then
    echo "The server answered with HTTP $status" >&2
    return 1
  fi
}

# url_exists <URL>: url_found, fetching only the first byte, so large files are not downloaded
url_exists() { url_found --range 0-0 "$1"; }

# Each tool the installer sets up besides the packages in packages/ (Docker Desktop, Node, IDplug...) is one script
# in scripts/components/, which does everything for it. It sets TITLE, the name its output is headed with, and defines
# a function for each action it has something to do for, leaving out the others:
#   on_install  set it up (packages.sh)
#   on_update   update it (update.sh)
#   on_sources  check, with `check`, that what it downloads can still be found (check-sources.sh)
#   on_doctor   check, with `check`, that this machine is still set up the way on_install left it (doctor.sh)
#   on_tracked  print the packages it installs as <manager>:<name>, so drift.sh does not report them
# It ends with `component_main "$@"`. Every script in the folder must be listed here (tests/components.sh checks): they
# run in this order, which is also the order they are installed in, so each comes after the ones it needs.
COMPONENTS_DIR="$ROOT_DIR/scripts/components"
COMPONENTS=(
  snaps flatpaks
  rust node homebrew jetbrains-toolbox
  docker-desktop docker-credentials kubernetes
  clamav udev
  openlogi github-debs wayland-scroll-factor craft-apps idplug
  firmware pipx
)
COMPONENT_ACTIONS=(install update sources doctor tracked)

# run_components <action>: run that action of every component that has one. install and update run as steps; sources
# and doctor add the component's failed checks to failed_checks. A component listed but missing counts as a failure.
run_components() {
  local action="$1" name file description title status
  for name in "${COMPONENTS[@]}"; do
    file="$COMPONENTS_DIR/$name.sh"
    # Its title, then the actions it defines
    if ! description="$(bash "$file" describe 2>&1)"; then
      echo "!! Component $name failed to describe itself: $description" >&2
      failed_steps+=("$name")
      failed_checks=$((failed_checks + 1))
      continue
    fi
    title="$(head -1 <<< "$description")"
    grep -qx "$action" <<< "$(tail -n +2 <<< "$description")" || continue
    case "$action" in
      install | update) step "$title" bash "$file" "$action" ;;
      sources | doctor)
        echo "== $title"
        status=0
        bash "$file" "$action" || status=$?
        failed_checks=$((failed_checks + status))
        ;;
      *) bash "$file" "$action" ;;
    esac
  done
}

# component_main <action>: what every component script ends with: run its on_<action> function. sources and doctor
# run without `set -e`, as doctor.sh does, so a command that fails cannot stop the checks after it, and exit with the
# number of checks that failed. `describe` prints TITLE, then the actions the script defines, one per line.
component_main() {
  local action
  case "${1:-}" in
    describe)
      [ -n "${TITLE:-}" ] || { echo "$0 sets no TITLE" >&2; exit 1; }
      echo "$TITLE"
      for action in "${COMPONENT_ACTIONS[@]}"; do
        ! declare -F "on_$action" > /dev/null || echo "$action"
      done
      exit 0
      ;;
    install | update | sources | doctor | tracked) ;;
    *) echo "Usage: $(basename "$0") $(IFS='|'; echo "${COMPONENT_ACTIONS[*]}")" >&2; exit 1 ;;
  esac
  declare -F "on_$1" > /dev/null || exit 0
  case "$1" in
    sources | doctor)
      set +e
      "on_$1"
      exit "$failed_checks"
      ;;
  esac
  "on_$1"
}
