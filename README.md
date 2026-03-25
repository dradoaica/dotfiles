# Dotfiles

A collection of configuration scripts and tools for setting up an efficient development environment on Ubuntu Desktop
24.04 minimal installation.

## Quick Start

To install everything, run the following command from the repository root:

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

## What's Included?

The installation script automates the setup of:

- **Custom Fonts**: System-wide installation of [Inter](https://rsms.me/inter/)
  and [JetBrains Mono](https://www.jetbrains.com/lp/mono/).
- **Custom Cursors**: Bibata, Phinger.
- **Development Toolchains**:
    - Languages: Python, Go, Rust, Java, .NET, C/C++, Node.js (via nvm).
    - IDEs: VS Code, JetBrains Toolbox App.
    - Git GUI: GitKraken.
    - Tools: build-essential, Postman, Docker Desktop (with `pass` configured), Microk8s, Homebrew, Helm, helm-docs,
      K9s.
- **Applications**:
    - Productivity: Google Chrome, LibreOffice, Transmission, VLC.
    - Graphics: GIMP.
    - System Utilities: BleachBit, GNOME Tweaks, GNOME Extensions.
    - Hardware Management: Solaar (Logitech), OpenRazer/Polychromatic (Razer).

## License

See [MIT License](LICENSE.md).
