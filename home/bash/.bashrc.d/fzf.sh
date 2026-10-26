# shellcheck shell=bash
# fzf: Ctrl+R fuzzy-searches the history, Ctrl+T inserts a file path, Alt+C changes into a directory
if command -v fzf > /dev/null; then
  eval "$(fzf --bash)"
fi
