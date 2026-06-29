# Dotfiles

A collection of configuration scripts and tools for setting up an efficient development environment on Ubuntu Desktop
26.04 minimal installation.

## Quick Start

To install everything, run the following command from the repository root:

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

## What's Included?

The installation script automates the setup of:

- **Flatpak package manager alongside APT and Snap.**
- **Custom Fonts**: System-wide installation of [Inter](https://rsms.me/inter/) and
  [JetBrains Mono](https://www.jetbrains.com/lp/mono/).
- **Custom Cursors**: System-wide installation of [Bibata](https://github.com/ful1e5/Bibata_Cursor) and
  [Phinger](https://github.com/phisch/phinger-cursors).
- **Development Toolchains**:
    - Runtimes: Python, Go, Rust, Java, .NET, C/C++, PHP, Ruby, Node.js (via nvm).
    - IDEs: VS Code, JetBrains Toolbox.
    - Git GUI: GitKraken.
    - Tools: Postman, Docker Desktop (with `pass` configured), Microk8s, Homebrew, Helm, helm-docs, K9s.
- **Applications**:
    - Productivity: Google Chrome, Firefox, LibreOffice, qBittorrent, VLC.
    - Graphics: GIMP, Ksnip.
    - System Utilities: GNOME Tweaks, GNOME Extensions, Nexis, Ulauncher.
    - Security: ClamAV, ClamTK
    - Hardware Management: Solaar (Logitech), OpenRazer/Polychromatic (Razer), GalaxyBudsClient (Samsung Galaxy Buds).
    - Games: GNOME Chess.

## Misc

### Additional Drivers

- Show all devices that need drivers and which packages apply:

```bash
sudo ubuntu-drivers devices
```

- Show all driver packages that apply to the current system:

```bash
sudo ubuntu-drivers list
```

- Install a driver [driver[:version][,driver[:version]]]:

```bash
sudo ubuntu-drivers install nvidia-driver-595-open
```

### Customize Login Screen

There is no simple way to customize the login
screen ([upstream issue](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/2185)). As a workaround, you can
copy your personal monitor settings to the login screen with:

```bash
sudo cp ~/.config/monitors.xml /var/lib/gdm3/seat0/config/
sudo chown gdm:gdm /var/lib/gdm3/seat0/config/monitors.xml
```

### Screen Brightness

- Ubuntu hard install sometimes does not, by default, enable GUI screen brightness:
    - `sudo nano /etc/default/grub`
    - Change the line `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"` to
      `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=native"` or
      `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=vendor"`
    - `sudo update-grub`
- After Ubuntu hard upgrade, sometimes screen brightness resets to 50% on every reboot. Force the Intel GPU to
  initialize correctly and re‑attach the eDP panel:
    - `sudo nano /etc/default/grub`
    - Change the line `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"` to
      `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.force_probe=* i915.enable_dpcd_backlight=1 i915.enable_guc=3"`
    - `sudo update-grub`
- If the above does not work (`ls /sys/class/backlight` shows only nvidia_0 even tough
  `lspci -nnk | grep -iA2 "vga\|3d\|display"` shows both graphics and `prime-select query` shows on-demand), set NVIDIA
  GPU screen brightness on login:
    - `sudo nano /etc/systemd/system/fix-screen-brightness.service`
    - Paste this configuration:
      ```ini
      [Unit]
      Description=Fix screen brightness
      After=multi-user.target
  
      [Service]
      Type=oneshot
      ExecStart=/bin/bash -c 'echo 100 > /sys/class/backlight/nvidia_0/brightness'
  
      [Install]
      WantedBy=multi-user.target
      ```
    - `sudo systemctl enable fix-screen-brightness.service`
    - `sudo systemctl start fix-screen-brightness.service`

### Ulauncher Hotkey In Wayland

Ulauncher in Wayland doesn't receive hotkey events when triggered from some windows (e.g., Terminal or OS Settings).

Please follow these steps to fix that:

- Open Ulauncher Preferences and set a hotkey to something you'll never use
- Open `Settings > Keyboard` (it may be named "Keyboard Shortcuts"), then scroll down to
  `View and Customize Shortcuts > Custom Shortcuts > + Add Shrortcut`
- In Command enter `ulauncher-toggle`, set the name and shortcut, then click `Add`

### GNOME Extensions

A curated set of extensions that make Ubuntu fast, polished, and genuinely enjoyable to use:

- AlphabeticalAppGrid@stuarthayhurst
- arcmenu@arcmenu.com
- Battery-Health-Charging@maniacx.github.com
- BingWallpaper@ineffable-gmail.com
- burn-my-windows@schneegans.github.com
- clipboard-indicator@tudmotu.com
- compiz-alike-magic-lamp-effect@hermes83.github.com
- compiz-windows-effect@hermes83.github.com
- dash-to-panel@jderose9.github.com
- desktop-cube@schneegans.github.com
- drive-menu@gnome-shell-extensions.gcampax.github.com
- lockkeys@vaina.lt
- sound-percentage@subashghimire.info.np
- tilingshell@ferrarodomenico.com

To import the settings for ArcMenu and Dash to Panel, run the following commands from the repository root:

```bash
dconf load /org/gnome/shell/extensions/arcmenu/ < gnome/dconf/arc-menu-settings.dconf
dconf load /org/gnome/shell/extensions/dash-to-panel/ < gnome/dconf/dash-to-panel-settings.dconf
```

To list only the user-installed GNOME extensions in alphabetical order, run:

```bash
find ~/.local/share/gnome-shell/extensions -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort
```

### OpenLogi (Solaar alternative)

Download the `.deb` from the [latest release](https://github.com/AprilNEA/OpenLogi/releases/latest):

```bash
sudo apt-get install -y ./openlogi-${version}-linux-amd64.deb
```

### Wayland Scroll Factor

Download the `.deb` from
the [latest release](https://github.com/daniel-g-carrasco/wayland-scroll-factor/releases/latest):

```bash
sudo apt-get install -y ./wayland-scroll-factor_${version}-1_amd64.deb

wsf set \
  --scroll-vertical 0.30 \
  --scroll-horizontal 0.30 \
  --pinch-zoom 1.00 \
  --pinch-rotate 1.00
```

## License

See [MIT License](LICENSE.md).
