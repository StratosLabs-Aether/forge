# Scrible — AI Coding Agent for Aether

**Scrible** is an AI-powered coding assistant for the [Aether](https://github.com/prism-technologies/aether) programming language, built into VS Code as an extension. It provides:

- **Inline code completions** — powered by a fine-tuned **StarCoder2-3B Q4** model
- **Chat interface** — conversational AI agent in the sidebar for code generation, explanation, and fixes
- **Status Center** — bottom panel with model metrics and controls
- **Preinstalled pretrained model** — `aether-scrible:3b-q4` or use any **Ollama** model

## Architecture

```
┌─────────────────────────────────────────────────┐
│  TOOLBAR (VS Code native)                       │
├────────┬──────────────────────┬─────────────────┤
│ FILES  │  Active File         │  AI Coding      │
│ (VS    │  (Text Editor)       │  Agent — Scrible│
│  Code  │                      │  (Webview)      │
│ native)│                      │                 │
├────────┴──────────────────────┴─────────────────┤
│  Status Center (Bottom Panel)                   │
└─────────────────────────────────────────────────┘
```

## Requirements

- VS Code >= 1.85.0
- [Ollama](https://ollama.com) running locally (for model inference)
- The fine-tuned model: `aether-scrible:3b-q4`

## Quick Start

### 1. Train the model (one-time setup)

```bash
# Prepare training data from the Aether repository
cd scripts/train-starcoder
python prepare_data.py --repo-root ../..

# Fine-tune StarCoder2-3B on Aether code (needs ~8GB VRAM with QLoRA 4-bit)
python finetune.py --epochs 3 --batch-size 4

# Convert to Ollama format
python convert_to_ollama.py --model-dir ./models/aether-scrible/merged --output-name aether-scrible:3b-q4

# Or pull a pre-made model:
ollama pull aether-scrible:3b-q4
```

### 2. Install the extension

```bash
cd aether-scrible
npm install
# Then press F5 in VS Code to launch Extension Development Host
# Or package it:
npx vsce package
code --install-extension aether-scrible-1.0.0.vsix
```

### 3. Use Scrible

- **Autocomplete**: Just type Aether code — Scrible suggests completions inline
- **Chat**: Click the Scrible icon in the activity bar or press the robot button in the editor toolbar
- **Commands** (right-click in editor): Explain Code, Fix Code, Generate Docstring
- **Switch Model**: Run `Scrible: Switch Model` from the command palette

## Features

### Inline Completions

Scrible uses **Fill-In-the-Middle (FIM)** format native to StarCoder2 to provide context-aware completions as you type. Toggle with `Scrible: Toggle Autocomplete`.

### AI Chat Panel

The chat panel provides:
- **Explain Code** — describes what selected Aether code does
- **Fix Code** — finds and repairs bugs
- **Generate Docstring** — creates `#!* ... #!*` documentation blocks
- **Free-form Q&A** — ask anything about Aether syntax, patterns, or best practices

### Status Center

The bottom panel shows:
- Active model name
- Autocomplete status (ON/OFF)
- Ollama endpoint status
- Engine info (StarCoder2-3B Q4)

## Model Options

| Model | Size | Description |
|---|---|---|
| `aether-scrible:3b-q4` | ~2 GB | **Recommended** — StarCoder2-3B fine-tuned on Aether code |
| `starcoder2:3b` | ~2 GB | Base StarCoder2-3B (no Aether fine-tuning) |
| `deepseek-coder:1.3b` | ~1 GB | Lightweight alternative |
| `codellama:7b` | ~4 GB | Larger model (more VRAM needed) |
| Custom | varies | Any Ollama-compatible model |

## Configuration

| Setting | Default | Description |
|---|---|---|
| `aether-scrible.model` | `aether-scrible:3b-q4` | Model for completions and chat |
| `aether-scrible.ollamaEndpoint` | `http://localhost:11434` | Ollama API endpoint |
| `aether-scrible.autocompleteEnabled` | `true` | Enable inline completions |
| `aether-scrible.autocompleteDelay` | `300` | Debounce delay in ms |
| `aether-scrible.maxTokens` | `256` | Max tokens per completion |
| `aether-scrible.temperature` | `0.2` | Model temperature |

## Training Pipeline

The `scripts/train-starcoder/` directory contains the full fine-tuning pipeline:

1. **`prepare_data.py`** — Collects all `.ath` files, generates instruction-tuning and FIM datasets
2. **`finetune.py`** — Fine-tunes StarCoder2-3B with QLoRA (4-bit, fits in 8GB VRAM)
3. **`convert_to_ollama.py`** — Converts the trained model to Ollama GGUF format

### Training Data

The pipeline extracts ~70 `.ath` files (~3,000 lines) from the Aether repository and creates:

- **Instruction-tuning pairs** (Alpaca format): function generation, completion, explanation
- **FIM examples**: prefix/middle/suffix triples for fill-in-the-middle training

### Hardware Requirements

- **Training**: GPU with ≥8GB VRAM (QLoRA 4-bit); tested on RTX 3060/4060
- **Inference**: CPU works (Q4 quantized), GPU optional for speed

## Development

```bash
# Prepare data
cd scripts/train-starcoder
python prepare_data.py

# Train (requires GPU)
python finetune.py

# Convert for Ollama
python convert_to_ollama.py --model-dir ./models/aether-scrible/merged

# Test in VS Code
cd ../../aether-scrible
code .
# Press F5 to launch Extension Development Host
```

## License

MIT — Stratos Labs
