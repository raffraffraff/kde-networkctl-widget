add_executable(plasma-networkctl-helper
    networkctlhelper.cpp
)

target_link_libraries(plasma-networkctl-helper
    Qt6::Core
    Qt6::DBus
    KF6::AuthCore
)

install(TARGETS plasma-networkctl-helper DESTINATION ${KAUTH_HELPER_INSTALL_DIR})

kauth_install_helper_files(plasma-networkctl-helper org.kde.plasma.networkctl root)
kauth_install_actions(org.kde.plasma.networkctl org.kde.plasma.networkctl.actions)

# Configure and install Polkit policy
configure_file(org.kde.plasma.networkctl.policy.in
    ${CMAKE_CURRENT_BINARY_DIR}/org.kde.plasma.networkctl.policy
    @ONLY
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/org.kde.plasma.networkctl.policy
    DESTINATION ${KDE_INSTALL_DATADIR}/polkit-1/actions
)
