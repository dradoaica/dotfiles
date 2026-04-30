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

### Screen Brightness

* Ubuntu hard install sometimes does not, by default, enable GUI screen brightness:
    * `sudo nano /etc/default/grub`
    * change the line `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"` to
      `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=native"` or
      `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=vendor"`
    * `sudo update-grub`

## License

See [MIT License](LICENSE.md).
