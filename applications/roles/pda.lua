-- MCNet PDA home application

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
                label = "Messages",
                compactLabel = "Messages",
                description = "MCNet messages will appear here after the communications milestone.",
                action = function()
                    placeholder("Messages", "Messaging arrives in the next milestone.")
                end
            },
            {
                label = "Network scan",
                compactLabel = "Network scan",
                description = "Discover nearby MCNet devices.",
                action = function()
                    placeholder("Network scan", "Discovery is not installed yet.")
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

        local selected = menu.choose(ui, "MCNet PDA", options, device, context.version)
        if selected.exit then
            return
        end
        selected.action()
    end
end

return application
