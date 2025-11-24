#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Quick demo test in current XFCE session

echo "=== Quick Demo Test ==="
echo "Testing the plasmoid widget UI in your current XFCE session"
echo

# Check for plasmoidviewer
if ! command -v plasmoidviewer >/dev/null 2>&1; then
    echo "Installing plasmoidviewer..."
    sudo zypper install -y plasma6-sdk || {
        echo "Failed to install plasmoidviewer. You can:"
        echo "1. Install manually: sudo zypper install plasma6-sdk"
        echo "2. Or use the full Plasma session method"
        exit 1
    }
fi

# Install the plasmoid
echo "→ Installing plasmoid for current user..."
if ./install-plasmoid-only.sh; then
    echo "→ Launching widget viewer..."
    echo
    echo "The widget will open in DEMO MODE showing sample interfaces."
    echo "You can interact with the toggle buttons and config dialogs."
    echo "Press Ctrl+C here to close when done testing."
    echo
    
    # Launch the widget viewer
    plasmoidviewer -a org.kde.plasma.networkctl
else
    echo "Failed to install plasmoid. Check the error messages above."
    exit 1
fi