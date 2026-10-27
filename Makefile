# Shortcuts for the scripts in scripts/. Run `make` to list them.

SHELL := /bin/bash
SCRIPTS := scripts/*.sh home/bash/.bashrc.d/*.sh home/bash/.profile

.DEFAULT_GOAL := help
.PHONY: help install update packages link unlink check doctor extensions load dump lint sources drift

help: ## List the available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-11s %s\n", $$1, $$2}'

install: ## Set up everything: packages, links, GNOME extensions and settings
	bash scripts/install.sh

update: ## Update packages, firmware, Docker Desktop, GitHub-release apps, Homebrew, pipx, extensions, Rust, Node
	bash scripts/update.sh

packages: ## Add the repositories and install the packages
	bash scripts/packages.sh

link: ## Symlink the dotfiles in home/ into ~ (backs up replaced files)
	bash scripts/link.sh

unlink: ## Remove the symlinks (the files stay in the repository)
	bash scripts/link.sh --unlink

check: ## Report dotfiles that are not linked
	bash scripts/link.sh --check

doctor: ## Check that this machine is still set up the way the installer left it
	bash scripts/doctor.sh

extensions: ## Install the GNOME extensions in gnome/extensions.txt
	bash scripts/gnome.sh extensions

load: ## Apply the GNOME settings and app settings saved in gnome/ and apps/
	bash scripts/gnome.sh load
	bash scripts/apps.sh load

dump: ## Save the current GNOME extensions, GNOME settings and app settings into the repository
	bash scripts/gnome.sh dump
	bash scripts/apps.sh dump
	bash scripts/drift.sh

drift: ## Report what is installed but not listed in packages/
	bash scripts/drift.sh

sources: ## Check that the PPAs, repositories and downloads the installer uses still work
	bash scripts/check-sources.sh

lint: ## Run shellcheck on the scripts
	shellcheck $(SCRIPTS)
