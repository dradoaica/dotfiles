# shellcheck shell=bash
# Helpers shared by the scripts in scripts/. Source it; it sets ROOT_DIR to the repository.

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

# github_release <owner/repo>: print, as JSON, the newest release of a repository that is at least 7 days old,
# leaving out drafts and pre-releases, or nothing when there is none. A release published from a maintainer's
# hijacked account then has a week to be noticed and withdrawn before it is installed here.
# Set GITHUB_RELEASE_MIN_AGE_DAYS to change the wait; 0 gives the newest release.
github_release() {
  github_api "repos/$1/releases?per_page=30" | jq -c --argjson days "${GITHUB_RELEASE_MIN_AGE_DAYS:-7}" '
    [.[] | select((.draft or .prerelease) | not)
         | select((.published_at | fromdateiso8601) <= now - $days * 86400)]
    | sort_by(.published_at) | last // empty'
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

# The upgrades that packages.sh and update.sh both run
upgrade_apt() {
  sudo apt-get update
  sudo apt-get upgrade -y --with-new-pkgs
}
upgrade_snaps() { sudo snap refresh; }
upgrade_flatpaks() { sudo flatpak update -y; }

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
