#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
APPIMAGE="$DIR/Aether-Forge-x86_64.AppImage"

# Detect display server and set appropriate flags
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    FLAGS="--no-sandbox --disable-gpu-sandbox --ozone-platform=x11"
elif [ "$XDG_SESSION_TYPE" = "x11" ]; then
    FLAGS="--no-sandbox"
else
    FLAGS="--no-sandbox --disable-gpu-sandbox"
fi

exec "$APPIMAGE" $FLAGS "$@"
