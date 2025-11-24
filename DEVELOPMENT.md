# KDE Plasma 6 Widget Development Guide

**Complete guide for developing KDE Plasma 6 widgets with privileged backend operations**

This document consolidates all knowledge gained from building the NetworkCtl widget, including architecture patterns, Plasma 6-specific requirements, common gotchas, and solutions.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Why This Architecture](#why-this-architecture)
3. [Plasma 6 Critical Requirements](#plasma-6-critical-requirements)
4. [Component Implementation](#component-implementation)
5. [CMake Configuration](#cmake-configuration)
6. [systemd-networkd Integration](#systemd-networkd-integration)
7. [Build & Installation](#build--installation)
8. [Testing Strategy](#testing-strategy)
9. [Common Issues & Solutions](#common-issues--solutions)
10. [Required Packages](#required-packages)

---

## Architecture Overview

### The Only Correct Pattern for Privileged Operations

```
[Plasmoid (QML/JS)] ←DBus→ [User Session Service (C++)] ←KAuth/Polkit→ [Root Helper (C++)] ←DBus→ [System Service]
```

**This is how KDE's official widgets work:**
- plasma-nm (Network Management)
- PowerDevil (Power Management)  
- KDE Wallet
- KDE Connect

### Why Plasma Widgets Cannot Run Commands Directly

Plasma 6's QML/JS runtime is **intentionally sandboxed**:
- Cannot spawn external processes
- Cannot access system files
- **Only DBus communication is allowed**

This is a security feature, not a limitation.

---

## Why This Architecture

### The Wrong Approaches (Don't Do These)

❌ **SUID binaries** - Security nightmare, discouraged by all modern systems  
❌ **sudo in scripts** - Breaks when run as non-interactive user, bad UX  
❌ **pkexec wrappers** - Plasma can't integrate, poor user experience  
❌ **Shelling out from QML** - Simply not allowed in Plasma 6

### The Right Approach

✅ **DBus Service** - Stable, trusted entry point your plasmoid calls  
✅ **KAuth Helper** - Runs as root only when Polkit authorizes it  
✅ **Polkit Policy** - Fine-grained permission control with user authentication  

**Benefits:**
- Follows KDE standards
- Proper privilege separation
- Audit-friendly (all actions logged)
- Clean user experience
- Future-proof

---

## Plasma 6 Critical Requirements

### 1. QML Import Version Numbers (MANDATORY)

All QML imports **MUST** have explicit version numbers:

```qml
import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as Plasma5Support
```

**Without versions:** Widget fails with "widget was written for unknown older version"

### 2. Plasmoid Metadata API Version (MANDATORY)

In `metadata.json`:

```json
{
  "KPlugin": {
    "Id": "org.kde.plasma.yourwidget",
    "Name": "Your Widget Name"
  },
  "KPackageStructure": "Plasma/Applet",
  "X-Plasma-API-Minimum-Version": "6.0"
}
```

The `X-Plasma-API-Minimum-Version` field is **required** for Plasma 6.

### 3. Configuration Pages

To add settings to your widget, you need:

**config/main.xml** - Define settings:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<kcfg xmlns="http://www.kde.org/standards/kcfg/1.0">
  <kcfgfile name=""/>
  <group name="General">
    <entry name="demoMode" type="Bool">
      <default>false</default>
    </entry>
  </group>
</kcfg>
```

**config/config.qml** - Define config pages:
```qml
import QtQuick 2.0
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: "General"
        icon: "preferences-system"
        source: "configGeneral.qml"
    }
}
```

**ui/configGeneral.qml** - Config UI:
```qml
import org.kde.kirigami 2.20 as Kirigami
import QtQuick.Controls 2.15 as QQC2

Kirigami.FormLayout {
    property alias cfg_demoMode: checkbox.checked
    
    QQC2.CheckBox {
        id: checkbox
        Kirigami.FormData.label: "Demo Mode:"
        text: "Description"
    }
}
```

Access in main.qml: `plasmoid.configuration.demoMode`

### 4. QtDBus Not Available in QML

**You cannot use `import QtDBus` in Plasma 6!**

#### Solution A: Use Plasma5Support.DataSource (Simple but Limited)

```qml
import org.kde.plasma.plasma5support 2.0 as Plasma5Support

Plasma5Support.DataSource {
    id: dbusService
    engine: "executable"
    connectedSources: []
    
    onNewData: function(sourceName, data) {
        var stdout = data["stdout"]
        if (stdout) {
            var result = JSON.parse(stdout)
            // Process result
        }
        disconnectSource(sourceName)
    }
    
    function callMethod(method, args) {
        var cmd = "qdbus6 org.your.service /Path org.your.service." + method
        connectSource(cmd)
    }
}
```

**Note:** This shells out to qdbus6, which may not capture stdout properly in all cases.

#### Solution B: Return JSON from DBus Methods (Recommended)

Add a JSON-returning method to your service:

```cpp
// In service header
public Q_SLOTS:
    QString ListInterfacesJSON();  // Returns JSON string

// In service implementation
QString NetworkCtlService::ListInterfacesJSON()
{
    QVariantList interfaces = ListInterfaces();
    QJsonArray jsonArray;
    
    for (const QVariant &item : interfaces) {
        QVariantMap map = item.toMap();
        QJsonObject jsonObj = QJsonObject::fromVariantMap(map);
        jsonArray.append(jsonObj);
    }
    
    QJsonDocument doc(jsonArray);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}
```

Then call via qdbus6 which returns the JSON string that QML can parse.

---

## Component Implementation

### 1. DBus Service (User Session)

**Purpose:** Runs as user, interfaces between plasmoid and system

**Key Files:**
- `service/networkctlservice.h/cpp` - Implementation
- `service/org.kde.plasma.networkctl.xml` - DBus interface definition
- `service/org.kde.plasma.networkctl.service` - DBus activation file

**Critical Details:**

```cpp
// Register custom DBus types
Q_DECLARE_METATYPE(NetworkLink)

struct NetworkLink {
    int index;
    QString name;
    QDBusObjectPath path;
};

// DBus marshalling operators (REQUIRED)
QDBusArgument &operator<<(QDBusArgument &argument, const NetworkLink &link) {
    argument.beginStructure();
    argument << link.index << link.name << link.path;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, NetworkLink &link) {
    argument.beginStructure();
    argument >> link.index >> link.name >> link.path;
    argument.endStructure();
    return argument;
}

// In constructor
qDBusRegisterMetaType<NetworkLink>();
```

**DBus Activation File:**
```ini
[D-BUS Service]
Name=org.kde.plasma.networkctl
Exec=/usr/lib64/libexec/plasma-networkctl-service
```

### 2. KAuth Helper (Privileged Operations)

**Purpose:** Runs as root when authorized by Polkit

**Key Files:**
- `helper/networkctlhelper.h/cpp` - Implementation
- `helper/org.kde.plasma.networkctl.actions` - Action definitions
- `helper/org.kde.plasma.networkctl.policy.in` - Polkit policy

**Helper Implementation:**

```cpp
#include <KAuth/ActionReply>
#include <KAuth/HelperSupport>

using namespace KAuth;

class NetworkCtlHelper : public QObject
{
    Q_OBJECT
public Q_SLOTS:
    ActionReply setup(const QVariantMap &args);
};

ActionReply NetworkCtlHelper::setup(const QVariantMap &args)
{
    QString interface = args["interface"].toString();
    QString action = args["action"].toString();
    
    // Perform privileged operation
    // ...
    
    return ActionReply::SuccessReply();
}

KAUTH_HELPER_MAIN("org.kde.plasma.networkctl", NetworkCtlHelper)
```

**Actions File:**
```ini
[org.kde.plasma.networkctl.setup]
Name=Control Network Interface
Description=Bring network interface up or down
Policy=yes
Persistence=session
```

**Polkit Policy:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
"http://www.freedesktop.org/software/polkit/policyconfig-1.dtd">
<policyconfig>
  <action id="org.kde.plasma.networkctl.setup">
    <description>Control network interface</description>
    <message>Authentication is required to control network interfaces</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
  </action>
</policyconfig>
```

### 3. Plasmoid (QML User Interface)

**Key Files:**
- `plasmoid/metadata.json` - Widget metadata
- `plasmoid/contents/ui/main.qml` - Main UI
- `plasmoid/contents/config/main.xml` - Configuration schema
- `plasmoid/contents/config/config.qml` - Config pages definition

**Calling DBus from QML:**

```qml
function callService() {
    var cmd = "qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.ListInterfacesJSON"
    dbusService.connectSource(cmd)
}
```

---

## CMake Configuration

### Package Names for Plasma 6

```cmake
cmake_minimum_required(VERSION 3.16)
project(plasma-networkctl VERSION 1.0.0)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

# Use Qt6 and KF6 (not Qt5/KF5!)
find_package(Qt6 REQUIRED COMPONENTS Core DBus Widgets)
find_package(KF6 REQUIRED COMPONENTS Auth CoreAddons I18n Plasma)
```

### Critical CMake Gotchas

#### 1. Link Against KF6::AuthCore NOT KF6::Auth

```cmake
# WRONG - KF6::Auth target doesn't exist!
target_link_libraries(helper KF6::Auth)

# CORRECT
target_link_libraries(helper KF6::AuthCore)
```

#### 2. Polkit Policy Installation Path

```cmake
# WRONG - Variable doesn't exist in KF6
install(FILES policy.xml 
        DESTINATION ${POLKITQT-1_POLICY_FILES_INSTALL_DIR})

# CORRECT
install(FILES policy.xml
        DESTINATION ${KDE_INSTALL_DATADIR}/polkit-1/actions)
```

#### 3. Helper Installation Path

```cmake
kauth_install_helper_files(helper org.kde.plasma.networkctl root)
kauth_install_actions(org.kde.plasma.networkctl actions)

install(TARGETS helper 
        DESTINATION ${KDE_INSTALL_LIBEXECDIR}/kf6/kauth)
```

### RPM Package Generation

Add to root CMakeLists.txt:

```cmake
# CPack configuration
set(CPACK_GENERATOR "RPM")
set(CPACK_PACKAGE_NAME "plasma6-applet-yourwidget")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_RPM_PACKAGE_LICENSE "GPL-2.0-or-later")
set(CPACK_RPM_PACKAGE_REQUIRES "systemd-network, plasma6-workspace")

include(CPack)
```

Build RPM:
```bash
make package
```

---

## systemd-networkd Integration

### DBus Interface Details

**Service:** `org.freedesktop.network1`  
**Manager Object:** `/org/freedesktop/network1`  
**Link Objects:** `/org/freedesktop/network1/link/_<index>`

### ListLinks Returns Structs NOT Object Paths

**CRITICAL:** `ListLinks()` returns `a(iso)` not `ao`!

```cpp
// WRONG - Will fail!
QDBusReply<QList<QDBusObjectPath>> reply = manager.call("ListLinks");

// CORRECT - Use custom struct
struct NetworkLink {
    int index;           // i
    QString name;        // s  
    QDBusObjectPath path; // o
};

QDBusReply<QList<NetworkLink>> reply = manager.call("ListLinks");
```

### Link Properties

Available on `org.freedesktop.network1.Link` interface:

- `IfIndex` (int) - Interface index
- `Name` (string) - Interface name (e.g., "eth0")
- `OperationalState` (string) - "off", "carrier", "degraded", "routable"
- `AdministrativeState` (string) - "unmanaged", "pending", "configuring", "configured"
- `Type` (string) - "ether", "wlan", etc.
- `SetupState` (string) - Configuration status

### Calling Methods on Links

```cpp
// Bring interface up
QDBusInterface linkIface("org.freedesktop.network1",
                         linkPath,
                         "org.freedesktop.network1.Link",
                         QDBusConnection::systemBus());

linkIface.call("SetUp");  // Requires root via KAuth
linkIface.call("SetDown");
```

---

## Build & Installation

### Install Required Packages

**openSUSE Tumbleweed:**
```bash
sudo zypper install cmake ninja gcc-c++ \
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

### Build from Source

```bash
mkdir build && cd build
cmake ..
make
```

### Create RPM Package (Recommended)

```bash
make package
```

Produces: `plasma6-applet-yourwidget-1.0.0-1.x86_64.rpm`

Install:
```bash
sudo rpm -i *.rpm
```

### Direct System Install (Development)

```bash
sudo make install
```

### Restart Plasma

After installation:
```bash
kquitapp6 plasmashell && kstart plasmashell
```

Or just:
```bash
systemctl --user restart plasma-plasmashell
```

---

## Testing Strategy

### Safe Testing Without Breaking Network

**Problem:** You can't test on your production network connection!

**Solution:** Use dummy interfaces

1. **Create dummy interfaces:**
```bash
sudo ip link add dummy0 type dummy
sudo ip link add dummy1 type dummy
sudo ip link set dummy0 up
sudo ip link set dummy1 up
```

2. **Create systemd-networkd config for dummies:**
```bash
sudo tee /etc/systemd/network/10-dummy.network << EOF
[Match]
Name=dummy*

[Network]
DHCP=no
Address=192.168.99.1/24
EOF

sudo systemctl restart systemd-networkd
```

3. **DO NOT create .network files for real interfaces**

The widget will see all interfaces but only manage those with .network files.

### Testing DBus Service Directly

```bash
# Check if service is running
ps aux | grep plasma-networkctl-service

# Call methods directly
qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.ListInterfacesJSON

# Monitor DBus activation
dbus-monitor --session "interface='org.kde.plasma.networkctl'"
```

### Testing KAuth Helper

```bash
# Check if helper is installed
ls -l /usr/libexec/kf6/kauth/plasma-networkctl-helper

# Check Polkit policy
pkaction --verbose --action-id org.kde.plasma.networkctl.setup

# Test authentication
pkcheck --action-id org.kde.plasma.networkctl.setup --process $$
```

### Demo Mode for UI Testing

Add a config option for mock data:

```qml
property bool mockMode: plasmoid.configuration.demoMode

function loadMockData() {
    interfaces = [
        {name: "eth0", type: "ethernet", operationalState: "routable"},
        {name: "wlan0", type: "wireless", operationalState: "carrier"}
    ]
}

Component.onCompleted: {
    if (mockMode) {
        loadMockData()
    } else {
        refreshInterfaces()
    }
}
```

---

## Common Issues & Solutions

### "QDBusArgument: write from a read-only object"

**Cause:** Missing DBus marshalling operators for custom struct

**Solution:** Implement `operator<<` and `operator>>`:

```cpp
QDBusArgument &operator<<(QDBusArgument &argument, const YourStruct &obj) {
    argument.beginStructure();
    argument << obj.field1 << obj.field2;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, YourStruct &obj) {
    argument.beginStructure();
    argument >> obj.field1 >> obj.field2;
    argument.endStructure();
    return argument;
}

// Register with DBus
qDBusRegisterMetaType<YourStruct>();
```

### "Widget was written for unknown older version"

**Cause:** Missing version numbers on QML imports or missing API version in metadata

**Solution:**
1. Add version to ALL imports: `import QtQuick 2.15`
2. Add to metadata.json: `"X-Plasma-API-Minimum-Version": "6.0"`

### "KF6::Auth target not found"

**Cause:** Wrong CMake target name

**Solution:** Use `KF6::AuthCore` not `KF6::Auth`

### Helper Not Loading / Authentication Fails

**Causes:**
1. Helper not at expected path
2. Actions file has wrong path
3. Polkit policy not installed
4. User not in admin group

**Debug:**
```bash
# Check helper location
find /usr -name "*your-helper*" 2>/dev/null

# Check if path in actions file matches
cat /usr/share/kauth/*.actions | grep Exec

# Verify polkit policy
ls -l /usr/share/polkit-1/actions/org.*.policy

# Check user groups
groups $USER | grep wheel
```

### DataSource Not Calling onNewData

**Cause:** Plasma5Support.DataSource with executable engine sometimes doesn't capture stdout

**Solutions:**
1. Make your service return JSON from a dedicated method
2. Use simpler commands that definitely produce output
3. Add extensive logging to debug what's happening

```qml
onNewData: function(sourceName, data) {
    console.log("Command:", sourceName)
    console.log("Exit code:", data["exit code"])
    console.log("Stdout:", data["stdout"])
    console.log("Stderr:", data["stderr"])
    console.log("All keys:", Object.keys(data))
}
```

### Service Not Auto-Starting

**Cause:** DBus activation file not installed or wrong path

**Solution:**
```bash
# Check activation file exists
ls -l /usr/share/dbus-1/services/org.*.service

# Verify service name matches
cat /usr/share/dbus-1/services/org.*.service

# Should contain:
# [D-BUS Service]
# Name=org.your.service
# Exec=/usr/lib64/libexec/your-service
```

### Polkit Keeps Asking for Password

**Cause:** Policy defaults too restrictive or persistence not set

**Solution:** In .policy file:
```xml
<defaults>
  <allow_active>yes</allow_active>  <!-- No password if user is active -->
</defaults>
```

In .actions file:
```ini
Persistence=session  # Remember for session
```

---

## Required Packages

### openSUSE Tumbleweed (Complete List)

```bash
sudo zypper install \
    cmake \
    ninja \
    gcc-c++ \
    git \
    extra-cmake-modules \
    kf6-kcoreaddons-devel \
    kf6-ki18n-devel \
    kf6-kauth-devel \
    kf6-kpackage-devel \
    libQt6Core-devel \
    libQt6DBus-devel \
    libQt6Widgets-devel \
    libQt6Qml-devel \
    plasma6-framework-devel \
    plasma6-workspace-devel \
    polkit-devel \
    systemd-devel \
    systemd-network
```

### Fedora Equivalent

```bash
sudo dnf install \
    cmake \
    ninja-build \
    gcc-c++ \
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

### Arch Linux Equivalent

```bash
sudo pacman -S \
    cmake \
    ninja \
    gcc \
    extra-cmake-modules \
    kcoreaddons \
    ki18n \
    kauth \
    qt6-base \
    qt6-declarative \
    plasma-workspace \
    polkit \
    systemd
```

---

## Summary: Key Takeaways

1. **Always follow the DBus → Service → KAuth → Helper pattern**
2. **Add version numbers to ALL QML imports**
3. **Use KF6::AuthCore not KF6::Auth in CMake**
4. **Return JSON strings from DBus methods for easy QML parsing**
5. **Register custom DBus types with proper marshalling operators**
6. **Test with dummy interfaces to avoid breaking your network**
7. **Use RPM packaging for distribution, not direct `make install`**
8. **Read systemd-networkd docs for DBus interface details**
9. **Add comprehensive logging during development**
10. **Follow KDE's existing widgets as reference implementations**

This pattern works for ANY privileged operation in Plasma widgets:
- Network management
- Power control
- Disk operations
- Service management
- System configuration
- Hardware control

**The key:** Never try to shortcut the architecture. Do it the KDE way.
