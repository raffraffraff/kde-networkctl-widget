#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Simple demo without plasmoidviewer dependency issues

echo "=== Simple Demo Test ==="
echo "Installing and testing the plasmoid without dependency conflicts"
echo

# Check if we have kpackagetool6 (should be available if you have KDE installed)
if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 not found. Checking for alternative package managers..."
    
    # Try to find any plasma package tool
    for tool in kpackagetool kpackagetool5; do
        if command -v $tool >/dev/null 2>&1; then
            echo "Found $tool, but we need kpackagetool6 for Plasma 6"
            echo "You may need to install: sudo zypper install kf6-kpackage-devel"
            exit 1
        fi
    done
    
    echo "No KDE package tools found. Install with:"
    echo "  sudo zypper install kf6-kpackage-devel"
    exit 1
fi

# Install the plasmoid
echo "→ Installing plasmoid for current user..."
if kpackagetool6 --type Plasma/Applet --show org.kde.plasma.networkctl >/dev/null 2>&1; then
    echo "  Upgrading existing installation..."
    kpackagetool6 --type Plasma/Applet --upgrade plasmoid
else
    echo "  Installing new..."
    kpackagetool6 --type Plasma/Applet --install plasmoid
fi

echo
echo "✓ Plasmoid installed successfully!"
echo
echo "Testing options:"
echo
echo "1. View the QML files directly:"
echo "   - Main interface: plasmoid/contents/ui/main.qml"
echo "   - Interface item: plasmoid/contents/ui/InterfaceItem.qml"
echo
echo "2. Test in a temporary Plasma session:"
echo "   - Logout from XFCE"  
echo "   - Login with KDE Plasma session"
echo "   - Add widget to panel: Right-click panel → Add Widgets → Search 'NetworkCtl'"
echo "   - Test the widget (will run in demo mode)"
echo "   - Logout and return to XFCE"
echo
echo "3. If you have qmlscene (Qt development):"
if command -v qmlscene >/dev/null 2>&1; then
    echo "   ✓ qmlscene found - you could test with:"
    echo "     cd plasmoid/contents/ui && qmlscene main.qml"
    echo "   (Note: This may have missing dependencies but shows the QML structure)"
else
    echo "   qmlscene not found - install qt6-declarative-devel for this option"
fi

echo
echo "4. Check installation location:"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/org.kde.plasma.networkctl"
if [ -d "$PLASMOID_DIR" ]; then
    echo "   ✓ Plasmoid installed at: $PLASMOID_DIR"
    echo "   You can examine the installed files there."
else
    echo "   Installation directory not found. Check for errors above."
fi

echo
echo "Recommended: Use option 2 (temporary Plasma session) for full testing."
echo "The widget will show demo interfaces and you can test all functionality safely."