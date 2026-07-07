#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Aether Forge — Standalone IDE installer (VS Codium portable)
# =============================================================================
#   curl -fsSL https://raw.githubusercontent.com/StratosLabs-Aether/forge/main/install.sh | bash
# =============================================================================

bold()  { printf '\033[1m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
warn()  { printf '\033[33m%s\033[0m' "$1" >&2; }
red()   { printf '\033[31m%s\033[0m' "$1"; }

FORGE_DIR="${HOME}/.aether-forge"
FORGE_BIN="${HOME}/.local/bin/forge"

echo ""
bold "⚒  Aether Forge Installer"
echo "  Install: ${FORGE_DIR}"
echo ""

# ── Step 0: Get Forge resources ───────────────────────────
FORGE_REPO="${FORGE_DIR}/forge-repo"
if [[ ! -d "${FORGE_REPO}" ]]; then
  echo "→ Fetching Aether Forge resources..."
  rm -rf "$FORGE_REPO" 2>/dev/null || true
  git clone --depth 1 https://github.com/StratosLabs-Aether/forge.git "$FORGE_REPO" 2>/dev/null || {
    red "Failed to fetch Forge. Check your internet connection."
    exit 1
  }
  green "✓ Forge resources downloaded"
fi

# ── Step 1: Download VS Codium (portable) ──────────────────
if [[ ! -f "${FORGE_DIR}/bin/codium" && ! -f "${FORGE_DIR}/codium" ]]; then
  echo "→ Downloading VS Codium..."
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  case "$OS" in
    Linux)
      case "$ARCH" in
        x86_64)  VSCODIUM_URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-x64-1.96.0.24347.tar.gz" ;;
        aarch64) VSCODIUM_URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-arm64-1.96.0.24347.tar.gz" ;;
        *) red "Unsupported architecture: $ARCH"; exit 1 ;;
      esac ;;
    Darwin)
      case "$ARCH" in
        x86_64) VSCODIUM_URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-darwin-x64-1.96.0.24347.zip" ;;
        arm64)  VSCODIUM_URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-darwin-arm64-1.96.0.24347.zip" ;;
        *) red "Unsupported architecture: $ARCH"; exit 1 ;;
      esac ;;
    *) red "Unsupported OS: $OS"; exit 1 ;;
  esac

  mkdir -p "${FORGE_DIR}"
  TMP_ARCHIVE="${FORGE_DIR}/vscodium.tar.gz"
  curl -fsSL --location --connect-timeout 10 --max-time 300 -o "$TMP_ARCHIVE" "$VSCODIUM_URL" || {
    red "Failed to download VS Codium. Check: ${VSCODIUM_URL}"
    exit 1
  }
  tar -xzf "$TMP_ARCHIVE" -C "${FORGE_DIR}" 2>/dev/null || {
    # macOS zip
    unzip -qo "$TMP_ARCHIVE" -d "${FORGE_DIR}" 2>/dev/null || { red "Failed to extract"; exit 1; }
  }
  rm -f "$TMP_ARCHIVE"

  # Find the extracted directory and rename to bin/
  VSCODIUM_EXTRACTED=$(find "${FORGE_DIR}" -maxdepth 2 -name "codium" -o -name "VSCodium" -type d 2>/dev/null | head -1)
  if [[ -z "$VSCODIUM_EXTRACTED" ]]; then
    # The tar extracts to a top-level directory, find the bin
    VSCODIUM_DIR=$(find "${FORGE_DIR}" -maxdepth 2 -name "bin" -type d 2>/dev/null | head -1)
    if [[ -n "$VSCODIUM_DIR" ]]; then
      VSCODIUM_DIR=$(dirname "$VSCODIUM_DIR")
      mkdir -p "${FORGE_DIR}/vscodium"
      mv "${VSCODIUM_DIR}"/* "${FORGE_DIR}/vscodium/" 2>/dev/null || true
      rmdir "${VSCODIUM_DIR}" 2>/dev/null || true
    fi
  fi

  # Ensure we have bin/codium
  if [[ ! -f "${FORGE_DIR}/vscodium/bin/codium" ]]; then
    # Try to locate codium binary
    CODIUM_BIN=$(find "${FORGE_DIR}" -name "codium" -type f 2>/dev/null | head -1)
    if [[ -z "$CODIUM_BIN" ]]; then
      red "Could not find codium binary in the downloaded archive."
      echo "Contents of ${FORGE_DIR}:"
      ls -la "${FORGE_DIR}/"
      exit 1
    fi
    CODIUM_ROOT=$(dirname $(dirname "$CODIUM_BIN"))
    mkdir -p "${FORGE_DIR}/vscodium"
    mv "${CODIUM_ROOT}"/* "${FORGE_DIR}/vscodium/" 2>/dev/null || true
  fi

  green "✓ VS Codium downloaded"

  # ── Replace dock icon with Aether Forge logo ─────────────
  if [[ -d "${FORGE_REPO}/icons" ]]; then
    ICON_DIR="${FORGE_REPO}/icons"
    # Replace codium.png wherever it exists in the extracted files
    find "${FORGE_DIR}" -name "codium.png" -o -name "code.png" 2>/dev/null | while read -r icon; do
      cp "${ICON_DIR}/forge-256.png" "$icon" 2>/dev/null || true
    done
    # Also place icon for .desktop / dock use
    mkdir -p "${FORGE_DIR}/share/icons"
    cp "${ICON_DIR}/forge-256.png" "${FORGE_DIR}/share/icons/forge.png" 2>/dev/null || true
    green "  ✓ Aether Forge icon installed"
  fi
fi

# Find the actual codium binary
CODIUM_BIN=""
for candidate in "${FORGE_DIR}/bin/codium" "${FORGE_DIR}/codium" "${FORGE_DIR}/vscodium/bin/codium"; do
  if [[ -f "$candidate" ]]; then CODIUM_BIN="$candidate"; break; fi
done
CODIUM_BIN="${CODIUM_BIN:-$(find "${FORGE_DIR}" -name "codium" -type f -not -path "*/resources/*" 2>/dev/null | head -1)}"
if [[ -z "$CODIUM_BIN" ]]; then
  red "Could not locate codium binary."
  exit 1
fi

# ── Step 2: Set up portable data directory ─────────────────
DATA_DIR="${FORGE_DIR}/data"
mkdir -p "${DATA_DIR}/extensions" "${DATA_DIR}/user-data/User"

# ── Step 3: Install Aether extensions ──────────────────────
echo "→ Installing Aether Forge extensions..."

install_ext() {
  local name="$1" display="$2"
  local dest="${DATA_DIR}/extensions/${name}"
  mkdir -p "$dest"
  cp -r "${FORGE_REPO}/extensions/${name}/"* "$dest/"
  green "  ✓ ${display}"
}
install_ext "aether-language"  "Aether Language Support"
install_ext "aether-scrible"   "Scrible AI"

# ── Step 4: Configure settings (portable) ──────────────────
echo "→ Configuring Aether Forge..."
SETTINGS_FILE="${DATA_DIR}/user-data/User/settings.json"
cat > "$SETTINGS_FILE" <<'JSONEOF'
{
  "workbench.colorTheme": "Aether Dark",
  "workbench.iconTheme": "aether-seti-icons",
  "files.associations": { "*.ath": "aether", "*.glo": "aether" },
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "extensions.autoUpdate": false,
  "window.title": "Aether Forge — ${activeEditorShort}",
  "workbench.startupEditor": "none"
}
JSONEOF
green "✓ Settings configured"

# ── Step 5: Create launcher ────────────────────────────────
echo "→ Creating launcher..."
mkdir -p "$(dirname "$FORGE_BIN")"
cat > "$FORGE_BIN" <<LAUNCHEOF
#!/usr/bin/env bash
exec "${CODIUM_BIN}" --user-data-dir "${DATA_DIR}/user-data" --extensions-dir "${DATA_DIR}/extensions" "\$@"
LAUNCHEOF
chmod +x "$FORGE_BIN"
green "✓ Launcher: forge"

# ── Step 6: Done ──────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold "✓ Aether Forge installed!"
echo ""
echo "  Launch:   $(bold 'forge')"
echo "  Open dir: $(bold 'forge .')"
echo ""
echo "  Scrible AI models (optional):"
echo "    bash ${FORGE_REPO}/install-models.sh"
echo ""
echo "  Your existing VS Code/Codium is untouched."
echo "  Aether Forge uses its own data directory at:"
echo "    ${DATA_DIR}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
