// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2025 Plasma NetworkCtl Widget

#ifndef NETWORKCTLHELPER_H
#define NETWORKCTLHELPER_H

#include <KAuth/ActionReply>
#include <KAuth/HelperSupport>

using namespace KAuth;

class NetworkCtlHelper : public QObject
{
    Q_OBJECT

public:
    NetworkCtlHelper();

public Q_SLOTS:
    ActionReply setup(const QVariantMap &args);
};

#endif // NETWORKCTLHELPER_H
