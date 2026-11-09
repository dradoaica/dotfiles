# shellcheck shell=bash
# Keep the history in ~/.local/state/bash/history, not ~/.bash_history. Ubuntu's .bashrc sets HISTFILESIZE=2000
# before this file runs, and bash cuts the history file down to that size the moment the variable is set, so every
# new terminal would trim ~/.bash_history back to 2000 lines. Pointing HISTFILE elsewhere after that keeps the file
# out of its reach. The first time, the old history is copied over (trimmed already, by the same .bashrc).
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/bash/history"
if [ ! -e "$HISTFILE" ]; then
  mkdir -p "${HISTFILE%/*}"
  if [ -f ~/.bash_history ]; then
    cp ~/.bash_history "$HISTFILE"
  fi
fi

# Keep more history than Ubuntu's default of 1000 commands (2000 in the file)
HISTSIZE=50000
HISTFILESIZE=100000

# Write each command to the history file as soon as it runs, not only when the shell exits, so a closed or
# crashed terminal loses nothing and new terminals (and fzf's Ctrl+R) see it. PROMPT_COMMAND is an array
# (bash 5.1+), so this keeps whatever else, such as the terminal's own hook, is already in it.
if [[ " ${PROMPT_COMMAND[*]} " != *" history -a "* ]]; then
  PROMPT_COMMAND+=('history -a')
fi
