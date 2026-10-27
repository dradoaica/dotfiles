# Dotfiles

[![CI](https://github.com/dradoaica/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/dradoaica/dotfiles/actions/workflows/ci.yml)

Scripts and settings for turning a fresh **Ubuntu Desktop 26.04 (minimal installation, amd64)** into a complete
development workstation.

- [Before You Run](#before-you-run)
- [Quick Start](#quick-start)
- [What's Included](#whats-included)
- [Dotfiles](#dotfiles)
- [Post-Install](#post-install)
- [Troubleshooting](#troubleshooting)
- [Optional Apps](#optional-apps)
- [Further Reading](#further-reading)
- [License](#license)

## Before You Run

`scripts/install.sh` makes system-wide changes and replaces some of your configuration files. Read it first, and be
aware that it:

- Targets **Ubuntu 26.04 on amd64 only** (the Chrome repository and the Docker Desktop package are amd64-only).
- Needs `sudo`, runs a full `apt-get upgrade`, and takes a while. It runs in steps (sources, packages, Docker,
  Kubernetes and so on); a step that fails does not stop the others, and the failed ones are listed at the end, so you
  can fix them and run it again.
- Installs balenaEtcher, OpenLogi and Wayland Scroll Factor from the `.deb` files on their latest GitHub releases
  ([`scripts/github-debs.sh`](scripts/github-debs.sh)), after checking each file against the SHA-256 digest GitHub
  publishes for it. Installs Docker Desktop the same way from Docker's update feed
  ([`scripts/docker-desktop.sh`](scripts/docker-desktop.sh)), checking it against the `checksums.txt` Docker publishes
  for each build.
- Adds third-party APT sources: five PPAs (Ulauncher, OpenRazer, Polychromatic, qBittorrent, Nexis) and the
  Google Chrome, Docker and GitHub CLI repositories. .NET comes from Ubuntu's own archive.
- Replaces `~/.bashrc`, `~/.profile`, the Git config and the other files under [`home/`](home) with symlinks into this
  repository. The files it replaces are moved to `~/.dotfiles-backup/<timestamp>/`.
- Installs the GNOME extensions listed in [`gnome/extensions.txt`](gnome/extensions.txt) from extensions.gnome.org and
  overwrites the GNOME settings saved in [`gnome/dconf/`](gnome/dconf) (fonts, theme, shortcuts, extension settings).
- Adds your user to the `microk8s` group and merges the MicroK8s cluster into `~/.kube/config` (other clusters and
  the current context are kept; the file is made readable only by you), then stops MicroK8s so it does not run in the
  background or start at boot. Run `microk8s start` when you need it, and `microk8s stop` afterwards.
- Makes Docker Desktop the default for `docker` commands (the `desktop-linux` context) and starts it at login,
  minimised to the tray (the Dashboard does not open). Docker Engine is installed too, but disabled, since Docker
  Desktop runs its own engine. Start it with `sudo systemctl start docker` if you need it.
- Enables `clamav-freshclam`, so ClamAV's virus definitions stay up to date.
- Creates a GPG key named "Docker Desktop" **without a passphrase** and initialises `pass` with it, so Docker Desktop
  can store credentials. Replace it with a passphrase-protected key if that matters to you.

The script is safe to re-run.

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

Keep the clone where it is afterwards: the symlinks point into it.

The installer runs these steps, which you can also run on their own. The `make` shortcuts work once `packages.sh` has
installed `make`; run `make` on its own to list them.

| Step                          | Shortcut          | What it does                                                     |
|-------------------------------|-------------------|------------------------------------------------------------------|
| `scripts/packages.sh`         | `make packages`   | Adds the repositories and installs everything listed below.      |
| `scripts/link.sh`             | `make link`       | Symlinks the dotfiles in `home/` into your home directory.       |
| `scripts/gnome.sh extensions` | `make extensions` | Installs the GNOME extensions listed in `gnome/extensions.txt`.  |
| `scripts/gnome.sh load`       | `make load`       | Applies the GNOME settings saved in `gnome/dconf/`.              |
| `scripts/apps.sh load`        | `make load`       | Applies the OpenLogi config, default apps and Helm repositories. |

When it finishes, **log out and back in** so the new group membership, fonts and GNOME extensions take effect, then
work through [Post-Install](#post-install).

## What's Included

### Installed Automatically

The packages are listed in [`packages/`](packages), one file per package manager: [`apt.txt`](packages/apt.txt),
[`snap.txt`](packages/snap.txt), [`flatpak.txt`](packages/flatpak.txt), [`brew.txt`](packages/brew.txt) and
[`github-debs.txt`](packages/github-debs.txt) for the apps from GitHub releases.

- **Package managers**: Flatpak (with Flathub) alongside APT and Snap, plus Homebrew.
- **Fonts**: [Inter](https://rsms.me/inter/) and [JetBrains Mono](https://www.jetbrains.com/lp/mono/), from Ubuntu's
  `fonts-inter`, `fonts-inter-variable` and `fonts-jetbrains-mono` packages.
- **Cursors**: [Bibata](https://github.com/ful1e5/Bibata_Cursor), [Phinger](https://github.com/phisch/phinger-cursors)
  and [Breeze](https://github.com/KDE/breeze).
- **Development**:
    - Languages: Python, Go, Rust (via rustup only), Java, .NET 10, C/C++ (GCC and Clang), PHP, Ruby, Node.js 24 (via
      nvm).
    - IDEs: VS Code, JetBrains Toolbox.
    - Git: GitKraken, GitHub CLI (`gh`).
    - Containers and Kubernetes: Docker Engine, Docker Desktop, Multipass, MicroK8s, kubectl, Helm, helm-docs, K9s.
    - Other: Postman, Claude Code.
- **Applications**:
    - Productivity: Google Chrome, Firefox, LibreOffice, qBittorrent, VLC, Notepad Next, Adobe Acrobat Reader
      (`acrordrdc` snap, runs via WINE).
    - Graphics: GIMP, Ksnip.
    - System: GNOME Tweaks, GNOME Shell Extensions, Nexis, Ulauncher, Déjà Dup, File Roller,
      [balenaEtcher](https://github.com/balena-io/etcher) (writes OS images to USB drives and SD cards).
    - Touchpad: [Wayland Scroll Factor](https://github.com/daniel-g-carrasco/wayland-scroll-factor), set to 30% scroll
      speed (`wsf set --scroll-vertical 0.30 --scroll-horizontal 0.30`), from the next login.
    - Security: ClamAV, ClamTK.
    - Hardware: [OpenLogi](https://github.com/AprilNEA/OpenLogi) (Logitech; replaces Solaar, which the installer removes
      if it finds it), OpenRazer and Polychromatic (Razer), Galaxy Buds Client (Samsung Galaxy Buds).
    - Games: GNOME Chess, Steam.

### GNOME Extensions

Installed from extensions.gnome.org with [gnome-extensions-cli](https://github.com/essembeh/gnome-extensions-cli), and
active after you log out and back in:

| Extension                                                                                                     | UUID                                                   |
|---------------------------------------------------------------------------------------------------------------|--------------------------------------------------------|
| [Alphabetical App Grid](https://extensions.gnome.org/extension/4269/alphabetical-app-grid/)                   | `AlphabeticalAppGrid@stuarthayhurst`                   |
| [ArcMenu](https://extensions.gnome.org/extension/3628/arcmenu/)                                               | `arcmenu@arcmenu.com`                                  |
| [Battery Health Charging](https://extensions.gnome.org/extension/5724/battery-health-charging/)               | `Battery-Health-Charging@maniacx.github.com`           |
| [Bing Wallpaper](https://extensions.gnome.org/extension/1262/bing-wallpaper-changer/)                         | `BingWallpaper@ineffable-gmail.com`                    |
| [Burn My Windows](https://extensions.gnome.org/extension/4679/burn-my-windows/)                               | `burn-my-windows@schneegans.github.com`                |
| [Clipboard Indicator](https://extensions.gnome.org/extension/779/clipboard-indicator/)                        | `clipboard-indicator@tudmotu.com`                      |
| [Compiz alike magic lamp effect](https://extensions.gnome.org/extension/3740/compiz-alike-magic-lamp-effect/) | `compiz-alike-magic-lamp-effect@hermes83.github.com`   |
| [Compiz windows effect](https://extensions.gnome.org/extension/3210/compiz-windows-effect/)                   | `compiz-windows-effect@hermes83.github.com`            |
| [Dash to Panel](https://extensions.gnome.org/extension/1160/dash-to-panel/)                                   | `dash-to-panel@jderose9.github.com`                    |
| [Desktop Cube](https://extensions.gnome.org/extension/4648/desktop-cube/)                                     | `desktop-cube@schneegans.github.com`                   |
| [Removable Drive Menu](https://extensions.gnome.org/extension/7/removable-drive-menu/)                        | `drive-menu@gnome-shell-extensions.gcampax.github.com` |
| [Lock Keys](https://extensions.gnome.org/extension/36/lock-keys/)                                             | `lockkeys@vaina.lt`                                    |
| [Sound Percentage](https://extensions.gnome.org/extension/7426/sound-percentage/)                             | `sound-percentage@subashghimire.info.np`               |
| [Tiling Shell](https://extensions.gnome.org/extension/7065/tiling-shell/)                                     | `tilingshell@ferrarodomenico.com`                      |

### Not Automated

Proprietary drivers ([Post-Install](#post-install)) and the [Optional Apps](#optional-apps).

## Dotfiles

Configuration lives in [`home/`](home), one folder per program. Each folder mirrors your home directory, and
[GNU Stow](https://www.gnu.org/software/stow/) links its files into place:

| Package     | Files                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| `autostart` | `~/.config/autostart/` entries for Ksnip, qBittorrent and Galaxy Buds Client         |
| `bash`      | `~/.bashrc`, `~/.profile`, `~/.bashrc.d/` (Homebrew, nvm, fzf, completions, history) |
|             | and `~/.inputrc` (case-insensitive completion, ↑/↓ search the history)               |
| `docker`    | Docker Desktop service override: waits for GNOME's tray at login, so its icon shows  |
| `gh`        | `~/.config/gh/config.yml` (GitHub CLI settings and aliases; not `hosts.yml`)         |
| `git`       | `~/.config/git/config`, `~/.config/git/ignore`                                       |
| `k9s`       | `~/.config/k9s/` aliases and plugins                                                 |
| `ulauncher` | `~/.config/ulauncher/settings.json`                                                  |
| `vscode`    | `~/.config/Code/User/settings.json`                                                  |

GNOME settings cannot be symlinked, so [`scripts/gnome.sh`](scripts/gnome.sh) saves them to and restores them from
the repository: the user-installed extensions in [`gnome/extensions.txt`](gnome/extensions.txt), and in
[`gnome/dconf/`](gnome/dconf) interface (fonts, theme, cursor), keyboard layouts, keyboard shortcuts, window manager,
mouse and touchpad, power and screen blanking, sound, privacy, the first day of the week, the enabled extensions, the
Files, Text Editor and Ptyxis (terminal) preferences, and the settings of ArcMenu, Dash to Panel, Burn My Windows,
Tiling Shell, Bing Wallpaper and Battery Health Charging.
Loading also resets any of these settings that are set on this machine but no longer saved, so a setting you put back
to its default and saved with `make dump` goes back to its default everywhere you load it. Keys that hold runtime state
rather than preferences are never reset.

Some app settings cannot be symlinked either, because the app rewrites the file or the file holds names that differ
per machine. [`scripts/apps.sh`](scripts/apps.sh) saves them to and restores them from [`apps/`](apps):

- **OpenLogi**: `~/.config/openlogi/config.toml` (Logitech button bindings, DPI, gestures), copied in and out. Loading
  backs up the current file to `~/.dotfiles-backup/`; restart OpenLogi afterwards.
- **Default apps**: the default applications from `~/.config/mimeapps.list`, applied with `xdg-mime`. JetBrains IDEs
  are matched by name, since their entries carry a per-installation ID; apps that are not installed yet are skipped.
- **Helm repositories**: the names and URLs from `helm repo list`, added again with `helm repo add`.

### Day to Day

- **Update everything** with `make update`: APT, Snap and Flatpak packages, firmware (with `fwupdmgr`; it never reboots,
  so reboot yourself if it asks), Docker Desktop, balenaEtcher, OpenLogi and Wayland Scroll Factor, Homebrew, pipx
  tools, your GNOME extensions, the Rust toolchain, nvm and Node 24 (keeping your global npm packages). It then removes
  unused packages and old snap revisions, the same cleanup the installer ends with
  ([`scripts/cleanup.sh`](scripts/cleanup.sh)), and reports any dotfile that is no longer linked. A step that fails does
  not stop the others; the failed ones are listed at the end.
- **Edit a dotfile** in place, in `~` or in the repository: they are the same file. Commit the change.
- **Add a file** by moving it into the matching package, then re-link it:

  ```bash
  mkdir -p home/k9s/.config/k9s
  mv ~/.config/k9s/views.yaml home/k9s/.config/k9s/
  bash scripts/link.sh k9s
  ```

- **Add a package** by creating a new folder in `home/`; `link.sh` picks up every folder.
- **Install an app** by adding it to the matching list in [`packages/`](packages), then running `make packages`.
- **Find what you installed by hand** with `make drift` (`make dump` runs it too). It lists the APT packages you
  installed (not the ones Ubuntu did), snaps, Flatpak apps and Homebrew packages that are not in `packages/`, so a
  fresh install would miss them. Add each one to its list, or to [`packages/ignore.txt`](packages/ignore.txt) to stop
  reporting it.
- **Shell additions** go in a new file in `home/bash/.bashrc.d/`, not in `.bashrc`, which stays Ubuntu's default.
  For a program that prints shell code to load (like `brew shellenv` or `fzf --bash`), use
  `cached_eval <name> <program> <command...>` from `00-cache.sh`: it keeps the output in `~/.cache/bashrc/` and only
  runs the program again when it changes, which keeps new shells fast.
- **Save GNOME and app changes** made in Settings, Tweaks or extension preferences, extensions you installed or
  removed, OpenLogi, default apps or Helm repositories, with `make dump`, then review `git diff` and commit.
- **Check the links** with `make check`. It lists every dotfile that is missing or replaced by a regular file, for
  example after a program overwrote its symlink. `make link` fixes them.
- **Remove the links** with `make unlink`. The files stay in the repository; restore your originals from
  `~/.dotfiles-backup/` if you want them back.
- **Check the whole machine** with `make doctor`, for example after `make packages` or a release upgrade. It checks,
  without changing anything, that the dotfiles are linked, Docker uses Docker Desktop and Docker Engine stays off,
  MicroK8s does not start at boot, `~/.kube/config` is private, ClamAV's definitions update, `gh` is logged in, the
  apps from GitHub releases are installed and every GNOME extension is enabled.
- **Search the history** with <kbd>Ctrl</kbd>+<kbd>R</kbd> ([fzf](https://github.com/junegunn/fzf)).
  <kbd>Ctrl</kbd>+<kbd>T</kbd> inserts a file path and <kbd>Alt</kbd>+<kbd>C</kbd> changes into a directory. Each
  command is written to the history as soon as it runs, so new terminals can find it straight away.

`link.sh` links individual files rather than whole folders, so programs that write extra files into `~/.config` never
write them into the repository.

### Machine-Specific Settings

Keep anything private or specific to one machine out of the repository:

- **Shell**: put it in an extra file in `~/.bashrc.d/`, for example `~/.bashrc.d/local.sh`. Every `*.sh` file there is
  loaded, but only the ones in `home/bash/.bashrc.d/` are tracked.
- **Git**: put it in `~/.config/git/config.local` (signing key, work email). The Git config includes it, and it is not
  tracked. `git config --global` writes through the symlink into the repository, so use
  `git config --file ~/.config/git/config.local` instead.

### Testing

[CI](.github/workflows/ci.yml) runs on every push and every Monday, in an Ubuntu 26.04 container:

- **sources**: checks that everything the installer downloads from still works for Ubuntu 26.04: the PPAs, the Docker,
  GitHub CLI and Chrome repositories, the Docker Desktop, JetBrains Toolbox, nvm, Flathub and Homebrew
  downloads, and a matching `.deb` in the latest release of each app in `github-debs.sh`. The weekly run catches a
  source that broke while nothing in this repository changed. Run the same check locally with `make sources`.

- **lint**: runs shellcheck on the scripts and `.profile`. Run the same check locally with `make lint`.
- **link**: links the dotfiles into a fresh home directory, checks that the existing files were backed up and that a
  second run changes nothing, starts an interactive shell with the linked `.bashrc`, then unlinks everything again.
- **secrets**: scans the whole Git history with [gitleaks](https://github.com/gitleaks/gitleaks), so a token that ends
  up in a tracked config file is caught before it stays public.

[`.editorconfig`](.editorconfig) keeps editors in line with the repository's style (LF, 2-space indents, 120 columns
for Markdown, no re-wrapping of Markdown paragraphs in JetBrains IDEs).

[Dependabot](.github/dependabot.yml) opens a pull request each month when the GitHub Actions used here have new
versions.

## Post-Install

### GitHub CLI

Sign in once. The Git config already uses the GitHub CLI's credentials for github.com, so `git push` over HTTPS then
works without a separate token, and you do not need `gh auth setup-git`:

```bash
gh auth login
```

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

## Optional Apps

These are distributed as `.deb` files on GitHub releases and are not installed by the script. The commands below
use the [GitHub CLI](https://cli.github.com/) (`gh`), which the script installs, to download the latest release. `gh`
needs you to [sign in](#github-cli) once first. You can also download the file from the linked releases page. These
packages come from third parties: check the project and any published checksums before installing.

### ArtCraft Launcher

Installer and updater for the Craft app suite (image, video, vector, document and CAD editors).
[Releases](https://github.com/storytold/craft-launcher/releases/latest).

```bash
gh release download -R storytold/craft-launcher --pattern '*-linux-x86_64.deb' -D /tmp/craft
sudo apt-get install -y /tmp/craft/*.deb
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
