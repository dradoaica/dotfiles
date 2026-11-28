# Dotfiles

[![CI](https://github.com/dradoaica/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/dradoaica/dotfiles/actions/workflows/ci.yml)

Scripts and settings for turning a fresh **Ubuntu Desktop 26.04 (minimal installation, amd64)** into a complete
development workstation, and for keeping it that way.

- [Before You Run](#before-you-run)
- [Quick Start](#quick-start)
- [What's Included](#whats-included)
- [How It Is Organised](#how-it-is-organised)
- [Day to Day](#day-to-day)
- [Testing](#testing)
- [Post-Install](#post-install)
- [Troubleshooting](#troubleshooting)
- [Further Reading](#further-reading)
- [License](#license)

## Before You Run

`scripts/install.sh` makes system-wide changes and replaces some of your configuration files. It:

- Targets **Ubuntu 26.04 on amd64 only**, needs `sudo`, runs a full `apt-get upgrade`, and takes a while.
- Adds third-party APT sources: the PPAs in [`packages/ppas.txt`](packages/ppas.txt), each kept to the packages listed
  next to it so it cannot replace one of Ubuntu's, and the repositories in
  [`packages/repositories.txt`](packages/repositories.txt), each trusted with its own signing key.
- Installs apps from downloads outside Ubuntu and the PPAs (GitHub releases, Docker Desktop, JetBrains Toolbox, nvm,
  the Homebrew installer, IDplug Classic), each checked against a published or pinned SHA-256. Each is only installed
  once it is **7 days old**, so a release published from a hijacked account has time to be withdrawn; set
  `RELEASE_MIN_AGE_DAYS` to change that (`0` installs the newest).
- Replaces `~/.bashrc`, `~/.profile`, the Git config and the other files under [`home/`](home) with symlinks into this
  repository, moving the files it replaces to `~/.dotfiles-backup/<timestamp>/`.
- Overwrites your GNOME settings and extensions with the ones saved in [`gnome/`](gnome), and some app settings with
  the ones in [`app-settings/`](app-settings).
- Removes LibreOffice (the Craft apps replace it) and Solaar (OpenLogi does not work alongside it).
- Enables the Git hooks in [`.githooks/`](.githooks): gitleaks checks each commit for secrets, and `make lint test`
  runs before each push.

It runs in steps. A step that fails does not stop the others: the failed ones are listed at the end, so you can fix
them and run it again, which is safe. The whole output is saved in `~/.local/state/dotfiles/`. Each script starts with
a comment saying what it does and why; read them before you run it.

## Quick Start

On a fresh machine, one command installs Git if needed, clones this repository to `~/Projects/dotfiles` and runs the
installer ([`scripts/bootstrap.sh`](scripts/bootstrap.sh); set `DOTFILES_DIR` to clone elsewhere):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dradoaica/dotfiles/main/scripts/bootstrap.sh)
```

Or clone it yourself and run the installer:

```bash
git clone https://github.com/dradoaica/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
bash scripts/install.sh
```

Keep the clone where it is afterwards: the symlinks point into it. When the installer finishes, **log out and back
in** so the new group memberships, fonts and GNOME extensions take effect, then work through
[Post-Install](#post-install).

## What's Included

The lists in [`packages/`](packages) are the full, current list; this is an overview.

- **Development**: Python, Go, Rust (rustup), Java, .NET 10, C/C++ (GCC and Clang), PHP, Ruby and Node.js (nvm); VS
  Code, JetBrains Toolbox, GitKraken, the GitHub CLI and Claude Code.
- **Containers and Kubernetes**: Docker Desktop (not started at login: start it from the app menu, and it opens in
  the tray), MicroK8s (stopped until you run `microk8s start`), Multipass, kubectl, Helm and K9s.
- **Apps**: Chrome and Firefox, media and screenshot tools, CD/DVD burning, a BitTorrent client, backups (Déjà Dup),
  antivirus (ClamAV, scanning on demand), Ulauncher, balenaEtcher, ArtCraft Launcher (for the Craft office and image
  editors) and Steam.
- **Hardware**: OpenLogi for Logitech devices, OpenRazer and Polychromatic for Razer, Galaxy Buds Client, Wayland
  Scroll Factor for touchpad scrolling, and udev rules that let the Rapoo and Keychron web drivers reach their devices.
- **Electronic ID**: IDplug Classic for the Romanian electronic identity card, set up in Chrome and Firefox.
- **GNOME**: the extensions in [`gnome/extensions.txt`](gnome/extensions.txt) (ArcMenu, Dash to Panel, Tiling Shell
  and others), the Inter and JetBrains Mono fonts, and the Bibata, Phinger and Breeze cursors.

Not automated, because they need you to answer prompts: proprietary drivers and commit signing (see
[Post-Install](#post-install)).

## How It Is Organised

| Folder                | What it holds                                                                              |
|-----------------------|--------------------------------------------------------------------------------------------|
| `home/`               | Dotfiles, one folder per program, linked into `~` with GNU Stow.                           |
| `packages/`           | What to install: one list per package manager, and the APT sources.                        |
| `gnome/`              | The saved GNOME extensions and settings (`dconf` dumps).                                   |
| `app-settings/`       | App settings that cannot be symlinked: OpenLogi, Claude Code, default apps, VS Code, Helm. |
| `system/`             | Files for `/etc`, which cannot be symlinked from `home/` (udev rules).                     |
| `scripts/`            | The installer and the `make` targets; shared helpers are in `lib.sh`.                      |
| `scripts/components/` | One script per tool beyond the package lists, such as Docker Desktop or Node.              |
| `tests/`              | Tests for the scripts, which never touch your own settings.                                |

The scripts in `scripts/` that act on the whole machine each do their own part and then the same for every component:
`packages.sh` installs, `update.sh` updates, `doctor.sh` checks the machine, `check-sources.sh` checks the downloads
and `drift.sh` lists what is installed but not tracked. A component script does all five for its tool, so everything
about Docker Desktop, say, is in [`scripts/components/docker-desktop.sh`](scripts/components/docker-desktop.sh). The
order they run in is `COMPONENTS` in [`scripts/lib.sh`](scripts/lib.sh), which also describes what a component
defines.

[`scripts/migrations.sh`](scripts/migrations.sh) undoes what earlier versions set up and the current one no longer
does, so an older machine ends up like a fresh install.

## Day to Day

Run `make` to list every target.

| Command         | What it does                                                                                       |
|-----------------|----------------------------------------------------------------------------------------------------|
| `make update`   | Updates every package, tool, firmware and GNOME extension, cleans up, then runs `make doctor`.     |
| `make doctor`   | Checks, changing nothing, that the machine is as the installer left it and every setting is saved. |
| `make dump`     | Saves the current GNOME extensions and settings, and the app settings, into the repository.        |
| `make load`     | Applies the saved GNOME and app settings.                                                          |
| `make drift`    | Lists what is installed but not in `packages/`, so a fresh install would miss it.                  |
| `make check`    | Lists the dotfiles that are not linked, or linked to a file no longer in the repository.           |
| `make link`     | Links the dotfiles, fixing what `make check` reports. `make unlink` removes the links.             |
| `make packages` | Adds the sources and installs everything, the first part of `make install`.                        |
| `make sources`  | Checks that every source and download the installer uses still works.                              |
| `make signing`  | Sets up commit signing (see [Post-Install](#post-install)).                                        |

### Changing the Setup

- **Edit a dotfile** in place, in `~` or in the repository: they are the same file. Commit the change.
- **Track another dotfile** by moving it into the matching folder of `home/` (or a new one), then linking it:

  ```bash
  mkdir -p home/k9s/.config/k9s
  mv ~/.config/k9s/views.yaml home/k9s/.config/k9s/
  bash scripts/link.sh k9s
  ```

- **Install an app** by adding it to the matching list in [`packages/`](packages), then running `make packages`. Run
  `make drift` now and then to catch what you installed by hand; add each one to its list, or to
  [`packages/ignore.txt`](packages/ignore.txt) to stop it being reported.
- **Add a tool** that needs more than a package list by copying a script in `scripts/components/`, keeping the actions
  it needs, and adding its name to `COMPONENTS` in `scripts/lib.sh`.
- **Change GNOME or app settings** in their own preferences, then run `make dump`, review `git diff` and commit.
  `make doctor` reports settings that changed and were not saved.
- **Add to the shell** in a new file in `home/bash/.bashrc.d/`, not in `.bashrc`, which stays as Ubuntu ships it. For a
  program that prints shell code to load (like `fzf --bash`), use `cached_eval` from `00-cache.sh`, which keeps new
  shells fast. `.profile` loads Homebrew and Node for the GNOME session too.

### Machine-Specific Settings

Keep anything private or specific to one machine out of the repository, which is public:

- **Shell**: put it in an extra file in `~/.bashrc.d/`, for example `~/.bashrc.d/local.sh`. Every `*.sh` file there is
  loaded, but only the ones in `home/bash/.bashrc.d/` are tracked.
- **Git**: put it in `~/.config/git/config.local` (a work email; `make signing` writes its settings there too). The Git
  config includes it. `git config --global` writes through the symlink into the repository, so use
  `git config --file ~/.config/git/config.local` instead.
- **Claude Code**: only the settings listed in `CLAUDE_SAVED_KEYS` in
  [`scripts/app-settings.sh`](scripts/app-settings.sh) are saved; anything else in `~/.claude/settings.json`, such as
  a token, stays on the machine.

### The Shell

<kbd>Ctrl</kbd>+<kbd>R</kbd> searches the history with [fzf](https://github.com/junegunn/fzf),
<kbd>Ctrl</kbd>+<kbd>T</kbd> inserts a file path and <kbd>Alt</kbd>+<kbd>C</kbd> changes into a directory. ↑ and ↓
search the history for what you have typed, and Tab completion ignores case. The history keeps 100,000 commands in
`~/.local/state/bash/history`, and each command is saved as soon as it runs, so new terminals see it.

## Testing

[CI](.github/workflows/ci.yml) runs on every push to `main`, every pull request and every Monday, in an Ubuntu 26.04
container:

- **sources** (`make sources`): every PPA, repository, download and listed package can still be found. The weekly run
  catches a source that broke while nothing here changed.
- **packages**: apt can install everything in `apt.txt` together from those sources (`packages.sh --simulate`).
- **lint** (`make lint`): shellcheck on every script.
- **link**: the dotfiles link into a fresh home directory and unlink again, and the shells they set up start.
- **test** (`make test`): the tests in [`tests/`](tests), each in a private home directory and settings database.
- **secrets**: gitleaks over the whole history, behind the pre-commit hook.

The pre-push hook runs `make lint test` too, since `main` is pushed to directly. Dependabot keeps the pinned GitHub
Actions up to date.

## Post-Install

### GitHub CLI

Sign in once. The Git config already uses the GitHub CLI's credentials for github.com, so `git push` over HTTPS then
works without a separate token, and you do not need `gh auth setup-git`:

```bash
gh auth login
```

### Commit Signing

Sign your commits and tags with an SSH key, so GitHub shows them as Verified. Run this once on each machine, after
signing in to the GitHub CLI:

```bash
make signing
```

It creates `~/.ssh/id_ed25519` if you do not have one (it asks for a passphrase), asks you in the browser to let the
GitHub CLI manage signing keys, adds the key to your GitHub account as a signing key, and writes the Git settings to
`~/.config/git/config.local`. Git signs through GNOME's SSH agent, which asks for the key's passphrase in a dialog the
first time after you log in, so commits from IDEs are signed too. Running it again skips what is already done.

### Ulauncher Hotkey on Wayland

On Wayland, Ulauncher does not receive its hotkey while some windows are focused (e.g. Terminal or Settings), so it
is bound through GNOME instead. `gnome.sh load` restores this as a custom shortcut (<kbd>Ctrl</kbd>+<kbd>Space</kbd> →
`ulauncher-toggle`), and the linked Ulauncher settings move Ulauncher's own hotkey to
<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Super</kbd>+<kbd>F12</kbd>, so the two never both fire. To set it up by hand:

1. In Ulauncher Preferences, set the hotkey to something you will never press.
2. Open **Settings > Keyboard > View and Customize Shortcuts > Custom Shortcuts** and click **Add Shortcut**.
3. Set the command to `ulauncher-toggle`, choose a name and shortcut, then click **Add**.

### Proprietary Drivers

```bash
# Show devices that need drivers and the packages that apply
sudo ubuntu-drivers devices

# Show all driver packages that apply to this system
sudo ubuntu-drivers list

# Install a specific driver: driver[:version][,driver[:version]]
sudo ubuntu-drivers install nvidia-driver-595-open
```

## Troubleshooting

### A Flatpak App Does Not Start

If an app fails after an interrupted update or a full disk, check and fix the Flatpak installation:

```bash
sudo flatpak repair
```

### The Browser Does Not See the Electronic ID Card

IDplug Manager shows the card's certificates, but the browsers only see them through the module that
[`scripts/components/idplug.sh`](scripts/components/idplug.sh) adds for them; `make doctor` checks it for both. For
Chrome, with the card in the reader, check that the module is in `~/.pki/nssdb` and lists the card's tokens:

```bash
modutil -dbdir sql:$HOME/.pki/nssdb -list "IDEMIA IDPlug"
```

In Firefox, open **Settings > Privacy & Security > Security Devices**: "IDEMIA IDPlug" should be there, with the
card's tokens under it. Because of the policy that adds it, Firefox shows "Your browser is being managed by your
organization" in its settings.

If either is missing, run `bash scripts/components/idplug.sh install`. Then quit the browser completely and start it
again.

When a site asks for a certificate, choose the one ending in "(Autentificare)", from the **PKI Application** token,
and enter the card's 4-digit User PIN; the other two tokens are for signing. The card locks after a few wrong PINs.

If hub.mai.gov.ro answers "A apărut o eroare la autentificare, cod eroare: …" after you choose the certificate and
enter the PIN, the browser did send the certificate: the code changes on every attempt and does not say what went
wrong. Quit the browser completely and try again later. If it keeps failing, write to suport.hub@mai.gov.ro with the
code and screenshots.

### Login Screen Uses the Wrong Monitor Layout

GNOME has no setting for the login screen layout
([upstream issue](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/2185)). Copy your own monitor
configuration to it instead:

```bash
sudo cp ~/.config/monitors.xml /var/lib/gdm3/seat0/config/
sudo chown gdm:gdm /var/lib/gdm3/seat0/config/monitors.xml
```

### Screen Brightness

Try these in order. For the first two, edit `/etc/default/grub` (e.g. `sudo nano /etc/default/grub`), change the
`GRUB_CMDLINE_LINUX_DEFAULT` line as shown, then run `sudo update-grub` and reboot.

1. **Brightness controls missing after a fresh install**:

   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=native"
   ```

   If that does not help, try `acpi_backlight=vendor` instead.

2. **Brightness resets to 50% on every boot after a release upgrade** (Intel GPU). Force the Intel GPU to initialise
   correctly and re-attach the eDP panel:

   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.force_probe=* i915.enable_dpcd_backlight=1 i915.enable_guc=3"
   ```

3. **Only `nvidia_0` is listed** in `ls /sys/class/backlight`, even though
   `lspci -nnk | grep -iA2 "vga\|3d\|display"` shows both GPUs and `prime-select query` reports `on-demand`. Set the
   NVIDIA backlight to full brightness at boot with a systemd service:

   ```bash
   sudo tee /etc/systemd/system/fix-screen-brightness.service > /dev/null <<'EOF'
   [Unit]
   Description=Fix screen brightness
   After=multi-user.target

   [Service]
   Type=oneshot
   ExecStart=/bin/bash -c 'echo 100 > /sys/class/backlight/nvidia_0/brightness'

   [Install]
   WantedBy=multi-user.target
   EOF
   sudo systemctl enable --now fix-screen-brightness.service
   ```

## Further Reading

- [Awesome Dotfiles](https://github.com/webpro/awesome-dotfiles): a curated list of dotfiles articles, tools and
  example repositories.
- [Using GNU Stow to manage your dotfiles](https://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html):
  the approach this repository uses.
- [conf.d like directories for zsh/bash dotfiles](https://chr4.org/posts/2014-09-10-conf-dot-d-like-directories-for-zsh-slash-bash-dotfiles/):
  the idea behind `~/.bashrc.d/`.
- [Shell startup scripts](https://blog.flowblok.id.au/2013-02/shell-startup-scripts.html): what goes in `.profile`
  versus `.bashrc`.
- [XDG Base Directory](https://wiki.archlinux.org/title/XDG_Base_Directory): why configuration belongs in `~/.config`.

## License

The scripts and configuration in this repository are released under the [MIT License](LICENSE.md).
