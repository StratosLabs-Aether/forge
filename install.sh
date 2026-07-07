#!/usr/bin/env bash
set -euo pipefail
green() { printf '\033[32m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

FORGE_DIR="${HOME}/.aether-forge"
DATA="${FORGE_DIR}/data"
EXT="${DATA}/extensions"
SETTINGS="${DATA}/user-data/User"

echo ""
bold "⚒  Aether Forge Installer"

# ── Download VS Codium ────────────────────────────────────
if [[ ! -f "${FORGE_DIR}/bin/codium" && ! -f "${FORGE_DIR}/codium" ]]; then
  echo "→ Downloading VS Codium..."
  case "$(uname -m)" in
    x86_64) URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-x64-1.96.0.24347.tar.gz" ;;
    aarch64) URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-arm64-1.96.0.24347.tar.gz" ;;
    *) echo "Unsupported arch"; exit 1 ;;
  esac
  mkdir -p "$FORGE_DIR"
  curl -fsSL -o /tmp/forge-vsc.tar.gz "$URL"
  tar -xzf /tmp/forge-vsc.tar.gz -C "$FORGE_DIR"
  rm -f /tmp/forge-vsc.tar.gz
fi

# Find codium binary
CODIUM=""
for c in "${FORGE_DIR}/bin/codium" "${FORGE_DIR}/codium"; do
  [[ -f "$c" ]] && { CODIUM="$c"; break; }
done
CODIUM="${CODIUM:-$(find "${FORGE_DIR}" -name codium -type f -not -path '*/resources/*' 2>/dev/null | head -1)}"
[[ -z "$CODIUM" ]] && { echo "codium not found"; exit 1; }
green "✓ VS Codium"

# ── Clone forge repo ──────────────────────────────────────
FORGE_REPO="${FORGE_DIR}/forge-repo"
rm -rf "$FORGE_REPO" 2>/dev/null
echo "→ Fetching extensions..."
git clone --depth 1 https://github.com/StratosLabs-Aether/forge.git "$FORGE_REPO" 2>/dev/null || { echo "Clone failed"; exit 1; }

# ── Install extensions ────────────────────────────────────
mkdir -p "$EXT" "$SETTINGS"

copy_ext() {
  local src="$1" id="$2"
  local dst="${EXT}/${id}"
  rm -rf "$dst" 2>/dev/null
  mkdir -p "$dst"
  cp -r "${FORGE_REPO}/extensions/${src}/"* "$dst/"
  green "  ✓ ${id}"
}

copy_ext "aether-language"   "stratos-labs.aether-support"
copy_ext "aether-file-icons" "stratos-labs.aether-file-icons"
copy_ext "aether-scrible"    "stratos-labs.aether-scrible"

# CRITICAL: Delete cache so VS Codium re-scans extensions
rm -f "${EXT}/extensions.json" "${EXT}/.obsolete" 2>/dev/null || true

# ── Settings ──────────────────────────────────────────────
cat > "${SETTINGS}/settings.json" <<'JSONEOF'
{
  "workbench.colorTheme": "Aether Dark",
  "workbench.iconTheme": "aether-seti-icons",
  "files.associations": { "*.ath": "aether", "*.glo": "aether" },
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "window.title": "Aether Forge — ${activeEditorShort}",
  "workbench.startupEditor": "none"
}
JSONEOF
cat > "${SETTINGS}/keybindings.json" <<'KEYEOF'
[
  { "key": "f5", "command": "aether.runCurrentFile", "when": "editorLangId == 'aether'" }
]
KEYEOF
green "✓ Settings"

# ── Launcher ──────────────────────────────────────────────
mkdir -p ~/.local/bin
cat > ~/.local/bin/forge <<LAUNCHEOF
#!/usr/bin/env bash
exec "${CODIUM}" --user-data-dir "${DATA}/user-data" --extensions-dir "${EXT}" --new-window "\$@"
LAUNCHEOF
chmod +x ~/.local/bin/forge

# ── Desktop entry + icon ──────────────────────────────────
mkdir -p ~/.local/share/applications ~/.aether-forge/icons
cp "${FORGE_REPO}/icons/forge-256.png" ~/.aether-forge/icons/forge.png 2>/dev/null || true

cat > ~/.local/share/applications/aether-forge.desktop <<DESKEOF
[Desktop Entry]
Name=Aether Forge
Comment=IDE for the Aether language
Exec=${HOME}/.local/bin/forge %F
Icon=${HOME}/.aether-forge/icons/forge.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=codium
DESKEOF
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
green "✓ Launcher + desktop"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green "✓ Aether Forge installed!"
echo "  $(bold 'forge .')   — open current directory"
echo "  $(bold 'F5')        — run .ath file"
echo ""
echo "  Scrible:  bash ${FORGE_REPO}/install-models.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
