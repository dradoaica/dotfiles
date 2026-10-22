# shellcheck shell=bash
# Homebrew
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x ~/.linuxbrew/bin/brew ]; then
  eval "$(~/.linuxbrew/bin/brew shellenv)"
fi
