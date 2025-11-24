// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2025 Plasma NetworkCtl Widget

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

RowLayout {
    id: interfaceItem
    
    property var interfaceData
    property bool isDemo: false
    
    spacing: Kirigami.Units.smallSpacing
    
    readonly property bool isUp: interfaceData.administrativeState === "configured" || 
                                  interfaceData.operationalState === "routable" ||
                                  interfaceData.operationalState === "carrier"
    
    // Interface icon
    Kirigami.Icon {
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        source: {
            if (interfaceData.type === "ethernet") {
                return "network-wired"
            } else if (interfaceData.type === "wireless") {
                return "network-wireless"
            } else if (interfaceData.type === "vpn") {
                return "network-vpn"
            }
            return "network-wired"
        }
    }
    
    // Interface name and status
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: interfaceData.name
            font.bold: true
        }
        
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: interfaceData.operationalState || "unknown"
            opacity: 0.7
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
    
    // Status indicator
    Rectangle {
        Layout.preferredWidth: Kirigami.Units.gridUnit
        Layout.preferredHeight: Kirigami.Units.gridUnit
        radius: width / 2
        color: {
            if (interfaceData.operationalState === "routable" || 
                interfaceData.operationalState === "carrier") {
                return Kirigami.Theme.positiveTextColor
            } else if (interfaceData.operationalState === "degraded") {
                return Kirigami.Theme.neutralTextColor
            } else {
                return Kirigami.Theme.disabledTextColor
            }
        }
        
        QQC2.ToolTip {
            text: isDemo ? "Demo mode - " + (interfaceData.operationalState || "unknown") : 
                          "Operational State: " + (interfaceData.operationalState || "unknown")
        }
    }
    
    // Toggle button
    QQC2.ToolButton {
        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        
        icon.name: isUp ? "media-playback-stop" : "media-playback-start"
        
        QQC2.ToolTip {
            text: isDemo ? "Demo mode - click to simulate toggle" : 
                  (isUp ? "Bring interface down" : "Bring interface up")
        }
        
        onClicked: {
            root.toggleInterface(interfaceData)
        }
    }
    
    // Config button
    QQC2.ToolButton {
        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        
        icon.name: "configure"
        
        QQC2.ToolTip {
            text: isDemo ? "Demo mode - configuration not available" : "Configure interface"
        }
        
        onClicked: {
            configDialog.open()
        }
    }
    
    // Configuration dialog (placeholder)
    QQC2.Dialog {
        id: configDialog
        
        title: "Configure " + interfaceData.name
        modal: true
        
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: "Configuration interface for " + interfaceData.name + " is not yet implemented."
                wrapMode: Text.WordWrap
            }
            
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: "You can manually edit configuration files in /etc/systemd/network/"
                wrapMode: Text.WordWrap
                opacity: 0.7
            }
            
            QQC2.Button {
                Layout.alignment: Qt.AlignHCenter
                text: "Open Network Configuration Directory"
                icon.name: "folder-open"
                onClicked: {
                    root.openNetworkConfig()
                    configDialog.close()
                }
            }
        }
        
        footer: QQC2.DialogButtonBox {
            QQC2.Button {
                text: "Close"
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole
            }
            
            onRejected: configDialog.close()
        }
    }
}
