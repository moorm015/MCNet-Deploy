-- MCNet station home application

local application = {}

function application.run(context)
    local ui = context.ui
    local menu = context.menu
    local deviceModule = context.deviceModule
    local appManager = context.appManager

    local function getDevice()
        return deviceModule.load(nil, context.version, context.protocol)
    end

    local function placeholder(title, message)
        local start = ui.drawHeader(title, getDevice(), context.version)
        local layout = ui.getLayout()
        ui.writeAt(layout.left, start, message, ui.getPalette().warning)
        ui.pause()
    end

    local function systemConsole()
        local child = {}
        for key, value in pairs(context) do
            child[key] = value
        end
        child.fromRole = true
        local completed, reason = appManager.run(appManager.getSystemConsolePath(), child)
        if not completed then
            placeholder("System console error", tostring(reason))
        end
    end

    while true do
        local device = getDevice()
        local options = {
            {
                label = "Next train arrivals",
                compactLabel = "Arrivals",
                description = "Future live arrival and destination board.",
                action = function()
                    placeholder("Arrivals", "Train timing service is not installed yet.")
                end
            },
            {
                label = "Select destination",
                compactLabel = "Destinations",
                description = "Future passenger destination and route selector.",
                action = function()
                    placeholder("Destinations", "Route selection is not installed yet.")
                end
            },
            {
                label = "Station status",
                compactLabel = "Status",
                description = "Show the station identity and current operating state.",
                action = function()
                    local start = ui.drawHeader("Station status", device, context.version)
                    ui.printField("Station", deviceModule.getDisplayName(device), start)
                    ui.printField("Address", device.address, start + 1)
                    ui.printField("Region", device.region, start + 2)
                    ui.printField("Status", device.status, start + 3)
                    ui.pause()
                end
            },
            {
                label = "Open system console",
                compactLabel = "System console",
                description = "Open installation, settings and diagnostics.",
                action = systemConsole
            },
            {
                label = "Exit to CraftOS",
                compactLabel = "Exit",
                exit = true
            }
        }

        local selected = menu.choose(ui, deviceModule.getDisplayName(device), options, device, context.version)
        if selected.exit then
            return
        end
        selected.action()
    end
end

return application
