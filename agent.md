Plasma 6 Plasmoid + Privileged Backend: The Right Way

tl;dr:
A Plasma widget (QML/JS) cannot directly run privileged commands.
The correct and supported Plasma 6 pattern is:

1. Plasmoid (QML/JS) →
2. DBus interface to a custom system service (your app) →
3. Polkit-controlled helper binary (root)

This is identical to how KDE's own network, power, and device applets work.

**CRITICAL**: This document has been updated with Plasma 6-specific requirements and real-world gotchas encountered during implementation.

# Why the Widget Cannot Call networkctl Directly

Plasma 6’s QML/JS runtime is sandboxed and prohibited from spawning external commands or accessing system files. Only DBus is allowed.
This is intentional.

So your plasmoid must rely on a trusted backend service, which does the privileged work via Polkit.

# The Architecture You Must Implement
```
[Your Plasmoid]  <--(DBus)-->  [Your DBus Service]  <--(Polkit auth)-->  [Helper running as root]
```

This is exactly the same architecture used by:

* KDE Wallet
* KDE Connect
* Plasma Network Management Applet (plasma-nm)
* PowerDevil power management

# The Minimal Components You Need
## DBus Service (non-root, runs as user)

A small C++/Qt executable installed into /usr/libexec that:

* Exposes a DBus interface (e.g. org.example.NetworkdControl)
* Has methods like:
  * `ListInterfaces() → array`
  * `GetStatus(ifname) → string`
  * SetUp(ifname)
  * SetDown(ifname)
* Uses KAuth to request privileged actions.

This process is started automatically by DBus activation when your plasmoid first calls it.

Why needed?
The DBus service is the stable entry point for your plasmoid. It has permissions, lifetime, and Polkit integration Plasma trusts.

## Polkit-Authenticated Helper (privileged)

This is a tiny binary that actually runs:

* networkctl list
* networkctl status <iface>
* networkctl up <iface>
* networkctl down <iface>

It runs as root—but only when Polkit authorizes it.

You implement this using KDE’s built-in KAuth framework:

### KAuth overview:

* Your DBus-facing code calls a KAuth action.
* KAuth asks Polkit whether the caller may perform it.
* If allowed, KAuth executes your root-privileged helper with a controlled environment.

Why needed?
This is how you avoid shipping SUID binaries, sudo hacks, or breaking Plasma’s security model.

# How These Components Interact
Example: User clicks “Enable interface eth0”

1. Plasmoid calls DBus:

```
org.example.NetworkdControl.SetUp("eth0")
```

2. User session DBus service receives it and triggers a KAuth action:
```
Action("org.example.networkd.setup").execute({"iface": "eth0"})
```

3. Polkit checks rules:
 * If user is allowed → run helper silently
 * If user not allowed → Polkit prompts for password

4. Helper runs as root:
```
networkctl up eth0
```

5. DBus service returns the result to the QML plasmoid.

# Files You Need (minimal skeleton)
File	Purpose
org.example.NetworkdControl.xml	DBus interface definition
networkd-control-service.cpp	Implements DBus service using Qt DBus
/usr/share/dbus-1/services/org.example.NetworkdControl.service	DBus activation
org.example.networkd.actions	KAuth action definitions
networkdhelper.cpp	KAuth helper (runs as root)
org.example.networkd.policy	Polkit policy letting users run actions
metadata.json	Plasmoid metadata
main.qml	UI, calls DBus


# KAuth Example (very minimal)

`org.example.networkd.actions`
```
[org.example.networkd.setup]
Description=Bring interface up
Policy=auth_admin
```

`org.example.networkd.policy`
```
<policyconfig>
  <action id="org.example.networkd.setup">
    <description>Bring a network interface up</description>
    <message>Authentication required to bring interface up</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>no</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
  </action>
</policyconfig>
```

# DBus–QML Interaction (plasmoid side)

**IMPORTANT**: QtDBus is NOT available as a QML module in Plasma 6!

