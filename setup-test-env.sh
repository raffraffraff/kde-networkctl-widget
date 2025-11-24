#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Create dummy network interfaces for safe testing

set -e

echo "=== Setting up Safe Test Environment ==="
echo "This creates virtual interfaces that won't affect your real network connectivity."
echo

# Check if we're root
if [ "$EUID" -ne 0 ]; then
    echo "This script needs root privileges to create network interfaces."
    echo "Run with: sudo $0"
    exit 1
fi

echo "→ Creating dummy network interfaces..."

# Create dummy interfaces
ip link add dummy0 type dummy 2>/dev/null || echo "  dummy0 already exists"
ip link add dummy1 type dummy 2>/dev/null || echo "  dummy1 already exists"

# Set them up but don't assign any real networking
ip link set dummy0 up
ip link set dummy1 up

echo "  ✓ Created dummy0 (ethernet simulation)"
echo "  ✓ Created dummy1 (can simulate wireless/vpn)"

# Create basic networkd configs for these dummy interfaces
echo "→ Creating systemd-networkd configs for dummy interfaces..."

cat > /etc/systemd/network/10-dummy0.network << 'EOF'
[Match]
Name=dummy0

[Network]
# Safe dummy config - no real networking
Description=Test Ethernet Interface
EOF

cat > /etc/systemd/network/11-dummy1.network << 'EOF'
[Match]
Name=dummy1

[Network]
# Safe dummy config - no real networking  
Description=Test Wireless Interface
EOF

echo "  ✓ Created networkd configs in /etc/systemd/network/"

# Start systemd-networkd but configure it to IGNORE your real interface
echo "→ Configuring systemd-networkd to ignore your real interface..."

# Create a config that explicitly ignores your wireless interface
cat > /etc/systemd/network/00-ignore-real-wifi.network << EOF
[Match]
Name=wlp3s0

[Network]
# Explicitly unmanaged - let NetworkManager handle this
Unmanaged=yes
EOF

echo "  ✓ Configured to ignore wlp3s0 (your real WiFi)"

echo
echo "→ Starting systemd-networkd (safe mode)..."

# Enable and start networkd
systemctl enable systemd-networkd
systemctl start systemd-networkd

# Also start resolved for completeness (but don't override your DNS)
systemctl enable systemd-resolved

echo "  ✓ systemd-networkd is running and managing dummy interfaces only"

echo
echo "=== Test Environment Ready ==="
echo
echo "Safe dummy interfaces created:"
echo "  - dummy0 (simulates ethernet)"
echo "  - dummy1 (simulates wireless/vpn)"
echo "  - wlp3s0 is IGNORED by systemd-networkd"
echo
echo "You can now test the widget with these safe interfaces!"
echo "Your real network connectivity through NetworkManager is preserved."
echo
echo "To test:"
echo "  1. Run ./check-system.sh to verify setup"
echo "  2. Install the widget with ./install.sh"
echo "  3. Test interface control on dummy0 and dummy1"
echo
echo "To clean up later:"
echo "  sudo ip link delete dummy0"
echo "  sudo ip link delete dummy1"
echo