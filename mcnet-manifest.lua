return {
    name = "MCNet",
    version = "0.8.0",
    protocol = 1,
    entrypoint = "kernel/boot.lua",

    remove = {
        "mcnet.lua",
        "kernel/console.lua"
    },

    files = {
        { source = "startup.lua", destination = "startup" },

        { source = "kernel/boot.lua", destination = "kernel/boot.lua" },
        { source = "kernel/app_manager.lua", destination = "kernel/app_manager.lua" },

        { source = "services/ui/theme.lua", destination = "services/ui/theme.lua" },
        { source = "services/ui/layout.lua", destination = "services/ui/layout.lua" },
        { source = "services/ui/logos.lua", destination = "services/ui/logos.lua" },
        { source = "services/ui/ui.lua", destination = "services/ui/ui.lua" },
        { source = "services/ui/loading.lua", destination = "services/ui/loading.lua" },
        { source = "services/ui/menu.lua", destination = "services/ui/menu.lua" },

        { source = "services/system/settings.lua", destination = "services/system/settings.lua" },
        { source = "services/system/device_config.lua", destination = "services/system/device_config.lua" },
        { source = "services/system/diagnostics.lua", destination = "services/system/diagnostics.lua" },

        { source = "services/communications/packet.lua", destination = "services/communications/packet.lua" },
        { source = "services/communications/frame.lua", destination = "services/communications/frame.lua" },
        { source = "services/communications/network_config.lua", destination = "services/communications/network_config.lua" },
        { source = "services/communications/routing.lua", destination = "services/communications/routing.lua" },
        { source = "services/communications/network.lua", destination = "services/communications/network.lua" },
        { source = "services/communications/messaging.lua", destination = "services/communications/messaging.lua" },

        { source = "drivers/modem.lua", destination = "drivers/modem.lua" },

        { source = "applications/system/console.lua", destination = "applications/system/console.lua" },
        { source = "applications/roles/generic.lua", destination = "applications/roles/generic.lua" },
        { source = "applications/roles/pda.lua", destination = "applications/roles/pda.lua" },
        { source = "applications/roles/station.lua", destination = "applications/roles/station.lua" },
        { source = "applications/roles/tower.lua", destination = "applications/roles/tower.lua" },

        { source = "tests/communications/packet_test.lua", destination = "tests/communications/packet_test.lua" },
        { source = "tests/communications/frame_test.lua", destination = "tests/communications/frame_test.lua" },
        { source = "tests/communications/routing_test.lua", destination = "tests/communications/routing_test.lua" },
        { source = "tests/communications/messaging_test.lua", destination = "tests/communications/messaging_test.lua" },
        { source = "tests/communications/network_test.lua", destination = "tests/communications/network_test.lua" },
        { source = "tests/communications/mesh_test.lua", destination = "tests/communications/mesh_test.lua" },

        { source = "tests/drivers/modem_test.lua", destination = "tests/drivers/modem_test.lua" },
        { source = "tests/system/device_config_test.lua", destination = "tests/system/device_config_test.lua" },
        { source = "tests/ui/layout_test.lua", destination = "tests/ui/layout_test.lua" }
    }
}
