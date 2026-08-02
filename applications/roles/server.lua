-- MCNet core server application
-- Version 0.9.0

local application = {}

function application.run(context)
    local ui, menu = context.ui, context.menu
    local deviceModule, appManager = context.deviceModule, context.appManager
    local coreServer = context.coreServer

    local function getDevice() return deviceModule.load(nil, context.version, context.protocol) end
    local function snapshot() return coreServer and coreServer.getSnapshot() or { devices={}, towers={}, events={}, totals={}, mailbox={}, stats={} } end

    local function systemConsole()
        local child = {}
        for key, value in pairs(context) do child[key] = value end
        child.fromRole = true
        local ok, reason = appManager.run(appManager.getSystemConsolePath(), child)
        if not ok then
            ui.drawHeader("System console error", getDevice(), context.version)
            print("") print(tostring(reason)) ui.pause()
        end
    end

    local function overview()
        local data = snapshot()
        local start = ui.drawHeader("MCNet Core", getDevice(), context.version)
        ui.printField("Server", data.server and data.server.address or "UNKNOWN", start)
        ui.printField("Devices online", tostring(data.totals.devicesOnline or 0) .. "/" .. tostring(data.totals.devices or 0), start + 1)
        ui.printField("Towers online", tostring(data.totals.towersOnline or 0) .. "/" .. tostring(data.totals.towers or 0), start + 2)
        ui.printField("Mailbox pending", data.mailbox.pending or 0, start + 3)
        ui.printField("Mailbox sent", data.mailbox.sent or 0, start + 4)
        ui.printField("Messages delivered", data.stats.mailboxDelivered or 0, start + 5)
        ui.printField("Heartbeats", data.stats.heartbeats or 0, start + 6)
        ui.printField("Snapshots", data.stats.snapshots or 0, start + 7)
        ui.pause()
    end

    local function listPage(title, entries, label, detail)
        while true do
            local options = {}
            for _, entry in ipairs(entries()) do
                local item = entry
                table.insert(options, {
                    label = label(item),
                    compactLabel = item.friendlyName ~= "" and item.friendlyName or item.address,
                    description = detail(item),
                    action = function()
                        ui.drawHeader(title, getDevice(), context.version)
                        print("") print(detail(item)) ui.pause()
                    end
                })
            end
            if #options == 0 then table.insert(options, { label = "No entries", disabled = true }) end
            table.insert(options, { label = "Back", back = true })
            local selected = menu.choose(ui, title, options, getDevice(), context.version)
            if selected.back then return end
            selected.action()
        end
    end

    local function towers()
        listPage("Tower registry", function() return snapshot().towers or {} end,
            function(item) return item.address .. "  " .. (item.online and "ONLINE" or "OFFLINE") end,
            function(item)
                local n = item.network or {}
                return tostring(item.friendlyName or item.address) .. " | " .. (item.online and "ONLINE" or "OFFLINE")
                    .. " | endpoints " .. tostring(n.localEndpoints or 0)
                    .. " | neighbours " .. tostring(n.neighbours or 0)
                    .. " | forwarded " .. tostring(n.counters and n.counters.framesForwarded or 0)
            end)
    end

    local function devices()
        listPage("Device directory", function() return snapshot().devices or {} end,
            function(item)
                local name = item.friendlyName ~= "" and item.friendlyName or item.address
                return name .. "  " .. (item.online and "ONLINE" or "OFFLINE")
            end,
            function(item)
                return item.address .. " | " .. tostring(item.type or "DEVICE") .. " | "
                    .. tostring(item.region or "UNKNOWN") .. " | tower " .. tostring(item.selectedTower or "NONE")
            end)
    end

    local function events()
        local data = snapshot().events or {}
        local options = {}
        for index = #data, math.max(1, #data - 49), -1 do
            local item = data[index]
            table.insert(options, {
                label = tostring(item.kind) .. "  " .. tostring(item.message),
                compactLabel = tostring(item.kind) .. " " .. tostring(item.source or ""),
                description = "Day " .. tostring(item.day) .. " time " .. tostring(item.time),
                action = function()
                    ui.drawHeader("Network event", getDevice(), context.version)
                    print("") print(tostring(item.message)) print("") print("Source: " .. tostring(item.source or "LOCAL")) ui.pause()
                end
            })
        end
        if #options == 0 then table.insert(options, { label = "No events", disabled = true }) end
        table.insert(options, { label = "Back", back = true })
        while true do
            local selected = menu.choose(ui, "Event log", options, getDevice(), context.version)
            if selected.back then return end
            selected.action()
        end
    end

    while true do
        local options = {
            { label = "Core overview", description = "Show directory, towers and mailbox totals.", action = overview },
            { label = "Tower registry", description = "Show live and offline tower reports.", action = towers },
            { label = "Device directory", description = "Show every registered MCNet device.", action = devices },
            { label = "Event log", description = "Show online, offline and mailbox activity.", action = events },
            { label = "Open system console", description = "Open installation and diagnostics.", action = systemConsole },
            { label = "Shut down core server", description = "Stop directory and mailbox services.", action = function()
                ui.drawHeader("Shut down", getDevice(), context.version)
                print("")
                if ui.askYesNo("Shut down SRV-001?") then ui.restoreNative(); os.shutdown() end
            end }
        }
        local selected = menu.choose(ui, "MCNet Core Server", options, getDevice(), context.version)
        selected.action()
    end
end

return application
