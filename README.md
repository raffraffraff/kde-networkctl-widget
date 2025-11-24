# Plasma NetworkCtl Widget

KDE Plasma 6 widget for controlling systemd-networkd network interfaces with proper privilege separation following KDE's recommended architecture.

![License](https://img.shields.io/badge/license-GPL--2.0--or--later-blue)
![Plasma](https://img.shields.io/badge/Plasma-6-blue)
![Qt](https://img.shields.io/badge/Qt-6.6%2B-green)

---

## Features

### 🎨 User Interface
- **Interface Grouping**: Organized by type (Ethernet, Wireless, VPN)
- **Visual Status Indicators**: Color-coded operational states
- **Toggle Controls**: Bring interfaces up/down with authentication
- **Real-time Updates**: Automatic refresh every 5 seconds
- **Demo Mode**: Test the widget without affecting real network settings

### 🔐 Security
- **Polkit Authentication**: Admin password required for changes
- **No SUID Binaries**: Uses KAuth/Polkit standard
- **Minimal Privileges**: Helper only performs necessary operations
- **Audit-friendly**: All operations logged through Polkit

### 🏗️ Architecture
```
[Plasmoid (QML)] ←DBus→ [Session Service (C++)] ←KAuth/Polkit→ [Root Helper] ←DBus→ [systemd-networkd]
```

Follows the same pattern as KDE's official widgets (plasma-nm, PowerDevil, etc.)

---

## Quick Start

### Install from RPM (Recommended)

```bash
# Build the RPM
mkdir build && cd build
cmake ..
make package

# Install
sudo rpm -i plasma6-applet-networkctl-1.0.0-1.x86_64.rpm

# Restart Plasma
kquitapp6 plasmashell && kstart plasmashell
```

### Add to Panel

1. Right-click on your panel or desktop
2. Select "Add Widgets..."
3. Search for "NetworkCtl"
4. Add the widget to your panel

---

## Requirements

### Runtime
- **KDE Plasma 6**
- **systemd-networkd** (for network management)
- **Polkit** (for authentication)

### Build Dependencies (openSUSE Tumbleweed)
```bash
sudo zypper install \
    cmake ninja gcc-c++ \
    extra-cmake-modules \
    kf6-kcoreaddons-devel \
    kf6-ki18n-devel \
    kf6-kauth-devel \
    libQt6Core-devel \
    libQt6DBus-devel \
    libQt6Widgets-devel \
    plasma6-framework-devel \
    polkit-devel \
    systemd-network
```

<details>
<summary>Fedora Dependencies</summary>

```bash
sudo dnf install \
    cmake ninja-build gcc-c++ \
    extra-cmake-modules \
    kf6-kcoreaddons-devel \
    kf6-ki18n-devel \
    kf6-kauth-devel \
    qt6-qtbase-devel \
    qt6-qtdeclarative-devel \
    plasma-workspace-devel \
    polkit-devel \
    systemd-devel
```
</details>

<details>
<summary>Arch Linux Dependencies</summary>

```bash
sudo pacman -S \
    cmake ninja gcc \
    extra-cmake-modules \
    kcoreaddons ki18n kauth \
    qt6-base qt6-declarative \
    plasma-workspace \
    polkit systemd
```
</details>

---

## Building

### Option 1: RPM Package (Production)

```bash
mkdir build && cd build
cmake ..
make package
```

Produces: `plasma6-applet-networkctl-1.0.0-1.x86_64.rpm`

**Install:**
```bash
sudo rpm -i plasma6-applet-networkctl-1.0.0-1.x86_64.rpm
```

**Upgrade:**
```bash
sudo rpm -U plasma6-applet-networkctl-1.0.0-1.x86_64.rpm
```

**Uninstall:**
```bash
sudo rpm -e plasma6-applet-networkctl
```

### Option 2: Direct Install (Development)

```bash
mkdir build && cd build
cmake ..
make
sudo make install
```

### Restart Plasma

After installation:
```bash
kquitapp6 plasmashell && kstart plasmashell
```

Or:
```bash
systemctl --user restart plasma-plasmashell
```

---

## Configuration

### Widget Settings

Right-click the widget → "Configure NetworkCtl Widget..."

**Demo Mode**: Enable to use sample data instead of real interfaces. Useful for:
- Testing the widget UI without backend service
- Previewing interface layout
- Safe experimentation without affecting network

### systemd-networkd Setup

To manage interfaces with this widget, they must be configured in systemd-networkd.

**Example: Ethernet with DHCP**
```bash
sudo tee /etc/systemd/network/10-ethernet.network << EOF
[Match]
Name=en*

[Network]
DHCP=yes
EOF

sudo systemctl restart systemd-networkd
```

**Example: Static IP**
```bash
sudo tee /etc/systemd/network/20-wired.network << EOF
[Match]
Name=eth0

[Network]
Address=192.168.1.100/24
Gateway=192.168.1.1
DNS=8.8.8.8
EOF

sudo systemctl restart systemd-networkd
```

See `man systemd.network` for full configuration options.

---

## Testing

### Safe Testing Without Breaking Your Network

**Problem:** You can't risk breaking your working network connection!

**Solution:** Use dummy interfaces for testing

```bash
# Create dummy interfaces
sudo ip link add dummy0 type dummy
sudo ip link add dummy1 type dummy

# Configure systemd-networkd for dummies
sudo tee /etc/systemd/network/10-dummy.network << EOF
[Match]
Name=dummy*

[Network]
DHCP=no
Address=192.168.99.1/24
EOF

# Restart networkd
sudo systemctl restart systemd-networkd
```

**Important:** Don't create .network files for your real interfaces. The widget will see all interfaces but only manage those with systemd-networkd configurations.

### Testing DBus Service

```bash
# Check if service is running
ps aux | grep plasma-networkctl-service

# Call methods directly
qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.ListInterfacesJSON

# Monitor DBus traffic
dbus-monitor --session "interface='org.kde.plasma.networkctl'"
```

### Testing Authentication

```bash
# Check Polkit policy
pkaction --verbose --action-id org.kde.plasma.networkctl.setup

# Test if you're authorized
pkcheck --action-id org.kde.plasma.networkctl.setup --process $$
```

---

## Project Structure

```
kde-networkctl-widget/
├── CMakeLists.txt              # Main build configuration
├── README.md                   # This file
├── DEVELOPMENT.md              # Comprehensive development guide
│
├── service/                    # DBus service (user session)
│   ├── networkctlservice.cpp/h
│   ├── org.kde.plasma.networkctl.xml
│   ├── org.kde.plasma.networkctl.service
│   └── main.cpp
│
├── helper/                     # KAuth helper (runs as root)
│   ├── networkctlhelper.cpp/h
│   ├── org.kde.plasma.networkctl.actions
│   └── org.kde.plasma.networkctl.policy.in
│
└── plasmoid/                   # Plasma widget (QML)
    ├── metadata.json
    └── contents/
        ├── config/
        │   ├── main.xml        # Settings schema
        │   └── config.qml      # Config pages
        └── ui/
            ├── main.qml        # Main interface
            ├── InterfaceItem.qml
            └── configGeneral.qml
```

---

## How It Works

### Component Interaction

1. **User clicks "Enable eth0" in widget**
2. **Plasmoid** calls DBus method: `org.kde.plasma.networkctl.SetUp("eth0")`
3. **DBus Service** receives call, triggers KAuth action
4. **Polkit** checks if user is authorized:
   - If yes → Executes helper silently
   - If no → Prompts for admin password
5. **KAuth Helper** runs as root, calls systemd-networkd via DBus
6. **systemd-networkd** brings interface up
7. **Result** flows back to widget, status updates

### Why This Architecture?

This is the **only correct way** to perform privileged operations in Plasma 6:

❌ **Don't:** SUID binaries, sudo scripts, pkexec wrappers  
✅ **Do:** DBus → KAuth → Polkit (the KDE way)

**Benefits:**
- Proper privilege separation
- Secure by design
- Audit trail
- Follows KDE standards
- Future-proof

---

## Troubleshooting

### Widget Shows "Connecting to service..."

**Cause:** DBus service not running or not returning data

**Fix:**
```bash
# Check if service is running
ps aux | grep plasma-networkctl-service

# Try calling it manually
qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.ListInterfacesJSON

# Check logs
journalctl --user -f | grep networkctl
```

### No Interfaces Shown

**Cause:** systemd-networkd not managing any interfaces

**Fix:**
1. Ensure systemd-networkd is running: `systemctl status systemd-networkd`
2. Create .network files in `/etc/systemd/network/`
3. Restart systemd-networkd: `sudo systemctl restart systemd-networkd`
4. Verify: `networkctl list`

### Authentication Fails

**Cause:** Polkit policy not installed or user not in admin group

**Fix:**
```bash
# Check policy installed
ls -l /usr/share/polkit-1/actions/org.kde.plasma.networkctl.policy

# Check if you're in wheel group (openSUSE)
groups $USER | grep wheel

# Add to wheel if needed
sudo usermod -a -G wheel $USER
```

### Widget Won't Load

**Cause:** Missing Plasma 6 compatibility metadata

**Fix:** Widget must have in `metadata.json`:
```json
{
  "X-Plasma-API-Minimum-Version": "6.0",
  "KPackageStructure": "Plasma/Applet"
}
```

And all QML imports must have version numbers.

---

## Development

For detailed development information including Plasma 6 requirements, gotchas, and solutions, see **[DEVELOPMENT.md](DEVELOPMENT.md)**.

Topics covered:
- Architecture patterns
- Plasma 6-specific requirements (MANDATORY reading!)
- CMake configuration gotchas
- systemd-networkd DBus integration
- Testing strategies
- Common issues and solutions
- Complete package requirements

---

## Contributing

Contributions welcome! Areas for improvement:

- [ ] Add more interface types (bridge, bond, vlan)
- [ ] Show IP addresses and routes
- [ ] Add network statistics (bandwidth, packets)
- [ ] Configurable refresh intervals
- [ ] Custom icon support
- [ ] Localization (i18n)

When contributing:
1. Read [DEVELOPMENT.md](DEVELOPMENT.md) first
2. Follow KDE coding standards
3. Test with dummy interfaces
4. Ensure Polkit integration works correctly
5. Add appropriate logging

---

## License

GPL-2.0-or-later

This project follows KDE's licensing practices.

---

## Acknowledgments

- **KDE Community** for excellent documentation
- **systemd-networkd** for clean DBus interfaces
- **Plasma team** for the extensible widget framework

Built following patterns from official KDE widgets like plasma-nm and PowerDevil.

---

## Support

- **Issues:** Report bugs via GitHub issues
- **Development Guide:** See [DEVELOPMENT.md](DEVELOPMENT.md)
- **KDE Documentation:** https://develop.kde.org/
- **systemd-networkd:** `man systemd.network`, `man networkctl`

---

## Version History

### 1.0.0 (2025-11-24)
- Initial release
- Full Plasma 6 support
- systemd-networkd integration via DBus
- KAuth/Polkit authentication
- Demo mode
- RPM packaging
- Comprehensive documentation

---

**Status:** ✅ Fully functional on KDE Plasma 6 with systemd-networkd

*A properly architected Plasma widget demonstrating the correct way to handle privileged operations.*