Instead, use Plasma5Support.DataSource with the "executable" engine:

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
        var argsStr = args ? " " + args.join(" ") : ""
        var cmd = "qdbus6 org.your.service /Path org.your.service." + method + argsStr
        connectSource(cmd)
    }
}
```

This is the working approach for Plasma 6 widgets.

# Reading systemd-networkd state (preferred method)

Instead of parsing command output, use DBus:
* systemd-networkd exposes DBus at: `org.freedesktop.network1`

Interfaces:
* `org.freedesktop.network1.Manager`
* `org.freedesktop.network1.Link`

Example:
`org.freedesktop.network1.Manager.ListLinks()` → array of object paths
Each path exposes status properties (OperationalState, AdminState, etc.)

This avoids shelling out to networkctl. The helper can call DBus with elevated privileges using sd-bus or QDBus.

# What KDE Itself Does (real-world analogues)

You are essentially replicating:

* plasma-nm (plasmoid)
   → talks to
  networkmanagement DBus service (C++/Qt)
   → which calls
  ModemManager/NetworkManager DBus
   → and uses Polkit for privileged actions

This is the approved design.

# Minimal Development Steps Summary

1. Write a DBus XML interface for your service.
2. Generate Qt DBus adaptor code using qdbusxml2cpp.
3. Implement the DBus service (Qt C++).
4. Define KAuth actions for privileged operations.
5. Implement a KAuth helper that calls systemd-networkd (via DBus or networkctl).
6. Create Polkit policy file to control access.
7. Install DBus service file for activation.
8. Create your plasmoid QML and call the DBus service.

That's the Plasma-approved, future-proof method.

---

# Plasma 6 Specific Requirements & Gotchas

## QML Imports MUST Have Version Numbers
All QML imports require explicit version numbers in Plasma 6:

```qml
import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as Plasma5Support
```

Without version numbers, the widget will fail with "widget was written for unknown older version".

## Plasmoid Metadata Must Declare API Version
In `metadata.json`, you MUST include:

```json
{
  "KPlugin": {
    "Id": "your.widget.id",
    "Name": "Your Widget Name"
  },
  "KPackageStructure": "Plasma/Applet",
  "X-Plasma-API-Minimum-Version": "6.0"
}
```

The `X-Plasma-API-Minimum-Version` field is critical for Plasma 6 compatibility.

## CMake Package Names for Plasma 6
Use Qt6 and KF6 package names:

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core DBus Widgets)
find_package(KF6 REQUIRED COMPONENTS Auth CoreAddons I18n Plasma)
```

**CRITICAL**: Link against `KF6::AuthCore`, NOT `KF6::Auth`! The `KF6::Auth` target doesn't exist.

Example in helper/CMakeLists.txt:
```cmake
target_link_libraries(plasma_networkctl_helper KF6::AuthCore)
```

## Polkit Policy Installation Path
Use KDE install variables, NOT the undefined POLKITQT-1 variables:

```cmake
install(FILES org.kde.plasma.networkctl.policy
        DESTINATION ${KDE_INSTALL_DATADIR}/polkit-1/actions)
```

The old `${POLKITQT-1_POLICY_FILES_INSTALL_DIR}` variable doesn't exist in KF6.

## QtDBus Not Available in QML
You cannot use `import QtDBus` in Plasma 6 QML. Instead:

1. Use `Plasma5Support.DataSource` with executable engine (call qdbus6 commands)
2. Or implement proper DBus proxies in C++ and expose to QML via context properties

The DataSource approach works but is less efficient. For production widgets, prefer C++ DBus proxies.

## systemd-networkd DBus Type Signatures
When calling `org.freedesktop.network1.Manager.ListLinks()`:
- It returns `a(iso)` - array of structs containing (int32, string, objectpath)
- NOT `ao` (array of object paths)

You must define a proper Qt struct:

```cpp
struct NetworkLink {
    int index;
    QString name;
    QDBusObjectPath path;
};
Q_DECLARE_METATYPE(NetworkLink)

// DBus marshalling operators
QDBusArgument &operator<<(QDBusArgument &argument, const NetworkLink &link);
const QDBusArgument &operator>>(const QDBusArgument &argument, NetworkLink &link);
```

Register the type in your service constructor:
```cpp
qDBusRegisterMetaType<NetworkLink>();
```

Then parse the reply:
```cpp
QDBusReply<QList<NetworkLink>> reply = manager.call("ListLinks");
if (reply.isValid()) {
    for (const NetworkLink &link : reply.value()) {
        // Use link.index, link.name, link.path
    }
}
```

## Common Build Errors

### "QDBusArgument: write from a read-only object"
This means you're trying to iterate a QDBusArgument without proper extraction operators. Implement `operator<<` and `operator>>` for your custom struct.

### "Unknown older version" in plasmashell
Add version numbers to ALL QML imports and set `X-Plasma-API-Minimum-Version` in metadata.json.

### "KF6::Auth target not found"
Use `KF6::AuthCore` instead. The Auth target doesn't exist.

### Helper fails to load
Check that the helper is installed to `${KDE_INSTALL_LIBEXECDIR}` (usually `/usr/lib64/libexec/` on openSUSE). Verify the path in your .actions file matches the actual installation location.

## Testing Strategy
When testing on a system where you can't risk losing network connectivity:

1. Create dummy interfaces:
```bash
sudo ip link add dummy0 type dummy
sudo ip link add dummy1 type dummy
```

2. Configure systemd-networkd to ignore your real interfaces by NOT creating .network files for them

3. Test your widget with the dummy interfaces

4. The widget will see all interfaces but only manage those with systemd-networkd .network files

This allows safe testing without risk of breaking your working network connection.

## Required Packages (openSUSE Tumbleweed)
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
    polkit-devel
```
