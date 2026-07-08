# Aether Forge

The official IDE for the [Aether](https://github.com/StratosLabs-Aether/aether) programming language.

Built on [Eclipse Theia](https://theia-ide.org/).

## Quick Start

```bash
# Ubuntu/Debian: install FUSE first
sudo apt install libfuse2

# Arch: FUSE is pre-installed

# Download and run
chmod +x aether-forge.sh Aether-Forge-x86_64.AppImage
./aether-forge.sh
```

Or run directly:
```bash
./Aether-Forge-x86_64.AppImage --no-sandbox
```

## Features

- Syntax highlighting for `.ath` and `.glo` files
- Run and debug Aether files directly from the IDE (Ctrl+Shift+P → "Aether: Run Current File")
- Built-in terminal with `aether` CLI
- 1,250+ Material Design file icons (SVG, no font dependency)
- Dark purple theme

## Requirements

- Linux x86_64
- `libfuse2` (Ubuntu/Debian: `sudo apt install libfuse2`)
- `aether` CLI ([install guide](https://github.com/StratosLabs-Aether/aether))

## Troubleshooting

**Blank window or crash:** Run with `--no-sandbox --disable-gpu-sandbox` flags.

**"AppImage not found" or mount error:** Install `libfuse2`:
```bash
sudo apt install libfuse2   # Ubuntu/Debian
sudo pacman -S fuse2         # Arch
```

**Wayland issues:** The launch script auto-detects Wayland and uses X11 fallback.
