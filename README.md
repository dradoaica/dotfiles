# Dotfiles

Scripts and settings for turning a fresh **Ubuntu Desktop 26.04 (minimal installation, amd64)** into a complete
development workstation.

- [Before You Run](#before-you-run)
- [Quick Start](#quick-start)
- [What's Included](#whats-included)
- [Post-Install](#post-install)
- [Troubleshooting](#troubleshooting)
- [Optional Apps](#optional-apps)
- [License](#license)

## Before You Run

`scripts/install.sh` makes system-wide changes. Read it first, and be aware that it:

- Targets **Ubuntu 26.04 on amd64 only** (the Chrome repository and the Docker Desktop package are amd64-only).
- Needs `sudo`, runs a full `apt-get upgrade`, and takes a while.
- Adds third-party APT sources: six PPAs (Ulauncher, OpenRazer, Polychromatic, qBittorrent, Nexis, Solaar) and the
  Google Chrome, Docker and Microsoft repositories.
- Appends the Homebrew environment to `~/.bashrc`.
- Adds your user to the `microk8s` group and writes `~/.kube/config`.
- Creates autostart entries for Ksnip, Galaxy Buds Client and qBittorrent in `~/.config/autostart`.
- Creates a GPG key named "Docker Desktop" **without a passphrase** and initialises `pass` with it, so Docker Desktop
  can store credentials. Replace it with a passphrase-protected key if that matters to you.

The script is safe to re-run.

## Quick Start

```bash
git clone https://github.com/dradoaica/dotfiles.git
cd dotfiles
bash scripts/install.sh
```

When it finishes, **log out and back in** so the new group membership and fonts take effect, then work through
[Post-Install](#post-install).

## What's Included

### Installed Automatically

- **Package managers**: Flatpak (with Flathub) alongside APT and Snap, plus Homebrew.
- **Fonts**: [Inter](https://rsms.me/inter/) and [JetBrains Mono](https://www.jetbrains.com/lp/mono/), installed
  system-wide from `fonts/`.
- **Cursors**: [Bibata](https://github.com/ful1e5/Bibata_Cursor), [Phinger](https://github.com/phisch/phinger-cursors)
  and [Breeze](https://github.com/KDE/breeze).
- **Development**:
    - Languages: Python, Go, Rust (via rustup only), Java, .NET 10, C/C++ (GCC and Clang), PHP, Ruby, Node.js 24 (via
      nvm).
    - IDEs: VS Code, JetBrains Toolbox.
    - Git GUI: GitKraken.
    - Containers and Kubernetes: Docker Engine, Docker Desktop, Multipass, MicroK8s, kubectl, Helm, helm-docs, K9s.
    - Other: Postman.
- **Applications**:
    - Productivity: Google Chrome, Firefox, LibreOffice, qBittorrent, VLC, Notepad Next, Adobe Acrobat Reader
      (`acrordrdc` snap, runs via WINE).
    - Graphics: GIMP, Ksnip.
    - System: GNOME Tweaks, GNOME Shell Extensions, Nexis, Ulauncher, Déjà Dup, File Roller.
    - Security: ClamAV, ClamTK.
    - Hardware: Solaar (Logitech), OpenRazer and Polychromatic (Razer), Galaxy Buds Client (Samsung Galaxy Buds).
    - Games: GNOME Chess, Steam.

### Manual Steps

These are not automated; see [Post-Install](#post-install) and [Optional Apps](#optional-apps):

- GNOME extensions and their settings (ArcMenu, Dash to Panel).
- Ulauncher hotkey on Wayland.
- Proprietary drivers.

## Post-Install

### GNOME Extensions

The extensions I use:

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

Install them all at once with [gnome-extensions-cli](https://github.com/essembeh/gnome-extensions-cli):

```bash
pipx install gnome-extensions-cli --system-site-packages
gext install \
  AlphabeticalAppGrid@stuarthayhurst \
  arcmenu@arcmenu.com \
  Battery-Health-Charging@maniacx.github.com \
  BingWallpaper@ineffable-gmail.com \
  burn-my-windows@schneegans.github.com \
  clipboard-indicator@tudmotu.com \
  compiz-alike-magic-lamp-effect@hermes83.github.com \
  compiz-windows-effect@hermes83.github.com \
  dash-to-panel@jderose9.github.com \
  desktop-cube@schneegans.github.com \
  drive-menu@gnome-shell-extensions.gcampax.github.com \
  lockkeys@vaina.lt \
  sound-percentage@subashghimire.info.np \
  tilingshell@ferrarodomenico.com
```

Then import the ArcMenu and Dash to Panel settings from the repository root:

```bash
dconf load /org/gnome/shell/extensions/arcmenu/ < gnome/dconf/arc-menu-settings.dconf
dconf load /org/gnome/shell/extensions/dash-to-panel/ < gnome/dconf/dash-to-panel-settings.dconf
```

To list the user-installed extensions in alphabetical order:

```bash
find ~/.local/share/gnome-shell/extensions -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort
```

### Ulauncher Hotkey on Wayland

On Wayland, Ulauncher does not receive its hotkey while some windows are focused (e.g. Terminal or Settings). Bind it
through GNOME instead:

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
use the [GitHub CLI](https://cli.github.com/) (`gh`) to download the latest release; you can also download the file
from the linked releases page. These packages come from third parties: check the project and any published checksums
before installing.

### OpenLogi

Open-source alternative to Solaar for Logitech devices.
[Releases](https://github.com/AprilNEA/OpenLogi/releases/latest).

```bash
gh release download -R AprilNEA/OpenLogi --pattern '*linux-amd64.deb' -D /tmp/openlogi
sudo apt-get install -y /tmp/openlogi/*.deb
```

### Wayland Scroll Factor

Adjusts touchpad scroll and gesture speed on Wayland.
[Releases](https://github.com/daniel-g-carrasco/wayland-scroll-factor/releases/latest).

```bash
gh release download -R daniel-g-carrasco/wayland-scroll-factor --pattern 'wayland-scroll-factor_*_amd64.deb' -D /tmp/wsf
sudo apt-get install -y /tmp/wsf/*.deb

wsf set \
  --scroll-vertical 0.30 \
  --scroll-horizontal 0.30 \
  --pinch-zoom 1.00 \
  --pinch-rotate 1.00
wsf enable
```

### balenaEtcher

Writes OS images to USB drives and SD cards.
[Releases](https://github.com/balena-io/etcher/releases/latest).

```bash
gh release download -R balena-io/etcher --pattern '*_amd64.deb' -D /tmp/etcher
sudo apt-get install -y /tmp/etcher/*.deb
```

### ArtCraft Launcher

Installer and updater for the Craft app suite (image, video, vector, document and CAD editors).
[Releases](https://github.com/storytold/craft-launcher/releases/latest).

```bash
gh release download -R storytold/craft-launcher --pattern '*-linux-x86_64.deb' -D /tmp/craft
sudo apt-get install -y /tmp/craft/*.deb
```

## License

The scripts and configuration in this repository are released under the [MIT License](LICENSE.md).

The bundled fonts keep their own licenses: Inter and JetBrains Mono are both distributed under the SIL Open Font
License (see `fonts/Inter/OFL.txt` and `fonts/JetBrainsMono-2.304/OFL.txt`).
