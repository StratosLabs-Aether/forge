#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
APPIMAGE="$DIR/Aether-Forge-x86_64.AppImage"

# Fix font issues: rebuild host cache + activate bundled fallback
if command -v fc-cache &>/dev/null; then
    # Rebuild font cache (fixes stale cache on some distros)
    fc-cache -fr 2>/dev/null || true
    
    # Verify fonts are actually found
    if ! fc-list 2>/dev/null | grep -qi "noto\|dejavu\|sans"; then
        echo "⚠️  Font issue detected. Trying to fix..."
        # Force fontconfig to rescan all standard dirs
        for d in /usr/share/fonts /usr/local/share/fonts ~/.fonts ~/.local/share/fonts; do
            [ -d "$d" ] && fc-cache -f "$d" 2>/dev/null || true
        done
        # If STILL no fonts, this is a system issue
        if ! fc-list 2>/dev/null | grep -qi "noto\|dejavu\|sans"; then
            echo ""
            echo "⚠️  No fonts found. Install fonts:"
            echo "   sudo apt install fonts-noto-core fonts-dejavu-core"
            echo ""
        fi
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
