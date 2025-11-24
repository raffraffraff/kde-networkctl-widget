// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2025 Plasma NetworkCtl Widget

#include "networkctlservice.h"

#include <QCoreApplication>
#include <QDebug>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("plasma-networkctl-service"));
    app.setApplicationVersion(QStringLiteral("1.0"));
    app.setOrganizationDomain(QStringLiteral("kde.org"));

    NetworkCtlService service;
    qDebug() << "Plasma NetworkCtl Service started";

    return app.exec();
}
