#!/usr/bin/env bash
set -euo pipefail

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

# ── Step 0: Clone forge repo ──────────────────────────────
FORGE_REPO="${FORGE_DIR}/forge-repo"
if [[ ! -d "${FORGE_REPO}" ]]; then
  echo "→ Fetching Aether Forge..."
  rm -rf "$FORGE_REPO" 2>/dev/null || true
  git clone --depth 1 https://github.com/StratosLabs-Aether/forge.git "$FORGE_REPO" 2>/dev/null || { red "Failed to fetch Forge"; exit 1; }
  green "✓ Forge downloaded"
fi

# ── Step 1: Download VS Codium ────────────────────────────
if [[ ! -f "${FORGE_DIR}/bin/codium" && ! -f "${FORGE_DIR}/codium" ]]; then
  echo "→ Downloading VS Codium..."
  ARCH="$(uname -m)"
  case "$(uname -s)" in
    Linux)
      case "$ARCH" in
        x86_64) URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-x64-1.96.0.24347.tar.gz" ;;
        aarch64) URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-arm64-1.96.0.24347.tar.gz" ;;
        *) red "Unsupported architecture"; exit 1 ;;
      esac ;;
    Darwin)
      case "$ARCH" in
        x86_64) URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-darwin-x64-1.96.0.24347.zip" ;;
        arm64) URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-darwin-arm64-1.96.0.24347.zip" ;;
        *) red "Unsupported architecture"; exit 1 ;;
      esac ;;
    *) red "Unsupported OS"; exit 1 ;;
  esac
  mkdir -p "$FORGE_DIR"
  TMP="/tmp/forge-vscodium.tar.gz"
  curl -fsSL --location --connect-timeout 10 --max-time 300 -o "$TMP" "$URL" || { red "Download failed"; exit 1; }
  tar -xzf "$TMP" -C "$FORGE_DIR" 2>/dev/null || unzip -qo "$TMP" -d "$FORGE_DIR" 2>/dev/null || { red "Extract failed"; exit 1; }
  rm -f "$TMP"
  green "✓ VS Codium installed"
fi

# ── Find codium binary ────────────────────────────────────
CODIUM=""
for c in "${FORGE_DIR}/bin/codium" "${FORGE_DIR}/codium"; do
  [[ -f "$c" ]] && { CODIUM="$c"; break; }
done
CODIUM="${CODIUM:-$(find "${FORGE_DIR}" -name codium -type f -not -path '*/resources/*' 2>/dev/null | head -1)}"
[[ -z "$CODIUM" ]] && { red "codium binary not found"; exit 1; }

# ── Setup data dir ────────────────────────────────────────
DATA="${FORGE_DIR}/data"
EXT="${DATA}/extensions"
mkdir -p "${EXT}" "${DATA}/user-data/User"

# ── Install extensions via VSIX ───────────────────────────
echo "→ Installing Aether Forge extensions..."

install_vsix() {
  local vsix="$1" name="$2"
  if [[ -f "${FORGE_REPO}/${vsix}" ]]; then
    "$CODIUM" --user-data-dir "${DATA}/user-data" --extensions-dir "${EXT}" --install-extension "${FORGE_REPO}/${vsix}" --force 2>&1 | tail -1
    green "  ✓ ${name}"
  else
    warn "  ⚠ ${name} VSIX not found"
  fi
}

install_vsix "extensions/aether-language.vsix" "Aether Language"
install_vsix "extensions/aether-file-icons.vsix" "Aether File Icons"
install_vsix "extensions/aether-scrible.vsix" "Scrible AI"

# ── Configure settings ────────────────────────────────────
echo "→ Configuring..."
SETTINGS="${DATA}/user-data/User/settings.json"
cat > "$SETTINGS" <<'JSONEOF'
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

cat > "${DATA}/user-data/User/keybindings.json" <<'KEYEOF'
[
  { "key": "f5", "command": "aether.runCurrentFile", "when": "editorLangId == 'aether'" },
  { "key": "ctrl+f5", "command": "aether.debugCurrentFile", "when": "editorLangId == 'aether'" }
]
KEYEOF
green "✓ Settings configured"

# ── Icons + Desktop ───────────────────────────────────────
if [[ -d "${FORGE_REPO}/icons" ]]; then
  mkdir -p "${FORGE_DIR}/share/icons"
  cp "${FORGE_REPO}/icons/forge-256.png" "${FORGE_DIR}/share/icons/forge.png"
fi

mkdir -p ~/.local/share/applications ~/.local/bin
cat > "$FORGE_BIN" <<LAUNCHEOF
#!/usr/bin/env bash
exec "${CODIUM}" --user-data-dir "${DATA}/user-data" --extensions-dir "${EXT}" "\$@"
LAUNCHEOF
chmod +x "$FORGE_BIN"

cat > ~/.local/share/applications/aether-forge.desktop <<DESKEOF
[Desktop Entry]
Name=Aether Forge
Comment=IDE for the Aether language
Exec=${FORGE_BIN} %F
Icon=${FORGE_DIR}/share/icons/forge.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=codium
DESKEOF
command -v update-desktop-database &>/dev/null && update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
green "✓ Launcher + desktop entry"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold "✓ Aether Forge installed!"
echo "  $(bold 'forge')        — launch"
echo "  $(bold 'forge .')      — open current dir"
echo ""
echo "  Scrible AI:  bash ${FORGE_REPO}/install-models.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
