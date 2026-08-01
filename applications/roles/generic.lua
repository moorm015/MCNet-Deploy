-- MCNet generic device application

local application = {}

function application.run(context)
    local ui = context.ui
    local menu = context.menu
    local deviceModule = context.deviceModule
    local appManager = context.appManager

    local function getDevice()
        return deviceModule.load(nil, context.version, context.protocol)
    end

    local function openSystemConsole()
        local child = {}
        for key, value in pairs(context) do
            child[key] = value
        end
        child.fromRole = true
        return appManager.run(appManager.getSystemConsolePath(), child)
    end

    while true do
        local device = getDevice()
        local options = {
            {
                label = "Device status",
                compactLabel = "Status",
                description = "Show the current identity and role.",
                action = function()
                    local start = ui.drawHeader("Device status", device, context.version)
                    ui.printField("Address", device.address, start)
                    ui.printField("Role", device.type, start + 1)
                    ui.printField("Region", device.region, start + 2)
                    ui.printField("Status", device.status, start + 3)
                    ui.pause()
                end
            },
            {
                label = "Open system console",
                compactLabel = "System console",
                description = "Open installation, settings and diagnostic tools.",
                action = function()
                    local completed, reason = openSystemConsole()
                    if not completed then
                        ui.clear()
                        print(tostring(reason))
                        ui.pause()
                    end
                end
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
