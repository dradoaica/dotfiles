# shellcheck shell=bash
# Completions that Ubuntu's bash-completion does not find on its own (brew.sh sets HOMEBREW_PREFIX first)
if [ -n "${HOMEBREW_PREFIX:-}" ]; then
  for completion in "$HOMEBREW_PREFIX"/etc/bash_completion.d/*; do
    # shellcheck source=/dev/null
    [ -r "$completion" ] && . "$completion"
  done
  unset completion
fi
if command -v gh > /dev/null; then
  eval "$(gh completion -s bash)"
fi
