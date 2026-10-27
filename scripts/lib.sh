# shellcheck shell=bash
# Helpers shared by the scripts in scripts/. Source it; it sets ROOT_DIR to the repository.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Installed before anything else: what packages.sh needs to add the other sources
# shellcheck disable=SC2034 # used by the scripts that source this file
PREREQUISITES=(curl flatpak jq software-properties-common stow wget)

# Print the entries of a list in packages/, without comments and blank lines
read_list() {
  grep -vE '^[[:space:]]*(#|$)' "$ROOT_DIR/packages/$1" | sed -E 's/[[:space:]]+#.*$//'
}

# Put Homebrew on PATH for this script; fails if it is not installed
load_homebrew() {
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

failed_checks=0
# check <description> <command...>: run the command quietly and print "ok" or "FAIL" for it.
# Count failures in failed_checks instead of stopping, so every check runs.
check() {
  local description="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "ok    $description"
  else
    echo "FAIL  $description"
    failed_checks=$((failed_checks + 1))
  fi
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

# finish <message>: print the message, or list the failed steps and exit with an error
finish() {
  if [ "${#failed_steps[@]}" -gt 0 ]; then
    echo "Done, but these steps failed: ${failed_steps[*]}. Scroll up for their errors." >&2
    exit 1
  fi
  echo "$1"
}
