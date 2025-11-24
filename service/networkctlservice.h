// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2025 Plasma NetworkCtl Widget

#ifndef NETWORKCTLSERVICE_H
#define NETWORKCTLSERVICE_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class NetworkCtlService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.plasma.networkctl")

public:
    explicit NetworkCtlService(QObject *parent = nullptr);
    ~NetworkCtlService() override;

public Q_SLOTS:
    QVariantList ListInterfaces();
    QString ListInterfacesJSON();  // JSON string version for QML
    QVariantMap GetStatus(const QString &interface);
    bool SetUp(const QString &interface);
    bool SetDown(const QString &interface);

Q_SIGNALS:
    void InterfaceChanged(const QString &interface, const QString &state);

private:
    QString determineInterfaceType(const QString &type, const QString &name);
};

#endif // NETWORKCTLSERVICE_H
