return {
    name = "MCNet",
    version = "0.6.0",

    files = {

        -- Main Console

        {
            source = "mcnet.lua",
            destination = "mcnet.lua"
        },

        -- Drivers

        {
            source = "drivers/modem.lua",
            destination = "drivers/modem.lua"
        },

        -- System Services

        {
            source = "services/system/device_config.lua",
            destination = "services/system/device_config.lua"
        },

        -- UI Services

        {
            source = "services/ui/theme.lua",
            destination = "services/ui/theme.lua"
        },

        {
            source = "services/ui/ui.lua",
            destination = "services/ui/ui.lua"
        },

        {
            source = "services/ui/menu.lua",
            destination = "services/ui/menu.lua"
        },

        -- Communications

        {
            source = "services/communications/packet.lua",
            destination = "services/communications/packet.lua"
        },

        -- Tests

        {
            source = "tests/communications/packet_test.lua",
            destination = "tests/communications/packet_test.lua"
        },

        {
            source = "tests/drivers/modem_test.lua",
            destination = "tests/drivers/modem_test.lua"
        },

        {
            source = "tests/system/device_config_test.lua",
            destination = "tests/system/device_config_test.lua"
        }
    }
}