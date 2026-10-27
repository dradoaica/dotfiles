# shellcheck shell=bash
# Keep more history than Ubuntu's default of 1000 commands (2000 in the file)
HISTSIZE=50000
HISTFILESIZE=100000

# Write each command to the history file as soon as it runs, not only when the shell exits, so a closed or
# crashed terminal loses nothing and new terminals (and fzf's Ctrl+R) see it. PROMPT_COMMAND is an array
# (bash 5.1+), so this keeps whatever else, such as the terminal's own hook, is already in it.
if [[ " ${PROMPT_COMMAND[*]} " != *" history -a "* ]]; then
  PROMPT_COMMAND+=('history -a')
fi
