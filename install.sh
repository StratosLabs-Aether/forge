#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Aether Forge — One-command install (VS Codium-based IDE)
# =============================================================================
#   curl -fsSL https://raw.githubusercontent.com/StratosLabs-Aether/forge/main/install.sh | bash
# =============================================================================

bold()  { printf '\033[1m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
warn()  { printf '\033[33m%s\033[0m' "$1" >&2; }
red()   { printf '\033[31m%s\033[0m' "$1"; }

FORGE_DIR="${HOME}/.aether-forge"
EXT_DIR="${HOME}/.vscode-oss/extensions"

echo ""
bold "⚒  Aether Forge Installer"
echo ""

# ── Step 1: Install VS Codium ──────────────────────────────
echo "→ Checking code editor..."
if command -v codium &>/dev/null; then
  green "✓ VS Codium found"
elif command -v code &>/dev/null; then
  warn "VS Code detected — using VS Code instead of Codium."
  EXT_DIR="${HOME}/.vscode/extensions"
  green "✓ VS Code found"
else
  echo "→ Installing VS Codium..."
  if command -v apt &>/dev/null; then
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg 2>/dev/null | gpg --dearmor 2>/dev/null | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main' | sudo tee /etc/apt/sources.list.d/vscodium.list >/dev/null
    sudo apt update -qq && sudo apt install -y codium 2>&1 | tail -1
  elif command -v dnf &>/dev/null; then
    sudo rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg 2>/dev/null
    printf "[vscodium]\nname=VS Codium\nbaseurl=https://download.vscodium.com/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg\n" | sudo tee /etc/yum.repos.d/vscodium.repo >/dev/null
    sudo dnf install -y codium 2>&1 | tail -1
  elif command -v pacman &>/dev/null; then
    yay -S vscodium-bin 2>/dev/null || paru -S vscodium-bin 2>/dev/null || warn "Install VS Codium manually: https://vscodium.com"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    brew install --cask vscodium 2>/dev/null || warn "Install VS Codium manually: https://vscodium.com"
  else
    warn "Could not auto-install VS Codium. Install manually: https://vscodium.com"
  fi
  green "✓ VS Codium installed"
fi

# ── Step 2: Install Aether extensions ─────────────────────
echo "→ Installing Aether Forge extensions..."
mkdir -p "$EXT_DIR"

install_ext() {
  local name="$1" display="$2"
  local dest="${EXT_DIR}/${name}"
  mkdir -p "$dest"
  cp -r "${FORGE_DIR}/extensions/${name}/"* "$dest/"
  green "  ✓ ${display}"
}

install_ext "aether-language"  "Aether Language Support"
install_ext "aether-scrible"   "Scrible AI"

# ── Step 3: Configure settings ────────────────────────────
echo "→ Configuring Aether Forge..."
SETTINGS_DIR="${HOME}/.config/VSCodium/User"
[[ "$EXT_DIR" == *".vscode/extensions" ]] && SETTINGS_DIR="${HOME}/.config/Code/User"
mkdir -p "$SETTINGS_DIR"
SETTINGS_FILE="${SETTINGS_DIR}/settings.json"

if [[ -f "$SETTINGS_FILE" ]] && command -v jq &>/dev/null; then
  jq '
    .["workbench.colorTheme"] = "Aether Dark" |
    .["workbench.iconTheme"] = "aether-seti-icons" |
    .["files.associations"] = ((.["files.associations"] // {}) + {"*.ath": "aether", "*.glo": "aether"}) |
    .["telemetry.telemetryLevel"] = "off" |
    .["update.mode"] = "none" |
    .["extensions.autoUpdate"] = false |
    .["window.title"] = "Aether Forge ${activeEditorShort}"
  ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
else
  cat > "$SETTINGS_FILE" <<'JSONEOF'
{
  "workbench.colorTheme": "Aether Dark",
  "workbench.iconTheme": "aether-seti-icons",
  "files.associations": { "*.ath": "aether", "*.glo": "aether" },
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "window.title": "Aether Forge ${activeEditorShort}"
}
JSONEOF
fi
green "✓ Settings configured"

# ── Step 4: Create launcher ───────────────────────────────
LAUNCHER="${HOME}/.local/bin/forge"
mkdir -p "${HOME}/.local/bin"
cat > "$LAUNCHER" <<'LAUNCHEOF'
#!/usr/bin/env bash
exec codium "$@" 2>/dev/null || exec code "$@"
LAUNCHEOF
chmod +x "$LAUNCHER"
green "✓ Launcher: forge"

# ── Step 5: Models ────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold "✓ Aether Forge installed!"
echo ""
echo "  Launch:   $(bold 'forge')"
echo "  Or:       $(bold 'codium')"
echo ""
echo "  Scrible AI models (optional):"
echo "    cd ${FORGE_DIR} && bash install-models.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
