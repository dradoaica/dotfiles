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

- **Flatpak package manager alongside APT and Snap**
- **Custom Fonts**: System-wide installation of [Inter](https://rsms.me/inter/)
  and [JetBrains Mono](https://www.jetbrains.com/lp/mono/).
- **Custom Cursors**: Bibata, Phinger.
- **Development Toolchains**:
    - Runtimes: Python, Go, Rust, Java, .NET, C/C++, PHP, Ruby, Node.js (via nvm).
    - IDEs: VS Code, JetBrains Toolbox.
    - Git GUI: GitKraken.
    - Tools: Postman, Docker Desktop (with `pass` configured), Microk8s, Homebrew, Helm, helm-docs, K9s.
- **Applications**:
    - Productivity: Google Chrome, Firefox, LibreOffice, Transmission, VLC.
    - Graphics: GIMP, Ksnip.
    - System Utilities: BleachBit, GNOME Tweaks, GNOME Extensions.
    - Hardware Management: Solaar (Logitech), OpenRazer/Polychromatic (Razer), GalaxyBudsClient (Samsung Galaxy Buds).
    - Games: GNOME Chess.

## Misc

### Customize Login Screen

- There is no simple way to customize the login
  screen ([upstream issue](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/2185)). As a workaround, you can
  copy your personal monitor settings to the login screen with:

```bash
sudo cp ~/.config/monitors.xml /var/lib/gdm3/seat0/config/
sudo chown gdm:gdm /var/lib/gdm3/seat0/config/monitors.xml
```

### Screen Brightness

- Ubuntu hard install sometimes does not, by default, enable GUI screen brightness:
    - `sudo nano /etc/default/grub`
    - change the line `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"` to
      `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=native"` or
      `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=vendor"`
    - `sudo update-grub`
- After Ubuntu hard upgrade, sometimes brightness resets to 50% on every reboot. Force the Intel GPU to initialize
  correctly and re‑attach the eDP panel:
    - `sudo nano /etc/default/grub`
    - change the line `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"` to
      `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.force_probe=* i915.enable_dpcd_backlight=1 i915.enable_guc=3"`
    - `sudo update-grub`

## License

See [MIT License](LICENSE.md).
