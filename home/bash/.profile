# shellcheck shell=sh
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Added by Toolbox App
if [ -d "$HOME/.local/share/JetBrains/Toolbox/scripts" ] ; then
    PATH="$PATH:$HOME/.local/share/JetBrains/Toolbox/scripts"
fi

# Homebrew and the default Node. .bashrc stops early unless the shell is interactive, and the GNOME session and
# the apps it starts get their PATH from a login shell that is not, so load the same files for them here.
case $- in
    *i*) ;;
    *)
        for rc in 00-cache brew nvm; do
            if [ -r "$HOME/.bashrc.d/$rc.sh" ]; then
                # shellcheck source=/dev/null
                . "$HOME/.bashrc.d/$rc.sh"
            fi
        done
        unset rc
        ;;
esac
