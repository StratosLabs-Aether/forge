#!/usr/bin/env bash
set -euo pipefail
green() { printf '\033[32m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

FORGE_DIR="${HOME}/.aether-forge"

echo ""
bold "⚒  Aether Forge Installer"

# ── Install system VS Codium ──────────────────────────────
if ! command -v codium &>/dev/null; then
  echo "→ Installing VS Codium..."
  wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg 2>/dev/null | gpg --dearmor 2>/dev/null | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null
  echo 'deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main' | sudo tee /etc/apt/sources.list.d/vscodium.list >/dev/null
  sudo apt update -qq && sudo apt install -y codium 2>&1 | tail -1
fi
green "✓ VS Codium"

# ── Install extensions (standard location) ────────────────
echo "→ Installing extensions..."
rm -rf /tmp/forge-ext 2>/dev/null
git clone --depth 1 https://github.com/StratosLabs-Aether/forge.git /tmp/forge-ext 2>/dev/null

EXT_DIR="${HOME}/.vscode-oss/extensions"
mkdir -p "$EXT_DIR"

for ext in aether-language aether-file-icons aether-scrible; do
  case "$ext" in
    aether-language) id="stratos-labs.aether-support" ;;
    aether-file-icons) id="stratos-labs.aether-file-icons" ;;
    aether-scrible) id="stratos-labs.aether-scrible" ;;
  esac
  dst="${EXT_DIR}/${id}"
  rm -rf "$dst" 2>/dev/null
  mkdir -p "$dst"
  cp -r /tmp/forge-ext/extensions/${ext}/* "$dst/"
  green "  ✓ ${id}"
done

# Fix icons to small SVGs
cat > "${EXT_DIR}/stratos-labs.aether-file-icons/aether.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><polygon points="8,1 15,15 1,15" fill="#c084fc" stroke="#8a4fcc" stroke-width="1"/></svg>
EOF
cat > "${EXT_DIR}/stratos-labs.aether-file-icons/aether-glo.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><circle cx="8" cy="8" r="6" fill="#f0c060" stroke="#c09030" stroke-width="1"/><circle cx="8" cy="8" r="2" fill="#0d0d1a"/></svg>
EOF

rm -rf /tmp/forge-ext

# ── Forge-specific settings (isolated user-data) ──────────
FORGE_DATA="${FORGE_DIR}/user-data"
rm -rf "$FORGE_DATA" 2>/dev/null
mkdir -p "${FORGE_DATA}/User"

cat > "${FORGE_DATA}/User/settings.json" <<'JSONEOF'
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
cat > "${FORGE_DATA}/User/keybindings.json" <<'KEYEOF'
[
  { "key": "f5", "command": "aether.runCurrentFile", "when": "editorLangId == 'aether'" }
]
KEYEOF
green "✓ Settings"

# ── Launcher ──────────────────────────────────────────────
mkdir -p ~/.local/bin
cat > ~/.local/bin/forge <<LAUNCHEOF
#!/usr/bin/env bash
exec codium --user-data-dir "${FORGE_DATA}" --new-window "\$@"
LAUNCHEOF
chmod +x ~/.local/bin/forge

# ── Desktop + icon ────────────────────────────────────────
mkdir -p ~/.local/share/applications "${FORGE_DIR}/icons"
curl -fsSL "https://raw.githubusercontent.com/StratosLabs-Aether/forge/main/icons/forge-256.png" -o "${FORGE_DIR}/icons/forge.png" 2>/dev/null || true

cat > ~/.local/share/applications/aether-forge.desktop <<DESKEOF
[Desktop Entry]
Name=Aether Forge
Comment=IDE for the Aether language
Exec=${HOME}/.local/bin/forge %F
Icon=${FORGE_DIR}/icons/forge.png
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
echo "  $(bold 'forge .')   — open in Forge"
echo "  $(bold 'F5')        — run .ath file"
echo "  $(bold 'system VS Code is untouched')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
