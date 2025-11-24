// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2025 Plasma NetworkCtl Widget

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as Plasma5Support

PlasmoidItem {
    id: root

    width: Kirigami.Units.gridUnit * 20
    height: Kirigami.Units.gridUnit * 30

    property var interfaces: []
    property var ethernetInterfaces: []
    property var wirelessInterfaces: []
    property var vpnInterfaces: []
    property bool serviceAvailable: false
    
    // Use the config value directly instead of copying it
    readonly property bool mockMode: plasmoid.configuration.demoMode

    // DBus interface to our service using DataSource
    Plasma5Support.DataSource {
        id: dbusService
        engine: "executable"
        connectedSources: []
        
        onNewData: function(sourceName, data) {
            var stdout = data["stdout"]
            var stderr = data["stderr"]
            var exitCode = data["exit code"]
            
            console.log("DBus command:", sourceName)
            console.log("Exit code:", exitCode)
            console.log("stdout length:", stdout ? stdout.length : 0)
            console.log("stderr length:", stderr ? stderr.length : 0)
            console.log("Full data keys:", Object.keys(data))
            if (stdout) {
                console.log("stdout content:", stdout.substring(0, 200))
            }
            if (stderr) {
                console.log("stderr content:", stderr.substring(0, 200))
            }
            
            if (stdout) {
                try {
                    // qdbus6 returns JSON from ListInterfacesJSON
                    var result = JSON.parse(stdout)
                    if (sourceName.indexOf("ListInterfacesJSON") >= 0) {
                        interfaces = result
                        categorizeInterfaces()
                        serviceAvailable = true
                    }
                } catch(e) {
                    console.error("Failed to parse DBus response:", e, "Output was:", stdout)
                    // Service might be available but output format is wrong
                    if (!stderr || stderr.indexOf("Service") < 0) {
                        serviceAvailable = true
                    }
                }
            } else if (stderr && stderr.indexOf("not provide") >= 0) {
                console.error("Service not available:", stderr)
                serviceAvailable = false
            }
            disconnectSource(sourceName)
        }
        
        onSourceAdded: function(source) {
            connectSource(source)
        }
        
        function callMethod(method, args) {
            var argsStr = args ? " " + args.join(" ") : ""
            var cmd = "qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl." + method + argsStr
            connectSource(cmd)
        }
    }

    Timer {
        id: refreshTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: refreshInterfaces()
    }

    Timer {
        id: serviceCheckTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: checkService()
    }

    Component.onCompleted: {
        console.log("NetworkCtl Widget loaded")
        console.log("Demo mode:", plasmoid.configuration.demoMode)
        if (plasmoid.configuration.demoMode) {
            loadMockData()
        } else {
            checkService()
            refreshInterfaces()
        }
    }

    // Watch for config changes
    onMockModeChanged: {
        console.log("Mock mode changed to:", mockMode)
        if (mockMode) {
            loadMockData()
        } else {
            refreshInterfaces()
        }
    }

    function checkService() {
        // Try to call the service to see if it's available
        var cmd = "qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.ListInterfacesJSON 2>&1"
        dbusService.connectSource(cmd)
    }

    function loadMockData() {
        console.log("Loading mock data...")
        interfaces = [
            {
                name: "eth0",
                type: "ethernet",
                operationalState: "routable",
                administrativeState: "configured",
                setupState: "configured"
            },
            {
                name: "wlan0",
                type: "wireless", 
                operationalState: "dormant",
                administrativeState: "unmanaged",
                setupState: "unmanaged"
            },
            {
                name: "wg0",
                type: "vpn",
                operationalState: "carrier",
                administrativeState: "configured",
                setupState: "configured"
            }
        ]
        console.log("Mock data loaded, interfaces:", interfaces.length)
        categorizeInterfaces()
    }

    function refreshInterfaces() {
        if (!mockMode) {
            var cmd = "qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.ListInterfacesJSON 2>&1"
            dbusService.connectSource(cmd)
        }
        // If in mock mode, data is already loaded
    }

    function categorizeInterfaces() {
        var ethernet = []
        var wireless = []
        var vpn = []

        console.log("Categorizing", interfaces.length, "interfaces")

        for (var i = 0; i < interfaces.length; i++) {
            var iface = interfaces[i]
            
            console.log("Interface:", iface.name, "Type:", iface.type)
            
            // Skip loopback
            if (iface.type === "loopback") {
                continue
            }
            
            if (iface.type === "ethernet") {
                ethernet.push(iface)
            } else if (iface.type === "wireless") {
                wireless.push(iface)
            } else if (iface.type === "vpn") {
                vpn.push(iface)
            }
        }
        
        // Assign to trigger property updates
        ethernetInterfaces = ethernet
        wirelessInterfaces = wireless
        vpnInterfaces = vpn
        
        console.log("Categorized - Ethernet:", ethernetInterfaces.length, "Wireless:", wirelessInterfaces.length, "VPN:", vpnInterfaces.length)
    }

    function setInterfaceUp(ifaceName) {
        if (mockMode) {
            console.log("Mock mode: Would bring up", ifaceName)
            // In mock mode, just toggle the state locally
            for (var i = 0; i < interfaces.length; i++) {
                if (interfaces[i].name === ifaceName) {
                    interfaces[i].operationalState = "routable"
                    interfaces[i].administrativeState = "configured"
                    break
                }
            }
            categorizeInterfaces()
            return
        }

        var cmd = "qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.SetUp " + ifaceName
        dbusService.connectSource(cmd)
        // Refresh after a short delay
        Qt.callLater(refreshInterfaces)
    }

    function setInterfaceDown(ifaceName) {
        if (mockMode) {
            console.log("Mock mode: Would bring down", ifaceName)
            // In mock mode, just toggle the state locally
            for (var i = 0; i < interfaces.length; i++) {
                if (interfaces[i].name === ifaceName) {
                    interfaces[i].operationalState = "off"
                    interfaces[i].administrativeState = "unmanaged"
                    break
                }
            }
            categorizeInterfaces()
            return
        }

        var cmd = "qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.SetDown " + ifaceName
        dbusService.connectSource(cmd)
        // Refresh after a short delay
        Qt.callLater(refreshInterfaces)
    }

    function toggleInterface(iface) {
        var isUp = iface.administrativeState === "configured" || 
                   iface.operationalState === "routable" ||
                   iface.operationalState === "carrier"
        
        if (isUp) {
            setInterfaceDown(iface.name)
        } else {
            setInterfaceUp(iface.name)
        }
    }

    function openNetworkConfig() {
        Qt.openUrlExternally("file:///etc/systemd/network")
    }

    fullRepresentation: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: "Network Interfaces"
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            }

            PlasmaComponents.Label {
                text: mockMode ? "DEMO" : ""
                color: Kirigami.Theme.neutralTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                visible: mockMode
            }
        }

        // Status bar
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: {
                if (mockMode) {
                    return "Demo mode - install and configure the backend service for full functionality"
                } else if (serviceAvailable) {
                    return "Connected to networkctl service"
                } else {
                    return "Connecting to service..."
                }
            }
            color: mockMode ? Kirigami.Theme.neutralTextColor : 
                   serviceAvailable ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            wrapMode: Text.WordWrap
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.largeSpacing

                // Ethernet Interfaces
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: ethernetInterfaces.length > 0
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: "Ethernet"
                        font.bold: true
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: ethernetInterfaces
                        delegate: InterfaceItem {
                            Layout.fillWidth: true
                            interfaceData: modelData
                            isDemo: root.mockMode
                        }
                    }
                }

                // Wireless Interfaces
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: wirelessInterfaces.length > 0
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: "Wireless"
                        font.bold: true
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: wirelessInterfaces
                        delegate: InterfaceItem {
                            Layout.fillWidth: true
                            interfaceData: modelData
                            isDemo: root.mockMode
                        }
                    }
                }

                // VPN Interfaces
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: vpnInterfaces.length > 0
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: "VPN"
                        font.bold: true
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: vpnInterfaces
                        delegate: InterfaceItem {
                            Layout.fillWidth: true
                            interfaceData: modelData
                            isDemo: root.mockMode
                        }
                    }
                }

                // Empty state
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignCenter
                    text: mockMode ? "No demo interfaces configured" : "No network interfaces found"
                    visible: ethernetInterfaces.length === 0 && 
                            wirelessInterfaces.length === 0 && 
                            vpnInterfaces.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.6
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    compactRepresentation: Kirigami.Icon {
        source: mockMode ? "network-disconnect" : "network-wired"
        active: compactMouse.containsMouse

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }
}
