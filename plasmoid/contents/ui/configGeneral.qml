// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2025 Plasma NetworkCtl Widget

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_demoMode: demoModeCheckbox.checked

    QQC2.CheckBox {
        id: demoModeCheckbox
        Kirigami.FormData.label: "Demo Mode:"
        text: "Use demo data instead of real network interfaces"
    }

    Item {
        Kirigami.FormData.isSection: true
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Enable demo mode to test the widget with sample data when the NetworkCtl service is not available or you want to preview the interface without affecting real network settings."
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
    }
}
