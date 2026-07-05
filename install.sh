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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo ""
bold "⚒  Aether Forge IDE — Installer"
echo ""

# ── Detect OS & install deps ──────────────────────────────
if command -v apt >/dev/null 2>&1; then
  echo "→ Detected Debian/Ubuntu — installing dependencies..."
  sudo apt update -qq
  sudo apt install -y pkg-config libglib2.0-dev libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev
elif command -v dnf >/dev/null 2>&1; then
  echo "→ Detected Fedora/RHEL — installing dependencies..."
  sudo dnf install -y pkg-config glib2-devel webkit2gtk4.1-devel gtk3-devel libappindicator-gtk3-devel
elif command -v pacman >/dev/null 2>&1; then
  echo "→ Detected Arch — installing dependencies..."
  sudo pacman -S --noconfirm pkg-config glib2 webkit2gtk-6.0 gtk3 libappindicator-gtk3
else
  echo "⚠️  Could not detect package manager. Install these manually:"
  echo "   libwebkit2gtk-4.1-dev, libgtk-3-dev, libappindicator"
fi

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

# ── Install Tauri CLI ─────────────────────────────────────
if ! command -v cargo-tauri >/dev/null 2>&1; then
  echo "→ Installing Tauri CLI..."
  cargo install tauri-cli --version "^2"
fi

# ── Build ─────────────────────────────────────────────────
echo "→ Building Aether Forge (this takes a few minutes)..."
cd "$SCRIPT_DIR"
cargo tauri build 2>&1 | tail -5

# ── Install ───────────────────────────────────────────────
BUNDLE_DIR="src-tauri/target/release/bundle"
INSTALL_DIR="${HOME}/.local/bin"

if [[ -f "${BUNDLE_DIR}/appimage/"*.AppImage ]]; then
  mkdir -p "$INSTALL_DIR"
  cp "${BUNDLE_DIR}/appimage/"*.AppImage "${INSTALL_DIR}/aether-forge.AppImage"
  chmod +x "${INSTALL_DIR}/aether-forge.AppImage"
  green "✓ Installed AppImage to ${INSTALL_DIR}/aether-forge.AppImage"
elif [[ -f "${BUNDLE_DIR}/deb/"*.deb ]]; then
  echo "→ Installing .deb package..."
  sudo dpkg -i "${BUNDLE_DIR}/deb/"*.deb
  green "✓ Installed via dpkg"
elif [[ -f "${BUNDLE_DIR}/rpm/"*.rpm ]]; then
  echo "→ Installing .rpm package..."
  sudo rpm -i "${BUNDLE_DIR}/rpm/"*.rpm
  green "✓ Installed via rpm"
else
  # Fallback: copy the binary directly
  BIN_SRC="$(find src-tauri/target/release -maxdepth 1 -type f -executable -name 'aether-forge' 2>/dev/null | head -1)"
  if [[ -n "$BIN_SRC" ]]; then
    mkdir -p "$INSTALL_DIR"
    cp "$BIN_SRC" "$INSTALL_DIR/aether-forge"
    chmod +x "$INSTALL_DIR/aether-forge"
    green "✓ Installed binary to ${INSTALL_DIR}/aether-forge"
  else
    red "Build succeeded but could not find output binary."
    exit 1
  fi
fi

# ── Desktop entry ─────────────────────────────────────────
DESKTOP_DIR="${HOME}/.local/share/applications"
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

echo ""
bold "✅ Aether Forge installed!"
echo "   Launch from your app menu or run: aether-forge"
