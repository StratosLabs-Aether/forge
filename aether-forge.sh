#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
APPIMAGE="$DIR/Aether-Forge-x86_64.AppImage"

# Rebuild font cache if stale (fixes "no text" on fresh Ubuntu installs)
if ! fc-list 2>/dev/null | grep -q "Noto\|DejaVu\|sans"; then
    echo "Font cache issue detected. Trying to fix..."
    fc-cache -rf 2>/dev/null || true
    # If still no fonts, install them
    if ! fc-list 2>/dev/null | grep -q "Noto\|DejaVu\|sans"; then
        echo ""
        echo "⚠️  No sans-serif fonts found. Install one of:"
        echo "   sudo apt install fonts-noto-core       # Ubuntu/Debian"
        echo "   sudo pacman -S noto-fonts             # Arch"
        echo "   sudo dnf install google-noto-sans-fonts # Fedora"
        echo ""
        echo "Running anyway (text may be missing)..."
    fi
fi

# Detect display server
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    FLAGS="--no-sandbox --disable-gpu-sandbox --ozone-platform=x11"
elif [ "$XDG_SESSION_TYPE" = "x11" ]; then
    FLAGS="--no-sandbox"
else
    FLAGS="--no-sandbox --disable-gpu-sandbox"
fi

exec "$APPIMAGE" $FLAGS "$@"
