// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2025 Plasma NetworkCtl Widget

#include "networkctlservice.h"
#include "networkctladaptor.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMetaType>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>
#include <KAuth/Action>
#include <KAuth/ExecuteJob>

// Struct to represent network link from systemd-networkd
struct NetworkLink {
    int index;
    QString name;
    QDBusObjectPath path;
};
Q_DECLARE_METATYPE(NetworkLink)

// DBus marshalling operators
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

NetworkCtlService::NetworkCtlService(QObject *parent)
    : QObject(parent)
{
    // Register the custom type for DBus
    qDBusRegisterMetaType<NetworkLink>();
    qDBusRegisterMetaType<QList<NetworkLink>>();
    
    new NetworkctlAdaptor(this);
    QDBusConnection::sessionBus().registerObject(QStringLiteral("/NetworkCtl"), this);
    QDBusConnection::sessionBus().registerService(QStringLiteral("org.kde.plasma.networkctl"));
}

NetworkCtlService::~NetworkCtlService() = default;

QVariantList NetworkCtlService::ListInterfaces()
{
    QVariantList result;
    
    // Connect to systemd-networkd DBus interface
    QDBusInterface manager(QStringLiteral("org.freedesktop.network1"),
                          QStringLiteral("/org/freedesktop/network1"),
                          QStringLiteral("org.freedesktop.network1.Manager"),
                          QDBusConnection::systemBus());
    
    if (!manager.isValid()) {
        qWarning() << "Failed to connect to systemd-networkd:" << manager.lastError().message();
        return result;
    }
    
    // Call ListLinks to get all network interfaces
    // ListLinks returns a(iso): array of (index, name, path)
    QDBusReply<QList<NetworkLink>> reply = manager.call(QStringLiteral("ListLinks"));
    
    if (!reply.isValid()) {
        qWarning() << "Failed to list links:" << reply.error().message();
        return result;
    }
    
    // Iterate through the links
    for (const NetworkLink &link : reply.value()) {
        // For each interface, get its properties
        QDBusInterface linkInterface(QStringLiteral("org.freedesktop.network1"),
                           link.path.path(),
                           QStringLiteral("org.freedesktop.network1.Link"),
                           QDBusConnection::systemBus());
        
        if (!linkInterface.isValid()) {
            continue;
        }
        
        QVariantMap interfaceData;
        
        // Get interface index
        QVariant indexProp = linkInterface.property("IfIndex");
        if (indexProp.isValid()) {
            interfaceData[QStringLiteral("index")] = indexProp;
        }
        
        // Get interface name
        QVariant nameProp = linkInterface.property("Name");
        if (nameProp.isValid()) {
            interfaceData[QStringLiteral("name")] = nameProp;
        }
        
        // Get operational state (up, down, dormant, etc.)
        QVariant operStateProp = linkInterface.property("OperationalState");
        if (operStateProp.isValid()) {
            interfaceData[QStringLiteral("operationalState")] = operStateProp;
        }
        
        // Get administrative state
        QVariant adminStateProp = linkInterface.property("AdministrativeState");
        if (adminStateProp.isValid()) {
            interfaceData[QStringLiteral("administrativeState")] = adminStateProp;
        }
        
        // Get interface type
        QVariant typeProp = linkInterface.property("Type");
        if (typeProp.isValid()) {
            QString type = typeProp.toString();
            interfaceData[QStringLiteral("type")] = determineInterfaceType(type, nameProp.toString());
        }
        
        // Get setup state
        QVariant setupStateProp = linkInterface.property("SetupState");
        if (setupStateProp.isValid()) {
            interfaceData[QStringLiteral("setupState")] = setupStateProp;
        }
        
        result.append(interfaceData);
    }
    
    return result;
}

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

