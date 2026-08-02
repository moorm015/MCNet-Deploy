-- MCNet tower router and core heartbeat application
-- Version 0.9.0

local application = {}

function application.run(context)
    local ui, menu = context.ui, context.menu
    local deviceModule, appManager = context.deviceModule, context.appManager
    local network, coreClient = context.network, context.coreClient

    local function getDevice() return deviceModule.load(nil, context.version, context.protocol) end

    local function showNotice(title, message)
        local start = ui.drawHeader(title, getDevice(), context.version)
        ui.writeAt(ui.getLayout().left, start, tostring(message), ui.getPalette().foreground)
        ui.pause()
    end

    local function systemConsole()
        local child = {}
        for key, value in pairs(context) do child[key] = value end
        child.fromRole = true
        local completed, reason = appManager.run(appManager.getSystemConsolePath(), child)
        if not completed then showNotice("System console error", tostring(reason)) end
    end

    local function relayStatus()
        local status = network.getStatus()
        local core = coreClient and coreClient.getStatus() or { online = false, coreAddress = "NONE" }
        local start = ui.drawHeader("Relay status", getDevice(), context.version)
        ui.printField("Router", status.address, start)
        ui.printField("Channel", status.channel, start + 1)
        ui.printField("Modem", status.modemReady and "READY" or "UNAVAILABLE", start + 2)
        ui.printField("Core", core.online and "ONLINE" or "OFFLINE", start + 3)
        ui.printField("Core address", core.coreAddress, start + 4)
        ui.printField("Neighbours", status.neighbours, start + 5)
        ui.printField("Endpoints", status.localEndpoints, start + 6)
        ui.printField("Destinations", status.knownDestinations, start + 7)
        ui.printField("Forwarded", status.counters.framesForwarded, start + 8)
        ui.printField("Dropped", status.counters.framesDropped, start + 9)
        ui.pause()
    end

    local function listEntries(title, entries, labelFunction, detailFunction)
        while true do
            local options = {}
            for _, entry in ipairs(entries()) do
                local item = entry
                table.insert(options, {
                    label = labelFunction(item),
                    compactLabel = item.address or item.destination or item.origin or "Entry",
                    description = detailFunction(item),
                    action = function() showNotice(title, detailFunction(item)) end
                })
            end
            if #options == 0 then table.insert(options, { label = "No entries are currently known", disabled = true }) end
            table.insert(options, { label = "Return to tower", compactLabel = "Back", back = true })
            local selected = menu.choose(ui, title, options, getDevice(), context.version)
            if selected.back then return end
            selected.action()
        end
    end

    local function neighbours()
        listEntries("Tower neighbours", network.getNeighbours,
            function(item) return item.address .. "  " .. tostring(item.distance or 0) .. " blocks" end,
            function(item) return item.address .. " | " .. tostring(item.region or "UNKNOWN") .. " | " .. tostring(item.distance or 0) .. " blocks" end)
    end

    local function endpoints()
        listEntries("Attached endpoints", network.getLocalEndpoints,
            function(item)
                local name = item.friendlyName and item.friendlyName ~= "" and item.friendlyName or item.address
                return name .. "  " .. tostring(item.type or "ENDPOINT")
            end,
            function(item) return item.address .. " | " .. tostring(item.type or "ENDPOINT") .. " | " .. tostring(item.distance or 0) .. " blocks" end)
    end

    local function topology()
        listEntries("Link-state database", network.getTopology,
            function(item) return item.origin .. "  seq " .. tostring(item.sequence or 0) end,
            function(item) return item.origin .. " advertises " .. tostring(#(item.neighbours or {})) .. " neighbours and " .. tostring(#(item.endpoints or {})) .. " endpoints" end)
    end

    local function destinations()
        listEntries("Known destinations", network.getKnownDestinations,
            function(item) return item.destination .. " via " .. tostring(item.owner or "UNKNOWN") end,
            function(item) return tostring(item.kind or "DESTINATION") .. " " .. item.destination .. " is attached to " .. tostring(item.owner or "UNKNOWN") end)
    end

    while true do
        local device = getDevice()
        local options = {
            { label = "Relay status", description = "Show routing, core and traffic counters.", action = relayStatus },
            { label = "Direct tower neighbours", compactLabel = "Neighbours", description = "Show towers currently inside wireless range.", action = neighbours },
            { label = "Attached endpoints", compactLabel = "Endpoints", description = "Show PDAs, displays and other devices registered here.", action = endpoints },
            { label = "Link-state database", compactLabel = "Topology", description = "Show route advertisements learned from the mesh.", action = topology },
            { label = "Known destinations", compactLabel = "Destinations", description = "Show towers and endpoints that can be routed.", action = destinations },
            { label = "Open system console", compactLabel = "System console", description = "Open installation, settings and diagnostics.", action = systemConsole },
            { label = "Shut down tower", compactLabel = "Shut down", description = "Stop this relay until the computer is powered on again.", action = function()
                ui.drawHeader("Shut down tower", device, context.version)
                print("")
                if ui.askYesNo("Shut down this tower?") then ui.restoreNative(); os.shutdown() end
            end }
        }
        local selected = menu.choose(ui, deviceModule.getDisplayName(device), options, device, context.version)
        selected.action()
    end
end

return application
