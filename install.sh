#!/bin/sh
# Installs (or updates) the widget for the current user.
set -e
cd "$(dirname "$0")"
if kpackagetool6 -t Plasma/Applet --show io.github.andry360.aitoggle >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet --upgrade .
else
    kpackagetool6 -t Plasma/Applet --install .
fi
echo "Done. Right-click the panel -> Add Widgets -> 'AI Toggle'."
