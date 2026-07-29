return {
    name = "MCNet",
    version = "0.5.1",
    protocol = 1,

    files = {
        {
            source = "installer/install.lua",
            destination = "mcnet.lua"
        },

        {
            source = "services/communications/packet.lua",
            destination = "services/communications/packet.lua"
        },

        {
            source = "services/system/device_config.lua",
            destination = "services/system/device_config.lua"
        },

        {
            source = "drivers/modem.lua",
            destination = "drivers/modem.lua"
        },

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