#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Aether Forge IDE — Build & Install from Source
# =============================================================================
#
# One command:
#   curl -fsSL https://raw.githubusercontent.com/StratosLabs-Aether/forge/main/install.sh | bash
#
# Or locally:
#   git clone https://github.com/StratosLabs-Aether/forge
#   cd forge && bash install.sh
# =============================================================================

bold()  { printf '\033[1m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }
warn()  { printf '\033[33m%s\033[0m' "$1"; }

# Determine script directory (works for both local and piped execution)
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "${0}" ]] 2>/dev/null; then
  # Running from a file
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
else
  # Piped from curl or sourced — use current directory
  SCRIPT_DIR="$(pwd)"
fi

# Ensure we're in the forge project root
if [[ -f "$SCRIPT_DIR/src-tauri/Cargo.toml" ]]; then
  cd "$SCRIPT_DIR"
elif [[ -f "./src-tauri/Cargo.toml" ]]; then
  SCRIPT_DIR="$(pwd)"
else
  red "Could not find Aether Forge source. Run this from the forge project directory."
  echo "  git clone https://github.com/StratosLabs-Aether/forge"
  echo "  cd forge && bash install.sh"
  exit 1
fi

echo ""
bold "⚒  Aether Forge IDE — Installer"
echo "  Source: $SCRIPT_DIR"
echo ""

# ── Detect OS & install deps ──────────────────────────────
HAS_SUDO=0
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  HAS_SUDO=1
fi

DEPS_LINE=""
if command -v apt >/dev/null 2>&1; then
  DEPS_LINE="pkg-config libglib2.0-dev libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev libfuse2"
  if [[ "$HAS_SUDO" -eq 1 ]]; then
    echo "→ Detected Debian/Ubuntu — installing dependencies..."
    sudo apt update -qq
    sudo apt install -y $DEPS_LINE
  fi
elif command -v dnf >/dev/null 2>&1; then
  DEPS_LINE="pkg-config glib2-devel webkit2gtk4.1-devel gtk3-devel libappindicator-gtk3-devel"
  if [[ "$HAS_SUDO" -eq 1 ]]; then
    echo "→ Detected Fedora/RHEL — installing dependencies..."
    sudo dnf install -y $DEPS_LINE
  fi
elif command -v pacman >/dev/null 2>&1; then
  DEPS_LINE="pkg-config glib2 webkit2gtk-6.0 gtk3 libappindicator-gtk3"
  if [[ "$HAS_SUDO" -eq 1 ]]; then
    echo "→ Detected Arch — installing dependencies..."
    sudo pacman -S --noconfirm $DEPS_LINE
  fi
fi

if [[ "$HAS_SUDO" -eq 0 ]] && [[ -n "$DEPS_LINE" ]]; then
  warn "⚠️  No sudo access. Install these packages manually, then re-run:"
  echo ""
  echo "    $DEPS_LINE"
  echo ""
fi

# Verify pkg-config is available before proceeding
if ! command -v pkg-config >/dev/null 2>&1; then
  red "pkg-config not found. Install it first, then re-run this script."
  exit 1
fi

# ── Helper functions ──────────────────────────────────────
INSTALL_DIR="${HOME}/.local/bin"

copy_desktop_entry() {
  local DESKTOP_DIR="${HOME}/.local/share/applications"
  mkdir -p "$DESKTOP_DIR"
  cat > "${DESKTOP_DIR}/com.stratoslabs.AetherForge.desktop" << DESKTOPEOF
[Desktop Entry]
Name=Aether Forge
Comment=Native IDE for the Aether programming language
Exec=${INSTALL_DIR}/aether-forge
Icon=com.stratoslabs.AetherForge
Terminal=false
Type=Application
Categories=Development;IDE;
DESKTOPEOF
  green "✓ Created desktop entry"
}

# ── Check Rust ────────────────────────────────────────────
if ! command -v cargo >/dev/null 2>&1; then
  if [[ -f "${HOME}/.cargo/env" ]]; then
    source "${HOME}/.cargo/env"
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    red "Rust not found. Install it: https://rustup.rs"
    exit 1
  fi
fi


# ── Build & Bundle ────────────────────────────────────────
echo "→ Building Aether Forge (this takes a few minutes)..."

# Check if FUSE is available for AppImage bundling
HAS_FUSE=0
if command -v fusermount3 >/dev/null 2>&1 || command -v fusermount >/dev/null 2>&1; then
  HAS_FUSE=1
fi

# linuxdeploy (used by Tauri for AppImage) is itself an AppImage.
# If no FUSE, set this env var so it can extract-and-run instead.
if [[ "$HAS_FUSE" -eq 0 ]]; then
  export APPIMAGE_EXTRACT_AND_RUN=1
  warn "⚠️  FUSE not detected — AppImage bundling may use fallback mode"
fi

# Install Tauri CLI if not present (needed for bundling)
if ! command -v cargo-tauri >/dev/null 2>&1; then
  echo "→ Installing Tauri CLI..."
  cargo install tauri-cli --version "^2"
fi

# Try full build with bundling
BUNDLE_OK=0
if cargo tauri build 2>&1 | tail -15; then
  green "✓ Build + bundle succeeded"
  BUNDLE_OK=1
else
  warn "⚠️  Bundling failed — falling back to binary-only build"
  cd src-tauri && cargo build --release 2>&1 | tail -5 && cd ..
fi

# ── Install ───────────────────────────────────────────────
INSTALL_DIR="${HOME}/.local/bin"
BIN_SRC="src-tauri/target/release/aether-forge"
BUNDLE_DIR="src-tauri/target/release/bundle"

if [[ -f "$BIN_SRC" ]]; then
  mkdir -p "$INSTALL_DIR"
  cp "$BIN_SRC" "$INSTALL_DIR/aether-forge"
  chmod +x "$INSTALL_DIR/aether-forge"
  green "✓ Installed binary to ${INSTALL_DIR}/aether-forge"

  # If AppImage was built, install it too
  if compgen -G "${BUNDLE_DIR}/appimage/"*.AppImage >/dev/null 2>&1; then
    cp "${BUNDLE_DIR}/appimage/"*.AppImage "${INSTALL_DIR}/aether-forge.AppImage"
    chmod +x "${INSTALL_DIR}/aether-forge.AppImage"
    green "✓ Installed AppImage to ${INSTALL_DIR}/aether-forge.AppImage"
  fi
else
  red "Build failed — binary not found at $BIN_SRC"
  exit 1
fi

# ── Desktop entry ─────────────────────────────────────────
copy_desktop_entry

echo ""
bold "✅ Aether Forge build complete!"
echo "   Launch from your app menu or run: ${INSTALL_DIR}/aether-forge"
