// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2025 Plasma NetworkCtl Widget

#include "networkctlhelper.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>

NetworkCtlHelper::NetworkCtlHelper()
{
}

ActionReply NetworkCtlHelper::setup(const QVariantMap &args)
{
    QString interface = args.value(QStringLiteral("interface")).toString();
    QString operation = args.value(QStringLiteral("operation")).toString();
    
    if (interface.isEmpty()) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(QStringLiteral("Interface name is required"));
        return reply;
    }
    
    if (operation != QStringLiteral("up") && operation != QStringLiteral("down")) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(QStringLiteral("Operation must be 'up' or 'down'"));
        return reply;
    }
    
    // Connect to systemd-networkd DBus (as root)
    QDBusInterface manager(QStringLiteral("org.freedesktop.network1"),
                          QStringLiteral("/org/freedesktop/network1"),
                          QStringLiteral("org.freedesktop.network1.Manager"),
                          QDBusConnection::systemBus());
    
    if (!manager.isValid()) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(QStringLiteral("Failed to connect to systemd-networkd: ") + 
                                 manager.lastError().message());
        return reply;
    }
    
    // Get the interface index by name
    QDBusReply<int> ifIndexReply = manager.call(QStringLiteral("GetLinkByName"), interface);
    
    if (!ifIndexReply.isValid()) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(QStringLiteral("Failed to get interface: ") + 
                                 ifIndexReply.error().message());
        return reply;
    }
    
    int ifIndex = ifIndexReply.value();
    QString linkPath = QStringLiteral("/org/freedesktop/network1/link/_") + QString::number(ifIndex);
    
    QDBusInterface link(QStringLiteral("org.freedesktop.network1"),
                       linkPath,
                       QStringLiteral("org.freedesktop.network1.Link"),
                       QDBusConnection::systemBus());
    
    if (!link.isValid()) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(QStringLiteral("Failed to access interface: ") + 
                                 link.lastError().message());
        return reply;
    }
    
    // Call SetUp or SetDown method
    QDBusReply<void> operationReply;
    if (operation == QStringLiteral("up")) {
        operationReply = link.call(QStringLiteral("SetUp"));
    } else {
        operationReply = link.call(QStringLiteral("SetDown"));
    }
    
    if (!operationReply.isValid()) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(QStringLiteral("Failed to set interface ") + operation + 
                                 QStringLiteral(": ") + operationReply.error().message());
        return reply;
    }
    
    ActionReply reply = ActionReply::SuccessReply();
    reply.addData(QStringLiteral("interface"), interface);
    reply.addData(QStringLiteral("operation"), operation);
    return reply;
}

KAUTH_HELPER_MAIN("org.kde.plasma.networkctl", NetworkCtlHelper)
