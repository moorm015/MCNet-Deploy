-- MCNet deployment manifest
-- Version 0.9.3
-- Modular package layout
--
-- The installer always installs packages.default, then adds the package set
-- for the computer's saved device role from packages.roles.
--
-- roles.DEFAULT is used for an unconfigured computer and for device types
-- without a specialised application. This is important: a fresh computer
-- must still be able to boot the System Console and join MCNet as a client.
--
-- Persistent configuration under .mcnet/ is not listed here and is therefore
-- retained when a computer changes role.
return {
    name = "MCNet",
    version = "0.9.3",
    protocol = 1,
    entrypoint = "kernel/boot.lua",
    packages = {
        default = {
            "CORE",
            "NETWORK"
        },
        roles = {
            -- Fresh/unconfigured computers and generic device types.
            DEFAULT = {
                "CLIENT"
            },
            SERVER = {
                "SERVER"
            },
            TOWER = {
                "CLIENT",
                "TOWER"
            },
            PDA = {
                "CLIENT",
                "PDA"
            },
            STATION = {
                "CLIENT",
                "STATION"
            },
            DISPLAY = {
                "CLIENT",
                "DISPLAY"
            },
            ARCHIVE = {
                "CLIENT",
                "ARCHIVE"
            },
            -- Development/test computer. TESTS also tags the specialised
            -- modules required by the complete test suite.
            TEST = {
                "CLIENT",
                "TESTS"
            }
        }
    },
    remove = {
        "mcnet.lua",
        "kernel/console.lua"
    },
    files = {
        -- ================================================================
        -- CORE
        -- Boot, shared UI, device/configuration services and console.
        -- ================================================================
        {
            source = "startup.lua",
            destination = "startup",
            packages = "CORE"
        },
        {
            source = "kernel/boot.lua",
            destination = "kernel/boot.lua",
            packages = "CORE"
        },
        {
            source = "kernel/app_manager.lua",
            destination = "kernel/app_manager.lua",
            packages = "CORE"
        },
        {
            source = "services/ui/theme.lua",
            destination = "services/ui/theme.lua",
            packages = "CORE"
        },
        {
            source = "services/ui/layout.lua",
            destination = "services/ui/layout.lua",
            packages = "CORE"
        },
        {
            source = "services/ui/logos.lua",
            destination = "services/ui/logos.lua",
            packages = "CORE"
        },
        {
            source = "services/ui/ui.lua",
            destination = "services/ui/ui.lua",
            packages = "CORE"
        },
        {
            source = "services/ui/loading.lua",
            destination = "services/ui/loading.lua",
            packages = "CORE"
        },
        {
            source = "services/ui/menu.lua",
            destination = "services/ui/menu.lua",
            packages = "CORE"
        },
        {
            source = "services/system/settings.lua",
            destination = "services/system/settings.lua",
            packages = "CORE"
        },
        {
            source = "services/system/device_config.lua",
            destination = "services/system/device_config.lua",
            packages = "CORE"
        },
        {
            source = "services/system/diagnostics.lua",
            destination = "services/system/diagnostics.lua",
            packages = "CORE"
        },
        {
            source = "applications/system/console.lua",
            destination = "applications/system/console.lua",
            packages = "CORE"
        },
        -- Generic stays tiny and universal. Unknown/future device types can
        -- therefore still open a safe role application without another sync.
        {
            source = "applications/roles/generic.lua",
            destination = "applications/roles/generic.lua",
            packages = "CORE"
        },
        -- ================================================================
        -- NETWORK
        -- Shared routed-network and messaging runtime used by every role.
        -- ================================================================
        {
            source = "services/communications/packet.lua",
            destination = "services/communications/packet.lua",
            packages = "NETWORK"
        },
        {
            source = "services/communications/frame.lua",
            destination = "services/communications/frame.lua",
            packages = "NETWORK"
        },
        {
            source = "services/communications/network_config.lua",
            destination = "services/communications/network_config.lua",
            packages = "NETWORK"
        },
        {
            source = "services/communications/routing.lua",
            destination = "services/communications/routing.lua",
            packages = "NETWORK"
        },
        {
            source = "services/communications/network.lua",
            destination = "services/communications/network.lua",
            packages = "NETWORK"
        },
        {
            source = "services/communications/core_config.lua",
            destination = "services/communications/core_config.lua",
            packages = "NETWORK"
        },
        {
            source = "services/communications/contacts.lua",
            destination = "services/communications/contacts.lua",
            packages = "NETWORK"
        },
        {
            source = "services/communications/messaging.lua",
            destination = "services/communications/messaging.lua",
            packages = "NETWORK"
        },
        {
            source = "drivers/modem.lua",
            destination = "drivers/modem.lua",
            packages = "NETWORK"
        },
        -- ================================================================
        -- CLIENT
        -- Core-directory client used by every non-SERVER runtime.
        -- ================================================================
        {
            source = "services/communications/core_client.lua",
            destination = "services/communications/core_client.lua",
            packages = "CLIENT"
        },
        -- ================================================================
        -- SERVER
        -- Central directory/mailbox server and archive-writing support.
        -- core_server is also installed on TEST computers for its tests.
        -- ================================================================
        {
            source = "services/communications/core_server.lua",
            destination = "services/communications/core_server.lua",
            packages = {
                "SERVER",
                "TESTS"
            }
        },
        {
            source = "services/archive/archive_manager.lua",
            destination = "services/archive/archive_manager.lua",
            packages = "SERVER"
        },
        {
            source = "applications/roles/server.lua",
            destination = "applications/roles/server.lua",
            packages = "SERVER"
        },
        -- ================================================================
        -- PDA
        -- ================================================================
        {
            source = "services/system/idle_manager.lua",
            destination = "services/system/idle_manager.lua",
            packages = "PDA"
        },
        {
            source = "applications/roles/pda.lua",
            destination = "applications/roles/pda.lua",
            packages = "PDA"
        },
        -- ================================================================
        -- TOWER
        -- Routing logic itself is shared NETWORK code; this package is the
        -- tower-specific operator application.
        -- ================================================================
        {
            source = "applications/roles/tower.lua",
            destination = "applications/roles/tower.lua",
            packages = "TOWER"
        },
        -- ================================================================
        -- DISPLAY
        -- Railway passenger-display data plus display configuration.
        -- Shared rail data is tagged STATION as well where both roles use it.
        -- TESTS is included only on modules required by a packaged test.
        -- ================================================================
        {
            source = "services/system/display_config.lua",
            destination = "services/system/display_config.lua",
            packages = {
                "DISPLAY",
                "TESTS"
            }
        },
        {
            source = "services/trains/rail_config.lua",
            destination = "services/trains/rail_config.lua",
            packages = {
                "DISPLAY",
                "STATION"
            }
        },
        {
            source = "services/trains/network_map.lua",
            destination = "services/trains/network_map.lua",
            packages = "DISPLAY"
        },
        {
            source = "services/trains/banner.lua",
            destination = "services/trains/banner.lua",
            packages = "DISPLAY"
        },
        {
            source = "services/trains/timetable.lua",
            destination = "services/trains/timetable.lua",
            packages = {
                "DISPLAY",
                "STATION"
            }
        },
        {
            source = "applications/roles/display.lua",
            destination = "applications/roles/display.lua",
            packages = "DISPLAY"
        },
        -- ================================================================
        -- STATION
        -- Local D1/D2/D3/H1 platform safety/control stack.
        -- Rail controller modules are also present on TEST computers.
        -- ================================================================
        {
            source = "services/trains/station_config.lua",
            destination = "services/trains/station_config.lua",
            packages = {
                "STATION",
                "TESTS"
            }
        },
        {
            source = "services/trains/platform_controller.lua",
            destination = "services/trains/platform_controller.lua",
            packages = {
                "STATION",
                "TESTS"
            }
        },
        {
            source = "services/trains/station_controller.lua",
            destination = "services/trains/station_controller.lua",
            packages = {
                "STATION",
                "TESTS"
            }
        },
        {
            source = "applications/roles/station.lua",
            destination = "applications/roles/station.lua",
            packages = "STATION"
        },
        -- ================================================================
        -- ARCHIVE READER
        -- Read-only archive browsing computer. Archive-writing code remains
        -- SERVER-only.
        -- ================================================================
        {
            source = "applications/roles/archive_reader.lua",
            destination = "applications/roles/archive_reader.lua",
            packages = "ARCHIVE"
        },
        -- ================================================================
        -- TESTS
        -- Not installed on normal devices. Set a development computer's
        -- device type to TEST to install this package.
        -- ================================================================
        {
            source = "tests/communications/packet_test.lua",
            destination = "tests/communications/packet_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/communications/frame_test.lua",
            destination = "tests/communications/frame_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/communications/routing_test.lua",
            destination = "tests/communications/routing_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/communications/messaging_test.lua",
            destination = "tests/communications/messaging_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/communications/network_test.lua",
            destination = "tests/communications/network_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/communications/mesh_test.lua",
            destination = "tests/communications/mesh_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/communications/core_services_test.lua",
            destination = "tests/communications/core_services_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/communications/contacts_test.lua",
            destination = "tests/communications/contacts_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/trains/platform_controller_test.lua",
            destination = "tests/trains/platform_controller_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/trains/station_controller_test.lua",
            destination = "tests/trains/station_controller_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/drivers/modem_test.lua",
            destination = "tests/drivers/modem_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/system/device_config_test.lua",
            destination = "tests/system/device_config_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/system/display_config_test.lua",
            destination = "tests/system/display_config_test.lua",
            packages = "TESTS"
        },
        {
            source = "tests/ui/layout_test.lua",
            destination = "tests/ui/layout_test.lua",
            packages = "TESTS"
        }
    }
}
