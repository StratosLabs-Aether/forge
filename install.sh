#!/usr/bin/env bash
set -euo pipefail
green() { printf '\033[32m%s\033[0m\n' "$1"; }
echo ""
echo "⚒  Aether Forge Installer"

# ── Install VS Codium ─────────────────────────────────────
if ! command -v codium &>/dev/null && ! command -v code &>/dev/null; then
  echo "→ Installing VS Codium..."
  wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg 2>/dev/null | gpg --dearmor 2>/dev/null | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null
  echo 'deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main' | sudo tee /etc/apt/sources.list.d/vscodium.list >/dev/null
  sudo apt update -qq && sudo apt install -y codium 2>&1 | tail -1
fi
green "✓ VS Codium"

# ── Clone forge & copy extensions ─────────────────────────
echo "→ Installing Aether extensions..."
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
rm -rf /tmp/forge-ext

# ── Settings ──────────────────────────────────────────────
DIR="${HOME}/.config/VSCodium/User"
mkdir -p "$DIR"

cat > "${DIR}/settings.json" <<'JSONEOF'
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
cat > "${DIR}/keybindings.json" <<'JSONEOF'
[
  { "key": "f5", "command": "aether.runCurrentFile", "when": "editorLangId == 'aether'" }
]
JSONEOF
green "✓ Settings"

# ── Desktop entry ─────────────────────────────────────────
mkdir -p ~/.local/bin ~/.local/share/applications ~/.aether-forge/icons
ln -sf "$(which codium 2>/dev/null || which code)" ~/.local/bin/forge 2>/dev/null
curl -fsSL "https://raw.githubusercontent.com/StratosLabs-Aether/forge/main/icons/forge-256.png" -o ~/.aether-forge/icons/forge.png 2>/dev/null

cat > ~/.local/share/applications/aether-forge.desktop <<DESKEOF
[Desktop Entry]
Name=Aether Forge
Exec=codium %F
Icon=${HOME}/.aether-forge/icons/forge.png
Terminal=false
Type=Application
Categories=Development;IDE;
DESKEOF
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
green "✓ Desktop entry"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green "✓ Aether Forge installed!"
echo "  codium .   — launch"
echo "  F5         — run .ath file"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
