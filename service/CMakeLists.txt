set(networkctl_service_SRCS
    main.cpp
    networkctlservice.cpp
)

qt_add_dbus_adaptor(networkctl_service_SRCS
    org.kde.plasma.networkctl.xml
    networkctlservice.h
    NetworkCtlService
    networkctladaptor
    NetworkctlAdaptor
)

add_executable(plasma-networkctl-service ${networkctl_service_SRCS})

target_link_libraries(plasma-networkctl-service
    Qt6::Core
    Qt6::DBus
    KF6::AuthCore
    KF6::CoreAddons
)

install(TARGETS plasma-networkctl-service DESTINATION ${KDE_INSTALL_LIBEXECDIR})

# Install DBus service file for activation
configure_file(org.kde.plasma.networkctl.service.in
    ${CMAKE_CURRENT_BINARY_DIR}/org.kde.plasma.networkctl.service
    @ONLY
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/org.kde.plasma.networkctl.service
    DESTINATION ${KDE_INSTALL_DBUSSERVICEDIR}
)
