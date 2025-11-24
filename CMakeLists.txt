cmake_minimum_required(VERSION 3.16)

project(plasma-networkctl VERSION 1.0.0)

set(QT_MIN_VERSION "6.6.0")
set(KF_MIN_VERSION "6.0.0")

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Core
    DBus
)

find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS
    Auth
    CoreAddons
    I18n
)

find_package(Plasma REQUIRED)

# Subdirectories
add_subdirectory(service)
add_subdirectory(helper)
add_subdirectory(plasmoid)

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)

# CPack configuration for RPM generation
set(CPACK_GENERATOR "RPM")
set(CPACK_PACKAGE_NAME "plasma6-applet-networkctl")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_RELEASE "1")
set(CPACK_PACKAGE_CONTACT "your@email.com")
set(CPACK_PACKAGE_VENDOR "KDE Community")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Plasma 6 widget to control systemd-networkd interfaces")
set(CPACK_PACKAGE_DESCRIPTION "KDE Plasma 6 widget for controlling systemd-networkd network interfaces with proper privilege separation using KAuth and Polkit.")

# RPM-specific settings
set(CPACK_RPM_PACKAGE_NAME "${CPACK_PACKAGE_NAME}")
set(CPACK_RPM_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION}")
set(CPACK_RPM_PACKAGE_RELEASE "${CPACK_PACKAGE_RELEASE}")
set(CPACK_RPM_PACKAGE_GROUP "System/GUI/KDE")
set(CPACK_RPM_PACKAGE_LICENSE "GPL-2.0-or-later")
set(CPACK_RPM_PACKAGE_URL "https://github.com/yourusername/plasma-networkctl")
set(CPACK_RPM_PACKAGE_REQUIRES "systemd-network, plasma6-workspace")
set(CPACK_RPM_FILE_NAME "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${CPACK_PACKAGE_RELEASE}.x86_64.rpm")
set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION
    "/usr/share/dbus-1"
    "/usr/share/dbus-1/services"
    "/usr/share/plasma"
    "/usr/share/plasma/plasmoids"
    "/usr/share/polkit-1"
    "/usr/share/polkit-1/actions"
    "/usr/share/kauth"
)

# Include CPack
include(CPack)
