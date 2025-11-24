#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later  
# Launch KDE Plasma session for testing without changing your main desktop

echo "=== Testing in KDE Plasma Session ==="
echo
echo "This script helps you test the widget in a KDE Plasma session"
echo "without changing your main XFCE desktop."
echo

# Check if Plasma is available
if ! command -v startplasma-wayland >/dev/null 2>&1 && ! command -v startplasma-x11 >/dev/null 2>&1; then
    echo "KDE Plasma not found. Install with:"
    echo "  sudo zypper install plasma6-desktop"
    exit 1
fi

echo "Options:"
echo "  1. Switch to KDE session temporarily (logout required)"
echo "  2. Test just the plasmoid in XFCE (limited functionality)"
echo "  3. Run Plasma in nested session (if supported)"
echo
echo "For option 1:"
echo "  - Logout from XFCE"
echo "  - On login screen, select 'KDE Plasma'"
echo "  - Login and test the widget"
echo "  - Logout and switch back to XFCE when done"
echo
echo "For option 2:"
echo "  - Install just the plasmoid: ./install-plasmoid-only.sh"
echo "  - Run: plasmoidviewer -a org.kde.plasma.networkctl"
echo "  - This shows the widget UI in demo mode"
echo
echo "Recommendation: Use option 1 with dummy interfaces for full testing."