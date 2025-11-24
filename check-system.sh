#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Test script to verify system requirements and networkd setup

echo "=== Plasma NetworkCtl Widget System Check ==="
echo

# Check systemd-networkd
echo "→ Checking systemd-networkd..."
if systemctl is-active --quiet systemd-networkd; then
    echo "  ✓ systemd-networkd is running"
    
    # Test DBus interface
    if busctl --system call org.freedesktop.network1 /org/freedesktop/network1 org.freedesktop.network1.Manager ListLinks >/dev/null 2>&1; then
        echo "  ✓ systemd-networkd DBus interface is accessible"
        
        # Show available interfaces
        echo "  → Available network interfaces:"
        busctl --system call org.freedesktop.network1 /org/freedesktop/network1 org.freedesktop.network1.Manager ListLinks 2>/dev/null | while read line; do
            if [[ $line =~ /org/freedesktop/network1/link/_([0-9]+) ]]; then
                ifindex="${BASH_REMATCH[1]}"
                ifname=$(busctl --system get-property org.freedesktop.network1 "/org/freedesktop/network1/link/_${ifindex}" org.freedesktop.network1.Link Name 2>/dev/null | cut -d'"' -f2)
                if [ ! -z "$ifname" ] && [ "$ifname" != "lo" ]; then
                    echo "    - $ifname"
                fi
            fi
        done
    else
        echo "  ✗ systemd-networkd DBus interface not accessible"
        echo "    Run: sudo systemctl enable --now systemd-networkd"
    fi
else
    echo "  ✗ systemd-networkd is not running"
    echo "    Run: sudo systemctl enable --now systemd-networkd"
fi

echo

# Check Polkit
echo "→ Checking Polkit..."
if systemctl is-active --quiet polkit; then
    echo "  ✓ Polkit is running"
    
    # Check if user has admin privileges
    if groups | grep -q wheel; then
        echo "  ✓ User is in wheel group (has admin privileges)"
    else
        echo "  ⚠ User is not in wheel group"
        echo "    Run: sudo usermod -a -G wheel $USER"
        echo "    Then logout and login again"
    fi
else
    echo "  ✗ Polkit is not running"
    echo "    Run: sudo systemctl enable --now polkit"
fi

echo

# Check development dependencies
echo "→ Checking development dependencies..."

# Check CMake
if command -v cmake >/dev/null 2>&1; then
    cmake_version=$(cmake --version | head -1 | sed 's/cmake version //')
    echo "  ✓ CMake found: $cmake_version"
else
    echo "  ✗ CMake not found"
    echo "    Run: sudo zypper install cmake"
fi

# Check for ECM
if find /usr -name "ECMConfig.cmake" 2>/dev/null | grep -q .; then
    echo "  ✓ Extra CMake Modules (ECM) found"
else
    echo "  ✗ Extra CMake Modules (ECM) not found"
    echo "    Run: sudo zypper install kf6-extra-cmake-modules-devel"
fi

# Check for Qt6
if pkg-config --exists Qt6Core 2>/dev/null; then
    qt6_version=$(pkg-config --modversion Qt6Core)
    echo "  ✓ Qt6 development found: $qt6_version"
else
    echo "  ✗ Qt6 development not found"
    echo "    Run: sudo zypper install qt6-base-devel qt6-declarative-devel"
fi

# Check for KF6 KAuth
if find /usr -name "KF6AuthConfig.cmake" 2>/dev/null | grep -q .; then
    echo "  ✓ KF6 KAuth development found"
else
    echo "  ✗ KF6 KAuth development not found"
    echo "    Run: sudo zypper install kf6-kauth-devel"
fi

echo

# Test manual DBus calls
echo "→ Testing manual networkctl operations..."
if command -v qdbus >/dev/null 2>&1; then
    echo "  ✓ qdbus tool available for testing"
    echo "  → You can test networkctl commands manually:"
    echo "    networkctl list"
    echo "    networkctl status <interface>"
    echo "    sudo networkctl up <interface>"
    echo "    sudo networkctl down <interface>"
else
    echo "  ✗ qdbus tool not found"
    echo "    Run: sudo zypper install qt6-tools"
fi

echo

if systemctl is-active --quiet systemd-networkd && systemctl is-active --quiet polkit; then
    echo "=== System is ready for Plasma NetworkCtl Widget ==="
    echo "You can now run: ./install.sh"
else
    echo "=== System setup required ==="
    echo "Please follow the instructions above, then run this script again."
fi

echo