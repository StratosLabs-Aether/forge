#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
APPIMAGE="$DIR/Aether-Forge-x86_64.AppImage"

# --- Don't run as root ---
if [ "$(id -u)" = "0" ]; then
    echo "❌ Do NOT run with sudo. Run as your normal user:"
    echo "   chmod +x Aether-Forge-x86_64.AppImage"
    echo "   ./aether-forge.sh"
    exit 1
fi

# --- Make sure AppImage is executable ---
if [ ! -x "$APPIMAGE" ]; then
    echo "🔧 Making AppImage executable..."
    chmod +x "$APPIMAGE"
fi

# --- Rebuild font cache if stale ---
if command -v fc-cache &>/dev/null; then
    fc-cache -fr 2>/dev/null || true
fi

# --- Detect display server ---
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    FLAGS="--no-sandbox --disable-gpu-sandbox --ozone-platform=x11"
elif [ "$XDG_SESSION_TYPE" = "x11" ]; then
    FLAGS="--no-sandbox"
else
    FLAGS="--no-sandbox --disable-gpu-sandbox"
fi

exec "$APPIMAGE" $FLAGS "$@"
