-- MCNet configurable multi-monitor display-wall application
-- Version 0.9.0

local application = {}

function application.run(context)
    local ui, menu = context.ui, context.menu
    local deviceModule, appManager = context.deviceModule, context.appManager
    local displayConfigModule = context.displayConfigModule
    local coreClient = context.coreClient
    local config = displayConfigModule.load()

    local function getDevice() return deviceModule.load(nil, context.version, context.protocol) end

    local function monitorNames()
        local result = {}
        if peripheral and peripheral.getNames then
            for _, name in ipairs(peripheral.getNames()) do
                if peripheral.getType(name) == "monitor" then result[#result + 1] = name end
            end
        end
        table.sort(result)
        return result
    end

    local function saveConfig()
        local saved, reason = displayConfigModule.save(config)
        if not saved then
            ui.drawHeader("Display error", getDevice(), context.version)
            print("") print(tostring(reason)) ui.pause()
        end
    end

    local function chooseDashboard()
        local categoryOptions = {}
        for _, value in ipairs(displayConfigModule.getCategories()) do
            local category = value
            table.insert(categoryOptions, {
                label = category,
                compactLabel = category,
                description = "Choose a " .. string.lower(category) .. " dashboard.",
                category = category
            })
        end
        table.insert(categoryOptions, { label = "Cancel", back = true })

        local selectedCategory = menu.choose(
            ui,
            "Display category",
            categoryOptions,
            getDevice(),
            context.version
        )
        if selectedCategory.back then return nil end

        local dashboardOptions = {}
        for _, item in ipairs(displayConfigModule.getDashboards(selectedCategory.category)) do
            local entry = item
            table.insert(dashboardOptions, {
                label = entry.label,
                compactLabel = entry.label,
                description = entry.id,
                id = entry.id
            })
        end
        table.insert(dashboardOptions, { label = "Back", back = true })

        local selectedDashboard = menu.choose(
            ui,
            selectedCategory.category .. " displays",
            dashboardOptions,
            getDevice(),
            context.version
        )
        return selectedDashboard.back and nil or selectedDashboard.id
    end

    local function chooseScale(current)
        local options = {}
        for _, value in ipairs({0.5, 1, 1.5, 2, 2.5, 3, 4, 5}) do
            local scale = value
            table.insert(options, { label = tostring(scale), value = scale })
        end
        table.insert(options, { label = "Cancel", back = true })
        local selected = menu.choose(ui, "Monitor text scale", options, getDevice(), context.version)
        return selected.back and current or selected.value
    end

    local function configureScreen(name)
        while true do
            local profile = config.screens[name] or { dashboard = "communications.overview", textScale = 0.5 }
            local options = {
                {
                    label = "Dashboard: " .. displayConfigModule.getLabel(profile.dashboard),
                    compactLabel = "Dashboard",
                    action = function()
                        local id = chooseDashboard()
                        if id then profile.dashboard = id; config.screens[name] = profile; saveConfig() end
                    end
                },
                {
                    label = "Text scale: " .. tostring(profile.textScale),
                    compactLabel = "Scale",
                    action = function()
                        profile.textScale = chooseScale(profile.textScale)
                        config.screens[name] = profile
                        saveConfig()
                    end
                },
                {
                    label = "Remove this screen",
                    compactLabel = "Remove",
                    action = function() config.screens[name] = nil; saveConfig(); return "removed" end
                },
                { label = "Back", back = true }
            }
            local selected = menu.choose(ui, "Screen " .. name, options, getDevice(), context.version)
            if selected.back then return end
            local result = selected.action()
            if result == "removed" then return end
        end
    end

    local function configureScreens()
        while true do
            local options = {}
            for _, name in ipairs(monitorNames()) do
                local profile = config.screens[name]
                table.insert(options, {
                    label = name .. "  " .. (profile and displayConfigModule.getLabel(profile.dashboard) or "UNASSIGNED"),
                    compactLabel = name,
                    description = profile and profile.dashboard or "Select a dashboard.",
                    name = name
                })
            end
            if #options == 0 then table.insert(options, { label = "No attached monitors", disabled = true }) end
            table.insert(options, { label = "Back", back = true })
            local selected = menu.choose(ui, "Configure screens", options, getDevice(), context.version)
            if selected.back then return end
            configureScreen(selected.name)
        end
    end

    local function setColour(method, value)
        if term[method] then term[method](value) end
    end

    local function clearMonitor(title)
        setColour("setBackgroundColor", colors.black)
        setColour("setTextColor", colors.white)
        term.clear()
        local width = term.getSize()
        setColour("setBackgroundColor", colors.green)
        setColour("setTextColor", colors.black)
        term.setCursorPos(1, 1)
        write(string.rep(" ", width))
        term.setCursorPos(2, 1)
        write(string.sub("MCNet | " .. title, 1, math.max(0, width - 2)))
        setColour("setBackgroundColor", colors.black)
        setColour("setTextColor", colors.white)
    end

    local function line(y, left, right, rightColour)
        local width, height = term.getSize()
        if y > height then return end
        term.setCursorPos(2, y)
        setColour("setTextColor", colors.lightGray)
        write(string.sub(tostring(left or ""), 1, math.max(0, width - 3)))
        if right then
            local text = tostring(right)
            term.setCursorPos(math.max(2, width - #text), y)
            setColour("setTextColor", rightColour or colors.white)
            write(text)
        end
    end

    local function drawOverview(data)
        clearMonitor("Communications Overview")
        local totals = data.totals or {}
        local mailbox = data.mailbox or {}
        local stats = data.stats or {}
        line(3, "Core server", data.coreOnline and "ONLINE" or "OFFLINE", data.coreOnline and colors.lime or colors.red)
        line(5, "Towers", tostring(totals.towersOnline or 0) .. "/" .. tostring(totals.towers or 0), colors.lime)
        line(6, "Devices", tostring(totals.devicesOnline or 0) .. "/" .. tostring(totals.devices or 0), colors.lime)
        line(8, "Mailbox pending", mailbox.pending or 0, colors.yellow)
        line(9, "Mailbox delivered", stats.mailboxDelivered or 0, colors.cyan)
        line(11, "Heartbeats", stats.heartbeats or 0)
        line(12, "Snapshots", stats.snapshots or 0)
    end

    local function drawTowers(data)
        clearMonitor("Tower Network")
        local y = 3
        for _, tower in ipairs(data.towers or {}) do
            local network = tower.network or {}
            local name = tower.friendlyName ~= "" and tower.friendlyName or tower.address
            line(y, name, tower.online and "ONLINE" or "OFFLINE", tower.online and colors.lime or colors.red)
            y = y + 1
            line(y, "  " .. tower.address .. "  E:" .. tostring(network.localEndpoints or 0) .. " N:" .. tostring(network.neighbours or 0), nil)
            y = y + 1
            local _, height = term.getSize()
            if y > height then break end
        end
    end

    local function drawDevices(data)
        clearMonitor("Device Directory")
        local y = 3
        for _, item in ipairs(data.devices or {}) do
            local name = item.friendlyName ~= "" and item.friendlyName or item.address
            line(y, name .. " [" .. tostring(item.type or "DEVICE") .. "]", item.online and "ON" or "OFF", item.online and colors.lime or colors.red)
            y = y + 1
            local _, height = term.getSize()
            if y > height then break end
        end
    end

    local function drawMailbox(data)
        clearMonitor("Mailbox Service")
        local mailbox = data.mailbox or {}
        local stats = data.stats or {}
        line(3, "Pending", mailbox.pending or 0, colors.yellow)
        line(4, "In transit", mailbox.sent or 0, colors.orange)
        line(5, "Delivered recently", mailbox.deliveredRecent or 0, colors.lime)
        line(7, "Stored total", stats.mailboxStored or 0)
        line(8, "Delivered total", stats.mailboxDelivered or 0)
        line(9, "Delivery attempts", stats.mailboxAttempts or 0)
    end

    local function drawFuture(title, description)
        clearMonitor(title)
        line(4, description, nil, colors.yellow)
        line(6, "The display profile is saved and will activate", nil)
        line(7, "when that MCNet service is installed.", nil)
    end

    local function drawDashboard(profile)
        local data = coreClient and coreClient.getSnapshot() or { coreOnline = false }
        if profile.dashboard == "communications.overview" then drawOverview(data)
        elseif profile.dashboard == "communications.towers" then drawTowers(data)
        elseif profile.dashboard == "communications.devices" then drawDevices(data)
        elseif profile.dashboard == "communications.mailbox" then drawMailbox(data)
        elseif profile.dashboard == "power.overview" then drawFuture("Power Overview", "Power telemetry is not installed yet.")
        elseif profile.dashboard == "trains.network" then drawFuture("Rail Network", "The live rail map is not installed yet.")
        elseif profile.dashboard == "trains.stations" then drawFuture("Station Board", "Station timetable data is not installed yet.")
        elseif profile.dashboard == "trains.routes" then drawFuture("Routes", "Route and line status is not installed yet.")
        end
    end

    local function drawAll()
        for name, profile in pairs(config.screens or {}) do
            if peripheral.getType(name) == "monitor" then
                local monitor = peripheral.wrap(name)
                if monitor then
                    if monitor.setTextScale then pcall(function() monitor.setTextScale(profile.textScale or 0.5) end) end
                    term.redirect(monitor)
                    local ok = pcall(drawDashboard, profile)
                    ui.restoreNative()
                    if not ok then -- Keep the other screens alive even if one renderer fails.
                        ui.restoreNative()
                    end
                end
            end
        end
    end

    local function runWall()
        local count = 0
        for _ in pairs(config.screens or {}) do count = count + 1 end
        if count == 0 then
            ui.drawHeader("Display wall", getDevice(), context.version)
            print("") print("No monitor screens are configured.") print("Use Configure screens first.") ui.pause()
            return
        end

        ui.restoreNative()
        term.clear()
        term.setCursorPos(1, 1)
        print("MCNet display wall running")
        print(tostring(count) .. " configured screen(s)")
        print("")
        print("Q = return to configuration")
        print("S = shut down")
        drawAll()
        local timer = os.startTimer(config.refreshInterval or 2)
        while true do
            local event = { os.pullEvent() }
            if event[1] == "timer" and event[2] == timer then
                drawAll()
                timer = os.startTimer(config.refreshInterval or 2)
            elseif event[1] == "char" and string.lower(event[2]) == "q" then
                ui.restoreNative()
                return
            elseif event[1] == "char" and string.lower(event[2]) == "s" then
                ui.restoreNative()
                os.shutdown()
            elseif event[1] == "peripheral" or event[1] == "peripheral_detach" then
                drawAll()
            end
        end
    end

    local function systemConsole()
        local child = {}
        for key, value in pairs(context) do child[key] = value end
        child.fromRole = true
        appManager.run(appManager.getSystemConsolePath(), child)
    end

    while true do
        ui.restoreNative()
        local options = {
            { label = "Run display wall", description = "Update every configured adjacent monitor.", action = runWall },
            { label = "Configure screens", description = "Assign a different dashboard to each monitor.", action = configureScreens },
            { label = "Refresh interval: " .. tostring(config.refreshInterval) .. "s", description = "Change how often live dashboards redraw.", action = function()
                local values = {1, 2, 3, 5, 10, 20, 30}
                local choices = {}
                for _, value in ipairs(values) do local v=value; choices[#choices+1]={label=tostring(v).." seconds", value=v} end
                choices[#choices+1] = {label="Cancel", back=true}
                local selected = menu.choose(ui, "Refresh interval", choices, getDevice(), context.version)
                if not selected.back then config.refreshInterval = selected.value; saveConfig() end
            end },
            { label = "Open system console", description = "Open installation and diagnostics.", action = systemConsole },
            { label = "Shut down display computer", action = function() ui.restoreNative(); os.shutdown() end }
        }
        local selected = menu.choose(ui, "MCNet Display", options, getDevice(), context.version)
        selected.action()
    end
end

return application
