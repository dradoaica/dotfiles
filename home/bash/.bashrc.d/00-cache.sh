# shellcheck shell=bash
# cached_eval <name> <program> <command...>: load the output of a command that prints shell code (like
# `brew shellenv` or `fzf --bash`), cached in ~/.cache/bashrc/<name>.sh instead of run in every new shell.
# The cache is rebuilt when the program is newer than it, e.g. after an upgrade. Loaded first (00-).
cached_eval() {
  local name="$1" program cache
  program="$(command -v "$2")" || return 0
  shift 2
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/bashrc/$name.sh"
  if [ ! -s "$cache" ] || [ "$program" -nt "$cache" ]; then
    mkdir -p "${cache%/*}"
    if ! "$@" > "$cache.tmp" 2> /dev/null; then
      rm -f "$cache.tmp"
      return 0
    fi
    mv "$cache.tmp" "$cache"
  fi
  # shellcheck source=/dev/null
  . "$cache"
}
