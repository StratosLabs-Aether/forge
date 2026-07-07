#!/usr/bin/env bash
set -euo pipefail
green() { printf '\033[32m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

FORGE_DIR="${HOME}/.aether-forge"
export PATH="${FORGE_DIR}/bin:${HOME}/.local/bin:${PATH}"

echo ""
bold "⚒  Aether Forge"

# ── VS Codium ─────────────────────────────────────────────
if ! command -v codium &>/dev/null; then
  if [[ ! -f "${FORGE_DIR}/bin/codium" ]]; then
    echo "→ Downloading VS Codium..."
    URL="https://github.com/VSCodium/vscodium/releases/download/1.96.0.24347/VSCodium-linux-x64-1.96.0.24347.tar.gz"
    mkdir -p "$FORGE_DIR"
    curl -fsSL -o /tmp/forge-vsc.tar.gz "$URL"
    tar -xzf /tmp/forge-vsc.tar.gz -C "$FORGE_DIR"
    rm -f /tmp/forge-vsc.tar.gz
  fi
fi
CODIUM="$(which codium 2>/dev/null || echo "${FORGE_DIR}/bin/codium")"
green "✓ VS Codium"

# ── Clone forge repo for extensions ───────────────────────
rm -rf /tmp/forge-ext 2>/dev/null
git clone --depth 1 https://github.com/StratosLabs-Aether/forge.git /tmp/forge-ext 2>/dev/null

# ── Extensions (into portable codium's natural data dir) ──
echo "→ Installing extensions..."
PORTABLE_DATA="${FORGE_DIR}/data"
rm -rf "${PORTABLE_DATA}/extensions" 2>/dev/null
mkdir -p "${PORTABLE_DATA}/extensions"
cp -r /tmp/forge-ext/extensions/aether-language   "${PORTABLE_DATA}/extensions/stratos-labs.aether-support"
cp -r /tmp/forge-ext/extensions/aether-file-icons "${PORTABLE_DATA}/extensions/stratos-labs.aether-file-icons"
cp -r /tmp/forge-ext/extensions/aether-scrible    "${PORTABLE_DATA}/extensions/stratos-labs.aether-scrible"
green "  ✓ Aether extensions"

rm -rf /tmp/forge-ext

# ── Forge settings (in portable codium's natural user-data) ──
FORGE_USERDATA="${PORTABLE_DATA}/user-data"
rm -rf "${FORGE_USERDATA}/User" 2>/dev/null
mkdir -p "${FORGE_USERDATA}/User"

cat > "${FORGE_USERDATA}/User/settings.json" <<'JSONEOF'
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
cat > "${FORGE_USERDATA}/User/keybindings.json" <<'KEYEOF'
[{ "key": "f5", "command": "aether.runCurrentFile", "when": "editorLangId == 'aether'" }]
KEYEOF
green "✓ Settings"

# ── Launcher + Desktop ────────────────────────────────────
mkdir -p ~/.local/bin ~/.local/share/applications "${FORGE_DIR}/icons"
# No --user-data-dir needed — portable codium auto-detects its data/ dir
cat > ~/.local/bin/forge <<LAUNCHEOF
#!/usr/bin/env bash
exec "${CODIUM}" --new-window "\$@"
LAUNCHEOF
chmod +x ~/.local/bin/forge
curl -fsSL "https://raw.githubusercontent.com/StratosLabs-Aether/forge/main/icons/forge-256.png" -o "${FORGE_DIR}/icons/forge.png" 2>/dev/null || true
cat > ~/.local/share/applications/aether-forge.desktop <<DESKEOF
[Desktop Entry]
Name=Aether Forge
Exec=${HOME}/.local/bin/forge %F
Icon=${FORGE_DIR}/icons/forge.png
Terminal=false
Type=Application
Categories=Development;IDE;
DESKEOF
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
green "✓ Launcher"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green "✓ Aether Forge — $(bold 'forge .')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
