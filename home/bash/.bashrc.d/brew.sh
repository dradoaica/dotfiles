# shellcheck shell=bash
# Homebrew
for brew in /home/linuxbrew/.linuxbrew/bin/brew ~/.linuxbrew/bin/brew; do
  if [ -x "$brew" ]; then
    cached_eval brew-shellenv "$brew" "$brew" shellenv
    break
  fi
done
unset brew
