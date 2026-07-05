# ⚒ Aether Forge IDE

**Aether Forge** is the official native desktop IDE for the [Aether](https://github.com/StratosLabs-Aether/source) programming language. Built with **Tauri 2.0 + Rust**, featuring a custom dark theme and the **Scrible AI agent** — powered by Ollama.

## Install

### 📦 Pre-built packages (coming soon)
Once CI builds are published, these will work:

| Platform | Command |
|----------|---------|
| Linux (any) | `curl -fsSL https://raw.githubusercontent.com/StratosLabs-Aether/forge/main/install.sh \| bash` |
| Debian/Ubuntu | `sudo apt install aether-forge` |
| Fedora/RHEL | `sudo dnf install aether-forge` |
| Arch Linux | `yay -S aether-forge` |

### 🛠️ Build from source (works today)

```bash
# 1. Install system dependencies
#    Debian/Ubuntu:
sudo apt install pkg-config libglib2.0-dev libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev libfuse2
#    Fedora:
sudo dnf install pkg-config glib2-devel webkit2gtk4.1-devel gtk3-devel libappindicator-gtk3-devel
#    Arch:
sudo pacman -S pkg-config glib2 webkit2gtk-6.0 gtk3 libappindicator-gtk3

# 2. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 3. Clone and build
git clone https://github.com/StratosLabs-Aether/forge
cd forge
cargo build --release --manifest-path src-tauri/Cargo.toml
# → binary at src-tauri/target/release/aether-forge
```

### 🧪 Development mode

```bash
cargo tauri dev       # hot-reload, devtools enabled
```

## Features

- **Native desktop app** — Tauri 2.0 + Rust, ~15MB binary, no Electron bloat
- **Dark theme** — Custom Catppuccin-inspired palette
- **Scrible AI** — Ollama-powered coding agent. Auto-pulls `Scrible` model on first launch
- **File explorer** — Tree view with directory expansion, native folder picker
- **Tab system** — Multi-file editing with dirty-state indicators
- **Run & debug** — Execute Aether scripts in an integrated terminal
- **Auto-update** — Checks GitHub Releases and notifies when a new version is available

## Architecture

```
Aether-Forge-IDE/
├── src-tauri/
│   ├── Cargo.toml              # Tauri 2.0 + Rust dependencies
│   ├── tauri.conf.json         # Window config, CSP, bundling
│   └── src/main.rs             # Rust backend (files, LSP, Scrible AI)
│   ├── preload.js            # Secure context bridge
│   ├── aether-runtime/       # Bundled Aether interpreter (Python)
│   └── renderer/
│       ├── index.html        # IDE shell layout
│       ├── css/
│       │   └── forge-dark.css    # Complete dark theme
│       ├── js/
│       │   ├── forge-core.js     # State management, tabs, IPC
│       │   ├── forge-editor.js   # Monaco editor + Aether language support
│       │   ├── forge-files.js    # File explorer panel
│       │   ├── forge-scrible.js  # Scrible AI chat panel
│       │   ├── forge-status.js   # Status center + terminal output
│       │   └── forge-app.js      # Bootstrap
│       └── icons/
│           └── forge.png
```

## Scrible AI Agent

Scrible is powered by **StarCoder2-3B**, heavily modified and trained for coding in Aether:

| Model | Size | Description |
|---|---|---|
| `aether-scrible:3b-q4` | ~2 GB | **Recommended** — Trained on Aether code (preinstalled) |
| `starcoder2:3b` | ~2 GB | Base StarCoder2 model |
| Any Ollama model | varies | Custom model support |

### Training Scrible

The Scrible agent is trained using the pipeline in `../scripts/train-starcoder/`:

```bash
cd ../scripts/train-starcoder
python prepare_data.py    # Collects all .ath files
python finetune.py        # Fine-tunes StarCoder2-3B with QLoRA
python convert_to_ollama.py  # Converts to Ollama format
ollama pull aether-scrible:3b-q4
```

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+N` | New file |
| `Ctrl+O` | Open file |
| `Ctrl+S` | Save |
| `Ctrl+K` | Open folder |
| `F5` | Run current file |
| `Ctrl+F5` | Debug current file |
| `Shift+F5` | Stop execution |
| `Ctrl+T` | Run tests |
| `Ctrl+B` | Toggle Files panel |
| `Ctrl+J` | Toggle Scrible panel |
| `Ctrl+`` | Toggle Status Center |

## License

MIT — Stratos Labs © 2026
