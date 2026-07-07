# ⚒ Aether Forge

A standalone IDE for the [Aether](https://github.com/StratosLabs-Aether/source) language — powered by VS Codium in portable mode. Does not touch your existing VS Code installation.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/StratosLabs-Aether/forge/main/install.sh | bash
```

## What's included

- **Aether Language Support** — syntax highlighting, snippets, Aether Dark theme
- **Scrible AI** — Ollama-powered chat and completions (Phi-3 v3)
- **Terminal** — xterm.js with full PTY (ask(), sudo, SSH all work)
- **Standalone** — portable mode, separate from your existing editor
- **No telemetry** — all tracking removed

## Launch

```bash
forge          # launch Forge
forge .        # open current directory
```

## Requirements

- Linux, macOS, or Windows
- [Aether](https://github.com/StratosLabs-Aether/source) (`curl -fsSL https://raw.githubusercontent.com/StratosLabs-Aether/source/main/scripts/install.sh | bash`)
- [Ollama](https://ollama.com) for Scrible AI