QString NetworkCtlService::determineInterfaceType(const QString &type, const QString &name)
{
    // Determine interface type based on name and type
    if (name.startsWith(QStringLiteral("wl")) || name.startsWith(QStringLiteral("wlan"))) {
        return QStringLiteral("wireless");
    } else if (name.startsWith(QStringLiteral("tun")) || name.startsWith(QStringLiteral("tap")) ||
               name.startsWith(QStringLiteral("vpn")) || name.startsWith(QStringLiteral("wg"))) {
        return QStringLiteral("vpn");
    } else if (name.startsWith(QStringLiteral("en")) || name.startsWith(QStringLiteral("eth")) ||
               type == QStringLiteral("ether")) {
        return QStringLiteral("ethernet");
    } else if (name == QStringLiteral("lo")) {
        return QStringLiteral("loopback");
    }
    
    return QStringLiteral("other");
}

QVariantMap NetworkCtlService::GetStatus(const QString &interface)
{
    QVariantMap result;
    
    if (interface.isEmpty()) {
        result[QStringLiteral("error")] = QStringLiteral("Interface name cannot be empty");
        return result;
    }
    
    // Connect to systemd-networkd DBus interface
    QDBusInterface manager(QStringLiteral("org.freedesktop.network1"),
                          QStringLiteral("/org/freedesktop/network1"),
                          QStringLiteral("org.freedesktop.network1.Manager"),
                          QDBusConnection::systemBus());
    
    if (!manager.isValid()) {
        result[QStringLiteral("error")] = manager.lastError().message();
        return result;
    }
    
    // Get the link by name
    QDBusReply<int> ifIndexReply = manager.call(QStringLiteral("GetLinkByName"), interface);
    
    if (!ifIndexReply.isValid()) {
        result[QStringLiteral("error")] = ifIndexReply.error().message();
        return result;
    }
    
    // Construct the object path for this interface
    QString linkPath = QStringLiteral("/org/freedesktop/network1/link/_") + QString::number(ifIndexReply.value());
    
    QDBusInterface link(QStringLiteral("org.freedesktop.network1"),
                       linkPath,
                       QStringLiteral("org.freedesktop.network1.Link"),
                       QDBusConnection::systemBus());
    
    if (!link.isValid()) {
        result[QStringLiteral("error")] = link.lastError().message();
        return result;
    }
    
    // Gather all relevant properties
    result[QStringLiteral("name")] = interface;
    result[QStringLiteral("operationalState")] = link.property("OperationalState");
    result[QStringLiteral("administrativeState")] = link.property("AdministrativeState");
    result[QStringLiteral("setupState")] = link.property("SetupState");
    result[QStringLiteral("type")] = link.property("Type");
    
    return result;
}

bool NetworkCtlService::SetUp(const QString &interface)
{
    if (interface.isEmpty()) {
        qWarning() << "Interface name cannot be empty";
        return false;
    }
    
    // Create KAuth action
    KAuth::Action action(QStringLiteral("org.kde.plasma.networkctl.setup"));
    action.setHelperId(QStringLiteral("org.kde.plasma.networkctl"));
    
    QVariantMap args;
    args[QStringLiteral("interface")] = interface;
    args[QStringLiteral("operation")] = QStringLiteral("up");
    action.setArguments(args);
    
    // Execute the action
    KAuth::ExecuteJob *job = action.execute();
    bool success = job->exec();
    
    if (!success) {
        qWarning() << "Failed to bring interface up:" << job->errorString();
        return false;
    }
    
    // Emit signal for interface state change
    Q_EMIT InterfaceChanged(interface, QStringLiteral("up"));
    
    return true;
}

bool NetworkCtlService::SetDown(const QString &interface)
{
    if (interface.isEmpty()) {
        qWarning() << "Interface name cannot be empty";
        return false;
    }
    
    // Create KAuth action
    KAuth::Action action(QStringLiteral("org.kde.plasma.networkctl.setup"));
    action.setHelperId(QStringLiteral("org.kde.plasma.networkctl"));
    
    QVariantMap args;
    args[QStringLiteral("interface")] = interface;
    args[QStringLiteral("operation")] = QStringLiteral("down");
    action.setArguments(args);
    
    // Execute the action
    KAuth::ExecuteJob *job = action.execute();
    bool success = job->exec();
    
    if (!success) {
        qWarning() << "Failed to bring interface down:" << job->errorString();
        return false;
    }
    
    // Emit signal for interface state change
    Q_EMIT InterfaceChanged(interface, QStringLiteral("down"));
    
    return true;
}
