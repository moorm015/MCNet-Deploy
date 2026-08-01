-- MCNet tower home application

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
                label = "Relay status",
                compactLabel = "Relay status",
                description = "Show modem and future routing state.",
                action = function()
                    local start = ui.drawHeader("Relay status", device, context.version)
                    ui.printField("Tower", device.address, start)
                    ui.printField("Status", device.status, start + 1)
                    ui.printField("Modems", context.diagnostics.countModems(), start + 2)
                    ui.printField("Routing", "Not installed", start + 3, ui.getPalette().warning)
                    ui.pause()
                end
            },
            {
                label = "Network links",
                compactLabel = "Network links",
                description = "Future neighbour and routing table display.",
                action = function()
                    placeholder("Network links", "Routing is not installed yet.")
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
