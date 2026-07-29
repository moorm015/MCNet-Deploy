return {
    name = "MCNet",
    version = "0.3.0",

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
        }
    }
}