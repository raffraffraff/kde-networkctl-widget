#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Quick build and install script for development

set -e

BUILD_DIR="build"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr}"

echo "=== Building Plasma NetworkCtl Widget ==="
echo "Install prefix: $INSTALL_PREFIX"
echo

# Create build directory
if [ ! -d "$BUILD_DIR" ]; then
    mkdir "$BUILD_DIR"
fi

cd "$BUILD_DIR"

# Configure
echo "→ Configuring..."
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON

# Build
echo "→ Building..."
make -j$(nproc)

# Install
echo "→ Installing (requires sudo)..."
sudo make install

# Restart DBus session bus
echo "→ Restarting DBus session..."
systemctl --user restart dbus || true

echo
echo "=== Installation Complete ==="
echo
echo "To add the widget to your panel:"
echo "  1. Right-click on your panel"
echo "  2. Click 'Add Widgets'"
echo "  3. Search for 'NetworkCtl Widget'"
echo "  4. Add it to your panel"
echo
echo "Or reinstall the plasmoid package:"
echo "  kpackagetool6 --type Plasma/Applet --upgrade plasmoid"
echo
