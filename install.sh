#!/usr/bin/env bash
set -euo pipefail

bold()  { printf '\033[1m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
warn()  { printf '\033[33m%s\033[0m' "$1" >&2; }
red()   { printf '\033[31m%s\033[0m' "$1"; }

FORGE_DIR="${HOME}/.aether-forge"
FORGE_BIN="${HOME}/.local/bin/forge"
DATA="${FORGE_DIR}/data"
EXT="${DATA}/extensions"
SETTINGS="${DATA}/user-data/User/settings.json"

echo ""
bold "⚒  Aether Forge Installer"

# ── Clone forge ───────────────────────────────────────────
FORGE_REPO="${FORGE_DIR}/forge-repo"
rm -rf "$FORGE_REPO" 2>/dev/null || true
echo "→ Fetching..."
git clone --depth 1 https://github.com/StratosLabs-Aether/forge.git "$FORGE_REPO" 2>/dev/null || { red "Clone failed"; exit 1; }

# ── Download VS Codium ────────────────────────────────────
if [[ ! -f "${FORGE_DIR}/bin/codium" && ! -f "${FORGE_DIR}/codium" ]]; then
  echo "→ Downloading VS Codium..."
  case "$(uname -m)" in
    x86_64) URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-x64-1.96.0.24347.tar.gz" ;;
    aarch64) URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-arm64-1.96.0.24347.tar.gz" ;;
    *) red "Unsupported arch"; exit 1 ;;
  esac
  mkdir -p "$FORGE_DIR"
  TMP="/tmp/forge-vscodium.tar.gz"
  curl -fsSL -o "$TMP" "$URL" || { red "Download failed"; exit 1; }
  tar -xzf "$TMP" -C "$FORGE_DIR"
  rm -f "$TMP"
fi

CODIUM=""
for c in "${FORGE_DIR}/bin/codium" "${FORGE_DIR}/codium"; do
  [[ -f "$c" ]] && { CODIUM="$c"; break; }
done
CODIUM="${CODIUM:-$(find "${FORGE_DIR}" -name codium -type f -not -path '*/resources/*' 2>/dev/null | head -1)}"
[[ -z "$CODIUM" ]] && { red "codium not found"; exit 1; }

# ── Install extensions ────────────────────────────────────
echo "→ Installing extensions..."
rm -rf "${EXT}" 2>/dev/null || true
mkdir -p "${EXT}" "${DATA}/user-data/User"

cp_ext() {
  local src="$1" name="$2"
  local dst="${EXT}/${name}"
  mkdir -p "$dst"
  cp -r "${FORGE_REPO}/extensions/${src}/"* "$dst/"
  green "  ✓ ${name}"
}

cp_ext "aether-language"   "stratos-labs.aether-support"
cp_ext "aether-file-icons" "stratos-labs.aether-file-icons"
cp_ext "aether-scrible"    "stratos-labs.aether-scrible"

# Use folder names that match extension ID (publisher.name)
# The aether-language folder has name "aether-support" in package.json
# VS Codium uses the folder name as fallback ID

# ── Settings ──────────────────────────────────────────────
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

# ── Launcher + Desktop ────────────────────────────────────
mkdir -p ~/.local/bin ~/.local/share/applications
cat > "$FORGE_BIN" <<LAUNCHEOF
#!/usr/bin/env bash
exec "${CODIUM}" --user-data-dir "${DATA}/user-data" --extensions-dir "${EXT}" "\$@"
LAUNCHEOF
chmod +x "$FORGE_BIN"

if [[ -d "${FORGE_REPO}/icons" ]]; then
  mkdir -p "${FORGE_DIR}/share/icons"
  cp "${FORGE_REPO}/icons/forge-256.png" "${FORGE_DIR}/share/icons/forge.png"
fi

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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green "✓ Aether Forge installed!"
echo "  $(bold 'forge')    — launch IDE"
echo "  $(bold 'forge .')  — open current directory"
echo "  F5        — run .ath file"
echo ""
echo "  Scrible AI:  bash ${FORGE_REPO}/install-models.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
