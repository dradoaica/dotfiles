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
    - Productivity: Google Chrome, Firefox, LibreOffice, qBittorrent, VLC.
    - Graphics: GIMP, Ksnip.
    - System Utilities: GNOME Tweaks, GNOME Extensions, Stacer.
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

## License

See [MIT License](LICENSE.md).
