#!/usr/bin/env bash
set -euo pipefail
green() { printf '\033[32m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

FORGE_DIR="${HOME}/.aether-forge"
export PATH="${FORGE_DIR}/bin:${HOME}/.local/bin:${PATH}"

echo ""
bold "⚒  Aether Forge"

# ── Get VS Codium ─────────────────────────────────────────
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

# ── Clone forge for extensions ────────────────────────────
rm -rf /tmp/forge-ext 2>/dev/null
git clone --depth 1 https://github.com/StratosLabs-Aether/forge.git /tmp/forge-ext 2>/dev/null

# ── Install via .vsix ─────────────────────────────────────
echo "→ Installing extensions..."
"$CODIUM" --install-extension /tmp/forge-ext/extensions/aether-support.vsix --force 2>/dev/null
green "  ✓ Aether Language"
"$CODIUM" --install-extension /tmp/forge-ext/extensions/aether-icons.vsix --force 2>/dev/null
green "  ✓ Aether Icons"

# Scrible: copy source (no .vsix)
SCRIBLE_DIR="${HOME}/.vscode-oss/extensions/stratos-labs.aether-scrible"
rm -rf "$SCRIBLE_DIR" 2>/dev/null
mkdir -p "$SCRIBLE_DIR"
cp -r /tmp/forge-ext/extensions/aether-scrible/* "$SCRIBLE_DIR/"
green "  ✓ Scrible AI"

rm -rf /tmp/forge-ext

# ── Forge settings ────────────────────────────────────────
FORGE_DATA="${FORGE_DIR}/user-data"
mkdir -p "${FORGE_DATA}/User"
cat > "${FORGE_DATA}/User/settings.json" <<'JSONEOF'
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
cat > "${FORGE_DATA}/User/keybindings.json" <<'KEYEOF'
[{ "key": "f5", "command": "aether.runCurrentFile", "when": "editorLangId == 'aether'" }]
KEYEOF
green "✓ Settings"

# ── Launcher + Desktop ────────────────────────────────────
mkdir -p ~/.local/bin ~/.local/share/applications "${FORGE_DIR}/icons"
cat > ~/.local/bin/forge <<LAUNCHEOF
#!/usr/bin/env bash
exec "${CODIUM}" --user-data-dir "${FORGE_DATA}" --new-window "\$@"
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

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green "✓ Aether Forge installed — $(bold 'forge .')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
