return {
    name = "MCNet",
    version = "0.9.2",
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
        { source = "services/system/idle_manager.lua", destination = "services/system/idle_manager.lua" },
        { source = "services/system/display_config.lua", destination = "services/system/display_config.lua" },

        { source = "services/communications/packet.lua", destination = "services/communications/packet.lua" },
        { source = "services/communications/frame.lua", destination = "services/communications/frame.lua" },
        { source = "services/communications/network_config.lua", destination = "services/communications/network_config.lua" },
        { source = "services/communications/routing.lua", destination = "services/communications/routing.lua" },
        { source = "services/communications/network.lua", destination = "services/communications/network.lua" },
        { source = "services/communications/core_config.lua", destination = "services/communications/core_config.lua" },
        { source = "services/communications/core_client.lua", destination = "services/communications/core_client.lua" },
        { source = "services/communications/core_server.lua", destination = "services/communications/core_server.lua" },
        { source = "services/communications/contacts.lua", destination = "services/communications/contacts.lua" },
        { source = "services/communications/messaging.lua", destination = "services/communications/messaging.lua" },

        { source = "services/archive/archive_manager.lua", destination = "services/archive/archive_manager.lua" },

        { source = "services/trains/station_config.lua", destination = "services/trains/station_config.lua" },
        { source = "services/trains/rail_config.lua", destination = "services/trains/rail_config.lua" },
        { source = "services/trains/banner.lua", destination = "services/trains/banner.lua" },
        { source = "services/trains/timetable.lua", destination = "services/trains/timetable.lua" },
        { source = "services/trains/platform_controller.lua", destination = "services/trains/platform_controller.lua" },
        { source = "services/trains/station_controller.lua", destination = "services/trains/station_controller.lua" },

        { source = "drivers/modem.lua", destination = "drivers/modem.lua" },

        { source = "applications/system/console.lua", destination = "applications/system/console.lua" },
        { source = "applications/roles/generic.lua", destination = "applications/roles/generic.lua" },
        { source = "applications/roles/pda.lua", destination = "applications/roles/pda.lua" },
        { source = "applications/roles/station.lua", destination = "applications/roles/station.lua" },
        { source = "applications/roles/tower.lua", destination = "applications/roles/tower.lua" },
        { source = "applications/roles/server.lua", destination = "applications/roles/server.lua" },
        { source = "applications/roles/display.lua", destination = "applications/roles/display.lua" },
        { source = "applications/roles/archive_reader.lua", destination = "applications/roles/archive_reader.lua" },

        { source = "tests/communications/packet_test.lua", destination = "tests/communications/packet_test.lua" },
        { source = "tests/communications/frame_test.lua", destination = "tests/communications/frame_test.lua" },
        { source = "tests/communications/routing_test.lua", destination = "tests/communications/routing_test.lua" },
        { source = "tests/communications/messaging_test.lua", destination = "tests/communications/messaging_test.lua" },
        { source = "tests/communications/network_test.lua", destination = "tests/communications/network_test.lua" },
        { source = "tests/communications/mesh_test.lua", destination = "tests/communications/mesh_test.lua" },
        { source = "tests/communications/core_services_test.lua", destination = "tests/communications/core_services_test.lua" },
        { source = "tests/communications/contacts_test.lua", destination = "tests/communications/contacts_test.lua" },

        { source = "tests/trains/platform_controller_test.lua", destination = "tests/trains/platform_controller_test.lua" },
        { source = "tests/trains/station_controller_test.lua", destination = "tests/trains/station_controller_test.lua" },

        { source = "tests/drivers/modem_test.lua", destination = "tests/drivers/modem_test.lua" },
        { source = "tests/system/device_config_test.lua", destination = "tests/system/device_config_test.lua" },
        { source = "tests/system/display_config_test.lua", destination = "tests/system/display_config_test.lua" },
        { source = "tests/ui/layout_test.lua", destination = "tests/ui/layout_test.lua" }
    }
}