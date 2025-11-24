#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Install just the plasmoid for testing (requires Qt6/KDE Plasma 6)

set -e

echo "=== Installing Plasma NetworkCtl Widget (plasmoid only) ==="
echo "This installs just the QML widget for testing."
echo "For full functionality, use ./install.sh to install the backend service too."
echo

# Check if we're on Plasma 6
if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Error: kpackagetool6 not found. This requires KDE Plasma 6."
    echo "Install with: sudo zypper install kf6-kpackage-devel"
    exit 1
fi

# Install or upgrade the plasmoid
echo "→ Installing plasmoid..."
if kpackagetool6 --type Plasma/Applet --show org.kde.plasma.networkctl >/dev/null 2>&1; then
    echo "  Upgrading existing installation..."
    kpackagetool6 --type Plasma/Applet --upgrade plasmoid
else
    echo "  Installing new..."
    kpackagetool6 --type Plasma/Applet --install plasmoid
fi

echo
echo "=== Installation Complete ==="
echo
echo "The widget has been installed and will run in DEMO MODE until you:"
echo "1. Install the full backend service with: ./install.sh"
echo "2. Set up systemd-networkd: sudo systemctl enable --now systemd-networkd"
echo
echo "To add the widget to your panel:"
echo "  1. Right-click on your panel"
echo "  2. Click 'Add Widgets'"
echo "  3. Search for 'NetworkCtl Widget'"
echo "  4. Add it to your panel"
echo
echo "Demo mode shows sample interfaces and simulates toggle functionality."
echo