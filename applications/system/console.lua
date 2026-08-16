-- MCNet system console application
-- Version 0.9.2

local application = {}

function application.run(context)
    local ui = context.ui
    local menu = context.menu
    local settingsModule = context.settingsModule
    local deviceModule = context.deviceModule
    local appManager = context.appManager
    local settings = context.settings
    local coreConfigModule = context.coreConfigModule
    local coreConfig = context.coreConfig
    local VERSION = context.version
    local PROTOCOL = context.protocol
    local INSTALLER_LOCAL = ".mcnet-installer.lua"

    local function getDevice()
        return deviceModule.load(nil, VERSION, PROTOCOL)
    end

    local function cloneContext()
        local result = {}
        for key, value in pairs(context) do
            result[key] = value
        end
        return result
    end

    local function saveSettings()
        local saved, reason = settingsModule.save(settings)
        if not saved then
            ui.clear()
            print("Could not save settings:")
            print(tostring(reason))
            ui.pause()
            return false
        end

        context.settings = settings
        local configured, configureReason = ui.configure(settings)
        if not configured then
            settings.display = "native"
            settingsModule.save(settings)
            ui.configure(settings)

            ui.clear()
            print("Display setting could not be applied:")
            print(tostring(configureReason))
            print("")
            print("The native display has been restored.")
            ui.pause()
        end

        return true
    end

    local function installOrUpdate()
        ui.drawHeader("Install or update MCNet", getDevice(), VERSION)
        print("")
        print("Downloading standalone installer...")

        if not http or not http.get then
            print("")
            print("HTTP is disabled or unavailable.")
            ui.pause()
            return
        end

        local response, reason = http.get(context.installerUrl)
        if not response then
            print("")
            print("Download failed:")
            print(tostring(reason))
            ui.pause()
            return
        end

        local contents = response.readAll()
        response.close()

        if not contents or #contents == 0 then
            print("")
            print("Installer download was empty.")
            ui.pause()
            return
        end

        if fs.exists(INSTALLER_LOCAL) then
            fs.delete(INSTALLER_LOCAL)
        end

        local file = fs.open(INSTALLER_LOCAL, "w")
        if not file then
            print("")
            print("Could not write installer file.")
            ui.pause()
            return
        end

        file.write(contents)
        file.close()

        print("Downloaded " .. tostring(#contents) .. " bytes.")
        print("Starting installer...")
        sleep(0.3)

        ui.restoreNative()

        local completed =
            os.run(
                getfenv(),
                INSTALLER_LOCAL
            )

        if completed then
            if fs.exists(INSTALLER_LOCAL) then
                fs.delete(INSTALLER_LOCAL)
            end
            print("")
            print("Update complete. Rebooting...")
            sleep(1)
            os.reboot()
        end

        ui.configure(settings)
        ui.pause("Installer returned an error. Press Enter...")
    end

    local function chooseValue(title, values, current, displayFunction)
        local options = {}

        for _, value in ipairs(values) do
            local display = displayFunction and displayFunction(value) or tostring(value)
            table.insert(options, {
                label = display .. (value == current and "  [current]" or ""),
                compactLabel = display,
                value = value
            })
        end

        table.insert(options, {
            label = "Cancel",
            back = true
        })

        local selected = menu.choose(ui, title, options, getDevice(), VERSION)
        if selected.back then
            return nil
        end
        return selected.value
    end

    local function configureDevice()
        ui.restoreNative()

        local current = getDevice()
        local selectedType = chooseValue("Select device type", deviceModule.getTypes(false), current.type)
        if not selectedType then
            return
        end

        ui.drawHeader("Configure device", current, VERSION)
        print("")
        print("Press Enter to keep the shown value.")
        print("Friendly name may be left blank.")
        print("")

        local suggestedAddress = current.address
        if suggestedAddress == "UNKNOWN" then
            suggestedAddress = deviceModule.getSuggestedAddress(selectedType)
        end

        local suggestedSystem = current.systemName
        if not suggestedSystem or suggestedSystem == "" or string.sub(suggestedSystem, 1, 6) == "MCNET-" then
            suggestedSystem = deviceModule.getSuggestedSystemName(selectedType)
        end

        local proposed = {
            address = ui.readDefault("MCNet address", suggestedAddress),
            systemName = ui.readDefault("System name", suggestedSystem),
            friendlyName = ui.readDefault("Friendly name", current.friendlyName or ""),
            type = selectedType,
            region = ui.readDefault("Region", current.region ~= "UNKNOWN" and current.region or "HOME"),
            owner = ui.readDefault("Owner", current.owner or "MCNet"),
            status = "ONLINE",
            computerID = os.getComputerID(),
            version = VERSION,
            protocol = PROTOCOL
        }

        proposed = deviceModule.normalise(proposed, VERSION, PROTOCOL)
        local valid, reason = deviceModule.validate(proposed)

        if not valid then
            print("")
            print("Configuration is invalid:")
            print(tostring(reason))
            ui.pause()
            return
        end

        ui.drawHeader("Confirm device", proposed, VERSION)
        print("")
        print("Address : " .. proposed.address)
        print("System  : " .. proposed.systemName)
        print("Friendly: " .. (proposed.friendlyName ~= "" and proposed.friendlyName or "None"))
        print("Type    : " .. proposed.type)
        print("Region  : " .. proposed.region)
        print("Owner   : " .. proposed.owner)
        print("")

        if not ui.askYesNo("Save this configuration?") then
            return
        end

        local saved, saveReason = deviceModule.save(proposed, nil, VERSION, PROTOCOL)
        if not saved then
            print("")
            print("Could not save configuration:")
            print(tostring(saveReason))
            ui.pause()
            return
        end

        if os.setComputerLabel then
            os.setComputerLabel(proposed.systemName)
        end

        if context.network then
            context.network.setDevice(proposed)
        end

        if context.messaging then
            context.messaging.setDevice(proposed)
        end

        if context.coreClient then
            context.coreClient.setDevice(proposed)
        end

        print("")
        print(proposed.address .. " is now configured.")
        print("Reboot to apply any device-role change.")
        ui.pause()
        ui.configure(settings)
    end

    local function deviceInformation()
        local device = getDevice()
        local start = ui.drawHeader("Device information", device, VERSION)
        ui.printField("Address", device.address, start)
        ui.printField("System name", device.systemName, start + 1)
        ui.printField("Friendly name", device.friendlyName ~= "" and device.friendlyName or "None", start + 2)
        ui.printField("Type", device.type, start + 3)
        ui.printField("Region", device.region, start + 4)
        ui.printField("Owner", device.owner, start + 5)
        ui.printField("Status", device.status, start + 6)
        ui.printField("Computer ID", device.computerID, start + 7)
        ui.printField("MCNet version", device.version, start + 8)
        ui.printField("Protocol", device.protocol, start + 9)
        ui.pause()
    end

    local function toggleSetting(key)
        settings[key] = not settings[key]
        saveSettings()
    end

    local function settingsMenu()
        while true do
            local options = {
                {
                    label = "Theme: " .. context.themeLibrary.getDisplayName(settings.theme),
                    compactLabel = "Theme: " .. settings.theme,
                    description = "Change the terminal colour palette.",
                    action = function()
                        local value = chooseValue("Select theme", context.themeLibrary.getNames(), settings.theme, context.themeLibrary.getDisplayName)
                        if value then
                            settings.theme = value
                            saveSettings()
                        end
                    end
                },
                {
                    label = "Loading logo: " .. tostring(settings.logo),
                    compactLabel = "Logo: " .. tostring(settings.logo),
                    description = "Choose a mob logo, random rotation, or no logo.",
                    action = function()
                        local value = chooseValue("Select loading logo", context.logoLibrary.getNames(), settings.logo)
                        if value then
                            settings.logo = value
                            saveSettings()
                        end
                    end
                },
                {
                    label = "Animations: " .. (settings.animations and "On" or "Off"),
                    compactLabel = "Animations: " .. (settings.animations and "On" or "Off"),
                    description = "Enable or disable loading pauses and visual transitions.",
                    action = function()
                        toggleSetting("animations")
                    end
                },
                {
                    label = "Layout: " .. tostring(settings.layout),
                    compactLabel = "Layout: " .. tostring(settings.layout),
                    description = "Automatically size the UI, or force compact/full mode.",
                    action = function()
                        local value = chooseValue("Select layout", { "auto", "compact", "full" }, settings.layout)
                        if value then
                            settings.layout = value
                            saveSettings()
                        end
                    end
                },
                {
                    label = "Display: " .. tostring(settings.display),
                    compactLabel = "Display: " .. tostring(settings.display),
                    description = "Use the native screen or an attached monitor.",
                    action = function()
                        local values = { "native" }
                        for _, monitorName in ipairs(ui.listMonitors()) do
                            table.insert(values, monitorName)
                        end

                        local value = chooseValue("Select display", values, settings.display)
                        if value then
                            settings.display = value
                            saveSettings()
                        end
                    end
                },
                {
                    label = "Monitor scale: " .. tostring(settings.monitorScale),
                    compactLabel = "Scale: " .. tostring(settings.monitorScale),
                    description = "Set the character scale used on an Advanced Monitor.",
                    action = function()
                        local value = chooseValue("Monitor text scale", { 0.5, 1, 1.5, 2, 2.5, 3, 4, 5 }, settings.monitorScale)
                        if value then
                            settings.monitorScale = value
                            saveSettings()
                        end
                    end
                },
                {
                    label = "Footer help: " .. (settings.showFooter and "On" or "Off"),
                    compactLabel = "Footer: " .. (settings.showFooter and "On" or "Off"),
                    description = "Show controls and descriptions along the bottom edge.",
                    action = function()
                        toggleSetting("showFooter")
                    end
                },
                {
                    label = "Header status: " .. (settings.showStatus and "On" or "Off"),
                    compactLabel = "Status: " .. (settings.showStatus and "On" or "Off"),
                    description = "Show the device status in page headers.",
                    action = function()
                        toggleSetting("showStatus")
                    end
                },
                {
                    label = "Boot target: " .. (settings.bootTarget == "role" and "Device application" or "System console"),
                    compactLabel = "Boot: " .. tostring(settings.bootTarget),
                    description = "Choose the system console or this device role's home application.",
                    action = function()
                        local value = chooseValue("Select boot target", { "console", "role" }, settings.bootTarget)
                        if value then
                            settings.bootTarget = value
                            saveSettings()
                        end
                    end
                },
                {
                    label = "PDA idle shutdown: " .. (settings.pdaIdleEnabled and "On" or "Off"),
                    compactLabel = "PDA idle: " .. (settings.pdaIdleEnabled and "On" or "Off"),
                    description = "Automatically power off an unused PDA.",
                    action = function()
                        toggleSetting("pdaIdleEnabled")
                    end
                },
                {
                    label = "PDA idle time: " .. tostring(settings.pdaIdleShutdown) .. " seconds",
                    compactLabel = "Idle: " .. tostring(settings.pdaIdleShutdown) .. "s",
                    description = "Choose the PDA inactivity timeout. Reboot applies it.",
                    action = function()
                        local value = chooseValue("PDA idle shutdown", { 60, 300, 600, 900, 1800, 0 }, settings.pdaIdleShutdown)
                        if value ~= nil then
                            settings.pdaIdleShutdown = value
                            saveSettings()
                        end
                    end
                },
                {
                    label = "Core server: " .. tostring(coreConfig and coreConfig.coreAddress or "SRV-001"),
                    compactLabel = "Core: " .. tostring(coreConfig and coreConfig.coreAddress or "SRV-001"),
                    description = "Set the central directory and mailbox address. Reboot applies it.",
                    action = function()
                        ui.restoreNative()
                        ui.drawHeader("Core server address", getDevice(), VERSION)
                        print("")
                        local value = ui.readDefault("Address", coreConfig and coreConfig.coreAddress or "SRV-001")
                        value = string.upper(tostring(value or ""))
                        if value ~= "" and coreConfigModule then
                            coreConfig.coreAddress = value
                            local saved, reason = coreConfigModule.save(coreConfig)
                            print("")
                            print(saved and "Core address saved. Reboot to apply." or tostring(reason))
                            ui.pause()
                        end
                        ui.configure(settings)
                    end
                },
                {
                    label = "Reset console settings",
                    compactLabel = "Reset settings",
                    description = "Restore all UI settings to their defaults.",
                    action = function()
                        ui.drawHeader("Reset settings", getDevice(), VERSION)
                        print("")
                        if ui.askYesNo("Reset all console settings?") then
                            local saved, reason, defaults = settingsModule.reset()
                            if saved then
                                settings = defaults
                                context.settings = settings
                                ui.configure(settings)
                            else
                                print(tostring(reason))
                                ui.pause()
                            end
                        end
                    end
                },
                {
                    label = "Return to main menu",
                    compactLabel = "Back",
                    back = true
                }
            }

            local selected = menu.choose(ui, "Console settings", options, getDevice(), VERSION)
            if selected.back then
                return
            end
            selected.action()
        end
    end

    local tests = {
        {
            label = "Packet protocol tests",
            compactLabel = "Packet tests",
            path = "tests/communications/packet_test.lua"
        },
        {
            label = "Modem driver tests",
            compactLabel = "Modem tests",
            path = "tests/drivers/modem_test.lua"
        },
        {
            label = "Device configuration tests",
            compactLabel = "Device tests",
            path = "tests/system/device_config_test.lua"
        },
        {
            label = "Responsive layout tests",
            compactLabel = "Layout tests",
            path = "tests/ui/layout_test.lua"
        },
        {
            label = "Network frame tests",
            compactLabel = "Frame tests",
            path = "tests/communications/frame_test.lua"
        },
        {
            label = "Routing database tests",
            compactLabel = "Routing tests",
            path = "tests/communications/routing_test.lua"
        },
        {
            label = "Messaging store tests",
            compactLabel = "Messaging tests",
            path = "tests/communications/messaging_test.lua"
        },
        {
            label = "Network service tests",
            compactLabel = "Network tests",
            path = "tests/communications/network_test.lua"
        },
        {
            label = "End-to-end mesh tests",
            compactLabel = "Mesh tests",
            path = "tests/communications/mesh_test.lua"
        },
        {
            label = "Core directory and mailbox tests",
            compactLabel = "Core tests",
            path = "tests/communications/core_services_test.lua"
        },
        {
            label = "Contact book tests",
            compactLabel = "Contacts tests",
            path = "tests/communications/contacts_test.lua"
        },
        {
            label = "Display configuration tests",
            compactLabel = "Display tests",
            path = "tests/system/display_config_test.lua"
        },
        {
            label = "Rail platform controller tests",
            compactLabel = "Rail platform",
            path = "tests/trains/platform_controller_test.lua"
        },
        {
            label = "Rail station controller tests",
            compactLabel = "Rail station",
            path = "tests/trains/station_controller_test.lua"
        }
    }

    local function runTest(test)
        if not test then
            ui.drawHeader(
                "Test error",
                getDevice(),
                VERSION
            )

            print("")
            print("No test was selected.")
            ui.pause()
            return
        end

        ui.restoreNative()
        term.clear()
        term.setCursorPos(1, 1)

        print(test.label)
        print(string.rep("=", #test.label))
        print("")

        if not fs.exists(test.path) then
            print("Test file is not installed:")
            print(test.path)
            ui.pause()
            ui.configure(settings)
            return
        end

        local completed =
            os.run(
                getfenv(),
                test.path
            )

        if not completed then
            print("")
            print("The test program returned an error.")
        end

        ui.pause()
        ui.configure(settings)
    end

    local function builtInDiagnostics()
        local diagnosticContext = cloneContext()
        diagnosticContext.device = getDevice()
        local results = context.diagnostics.run(diagnosticContext)
        local options = {}

        for _, result in ipairs(results) do
            local marker = result.passed and "PASS" or "FAIL"
            local item = result
            table.insert(options, {
                label = marker .. "  " .. item.name,
                compactLabel = marker .. " " .. item.name,
                description = item.detail,
                action = function()
                    ui.drawHeader(item.name, getDevice(), VERSION)
                    print("")
                    print(item.passed and "PASS" or "FAIL")
                    print("")
                    print(item.detail)
                    ui.pause()
                end
            })
        end

        table.insert(options, {
            label = "Return to diagnostics",
            compactLabel = "Back",
            back = true
        })

        while true do
            local selected = menu.choose(ui, "Built-in diagnostics", options, getDevice(), VERSION)
            if selected.back then
                return
            end
            selected.action()
        end
    end

    local function diagnosticsMenu()
        while true do
            local options = {
                {
                    label = "Run built-in diagnostics",
                    compactLabel = "Built-in checks",
                    description = "Check storage, internet, core files, identity, modem, display and MCNet network.",
                    action = builtInDiagnostics
                }
            }

            for _, test in ipairs(tests) do
                local currentTest = test
                table.insert(options, {
                    label = "Run " .. currentTest.label,
                    compactLabel = currentTest.compactLabel,
                    description = currentTest.path,
                    action = function()
                        runTest(currentTest)
                    end
                })
            end

            table.insert(options, {
                label = "Return to main menu",
                compactLabel = "Back",
                back = true
            })

            local selected = menu.choose(ui, "Diagnostics and tests", options, getDevice(), VERSION)
            if selected.back then
                return
            end
            selected.action()
        end
    end

    local function systemInformation()
        local device = getDevice()
        local start = ui.drawHeader("System information", device, VERSION)
        local width, height = ui.getSize()
        local layout = ui.getLayout()

        ui.printField("Computer ID", os.getComputerID(), start)
        ui.printField("Computer label", os.getComputerLabel() or "None", start + 1)
        ui.printField("Console version", VERSION, start + 2)
        ui.printField("Protocol", PROTOCOL, start + 3)
        ui.printField("Screen", tostring(width) .. "x" .. tostring(height), start + 4)
        ui.printField("Layout", layout.mode, start + 5)
        ui.printField("Display", ui.getDisplayName(), start + 6)
        ui.printField("Free space", tostring(fs.getFreeSpace("/")) .. " bytes", start + 7)
        ui.printField("Modems", context.diagnostics.countModems(), start + 8)
        ui.printField("Settings", settingsModule.getPath(), start + 9)
        ui.printField("Device file", deviceModule.getPath(), start + 10)
        ui.pause()
    end

    local function showNetworkStatus()
        local device = getDevice()
        local status = context.network.getStatus()
        local start = ui.drawHeader("Network status", device, VERSION)

        ui.printField("Role", status.role, start)
        ui.printField("Channel", status.channel, start + 1)
        ui.printField(
            "Modem",
            status.modemReady and "READY" or "UNAVAILABLE",
            start + 2,
            status.modemReady
                and ui.getPalette().success
                or ui.getPalette().warning
        )

        ui.printField(
            "Tower",
            status.selectedTower or "NONE",
            start + 3
        )

        ui.printField(
            "Nearby towers",
            status.nearbyTowers,
            start + 4
        )

        ui.printField(
            "Neighbours",
            status.neighbours,
            start + 5
        )

        ui.printField(
            "Local endpoints",
            status.localEndpoints,
            start + 6
        )

        ui.printField(
            "Known destinations",
            status.knownDestinations,
            start + 7
        )

        ui.printField(
            "Pending packets",
            status.pending,
            start + 8
        )

        ui.pause()
    end

    local function showNearbyTowers()
        local towers =
            context.network.getNearbyTowers()

        local options = {}

        for _, tower in ipairs(towers) do
            local item = tower

            table.insert(options, {
                label =
                    item.address
                    .. "  "
                    .. tostring(item.distance or 0)
                    .. " blocks",
                compactLabel = item.address,
                description =
                    item.friendlyName
                    or item.systemName
                    or "Tower beacon",
                action = function()
                    local start =
                        ui.drawHeader(
                            "Nearby tower",
                            getDevice(),
                            VERSION
                        )

                    ui.printField(
                        "Address",
                        item.address,
                        start
                    )

                    ui.printField(
                        "Distance",
                        tostring(item.distance or 0)
                            .. " blocks",
                        start + 1
                    )

                    ui.printField(
                        "Region",
                        item.region or "UNKNOWN",
                        start + 2
                    )

                    ui.printField(
                        "Name",
                        item.friendlyName
                            or item.systemName
                            or "None",
                        start + 3
                    )

                    ui.pause()
                end
            })
        end

        table.insert(options, {
            label =
                #towers == 0
                and "No towers detected"
                or "Return",
            compactLabel =
                #towers == 0
                and "No towers"
                or "Back",
            disabled = #towers == 0,
            back = #towers > 0
        })

        if #towers == 0 then
            table.insert(options, {
                label = "Return",
                compactLabel = "Back",
                back = true
            })
        end

        while true do
            local selected =
                menu.choose(
                    ui,
                    "Nearby towers",
                    options,
                    getDevice(),
                    VERSION
                )

            if selected.back then
                return
            end

            if selected.action then
                selected.action()
            end
        end
    end

    local function showNetworkList(
        title,
        values,
        labelFunction,
        detailFunction
    )
        local options = {}

        for _, value in ipairs(values) do
            local item = value

            table.insert(options, {
                label = labelFunction(item),
                compactLabel =
                    item.address
                    or item.destination
                    or item.origin
                    or "Entry",
                description = detailFunction(item),
                action = function()
                    local start =
                        ui.drawHeader(
                            title,
                            getDevice(),
                            VERSION
                        )

                    ui.writeAt(
                        ui.getLayout().left,
                        start,
                        detailFunction(item),
                        ui.getPalette().foreground
                    )

                    ui.pause()
                end
            })
        end

        if #values == 0 then
            table.insert(options, {
                label = "No entries are currently known",
                compactLabel = "No entries",
                disabled = true
            })
        end

        table.insert(options, {
            label = "Return",
            compactLabel = "Back",
            back = true
        })

        while true do
            local selected =
                menu.choose(
                    ui,
                    title,
                    options,
                    getDevice(),
                    VERSION
                )

            if selected.back then
                return
            end

            if selected.action then
                selected.action()
            end
        end
    end

    local function showNeighbours()
        showNetworkList(
            "Tower neighbours",
            context.network.getNeighbours(),
            function(item)
                return item.address
                    .. "  "
                    .. tostring(item.distance or 0)
                    .. " blocks"
            end,
            function(item)
                return item.address
                    .. " | "
                    .. tostring(item.region or "UNKNOWN")
                    .. " | "
                    .. tostring(item.distance or 0)
                    .. " blocks"
            end
        )
    end

    local function showEndpoints()
        showNetworkList(
            "Registered endpoints",
            context.network.getLocalEndpoints(),
            function(item)
                return item.address
                    .. "  "
                    .. tostring(item.type or "ENDPOINT")
            end,
            function(item)
                return item.address
                    .. " | "
                    .. tostring(item.type or "ENDPOINT")
                    .. " | "
                    .. tostring(item.distance or 0)
                    .. " blocks"
            end
        )
    end

    local function showDestinations()
        showNetworkList(
            "Known destinations",
            context.network.getKnownDestinations(),
            function(item)
                return item.destination
                    .. " via "
                    .. tostring(item.owner or "UNKNOWN")
            end,
            function(item)
                return tostring(item.kind or "DESTINATION")
                    .. " "
                    .. item.destination
                    .. " is attached to "
                    .. tostring(item.owner or "UNKNOWN")
            end
        )
    end

    local function showMessageStore()
        local summary =
            context.messaging.getSummary()

        local start =
            ui.drawHeader(
                "Message storage",
                getDevice(),
                VERSION
            )

        ui.printField(
            "Inbox",
            summary.inbox,
            start
        )

        ui.printField(
            "Unread",
            summary.unread,
            start + 1
        )

        ui.printField(
            "Outbox",
            summary.outbox,
            start + 2
        )

        ui.printField(
            "File",
            context.messaging.getPath(),
            start + 3
        )

        ui.pause()
    end

    local function showCoreStatus()
        local start = ui.drawHeader("Core services", getDevice(), VERSION)
        if context.coreServer then
            local data = context.coreServer.getSnapshot()
            ui.printField("Role", "CORE SERVER", start)
            ui.printField("Devices online", tostring(data.totals.devicesOnline or 0) .. "/" .. tostring(data.totals.devices or 0), start + 1)
            ui.printField("Towers online", tostring(data.totals.towersOnline or 0) .. "/" .. tostring(data.totals.towers or 0), start + 2)
            ui.printField("Mailbox pending", data.mailbox.pending or 0, start + 3)
            ui.printField("Delivered", data.stats.mailboxDelivered or 0, start + 4)
        elseif context.coreClient then
            local status = context.coreClient.getStatus()
            ui.printField("Core address", status.coreAddress, start)
            ui.printField("Core status", status.online and "ONLINE" or "OFFLINE", start + 1)
            ui.printField("Directory devices", status.devices, start + 2)
            ui.printField("Known towers", status.towers, start + 3)
            ui.printField("Cache file", context.coreClient.getCachePath(), start + 4)
        else
            ui.writeAt(ui.getLayout().left, start, "Core services are unavailable.", ui.getPalette().warning)
        end
        ui.pause()
    end

    local function networkPage()
        while true do
            local status =
                context.network.getStatus()

            local options = {
                {
                    label = "Network status",
                    compactLabel = "Status",
                    description =
                        "Show modem, tower, routing and queue state.",
                    action = showNetworkStatus
                },
                {
                    label = "Nearby tower beacons",
                    compactLabel = "Nearby towers",
                    description =
                        "Show towers directly visible to this endpoint.",
                    disabled = status.role == "ROUTER",
                    action = showNearbyTowers
                },
                {
                    label = "Direct tower neighbours",
                    compactLabel = "Neighbours",
                    description =
                        "Show towers directly connected by wireless range.",
                    disabled = status.role ~= "ROUTER",
                    action = showNeighbours
                },
                {
                    label = "Registered local endpoints",
                    compactLabel = "Endpoints",
                    description =
                        "Show PDAs and other devices attached to this tower.",
                    disabled = status.role ~= "ROUTER",
                    action = showEndpoints
                },
                {
                    label = "Known routed destinations",
                    compactLabel = "Destinations",
                    description =
                        "Show destinations learned from tower link-state data.",
                    action = showDestinations
                },
                {
                    label = "Core directory and mailbox",
                    compactLabel = "Core services",
                    description = "Show SRV-001, directory and mailbox state.",
                    action = showCoreStatus
                },
                {
                    label = "Message storage",
                    compactLabel = "Messages",
                    description =
                        "Show inbox, unread and outbox counts.",
                    action = showMessageStore
                },
                {
                    label = "Return to main menu",
                    compactLabel = "Back",
                    back = true
                }
            }

            local selected =
                menu.choose(
                    ui,
                    "Network console",
                    options,
                    getDevice(),
                    VERSION
                )

            if selected.back then
                return
            end

            selected.action()
        end
    end

    local function launchRoleApplication()
        local device = getDevice()

        if not deviceModule.isConfigured(device) then
            ui.drawHeader("Device application", device, VERSION)
            print("")
            print("Configure this device first.")
            ui.pause()
            return
        end

        local childContext = cloneContext()
        childContext.fromConsole = true
        local path = appManager.getRolePath(device.type)
        local completed, reason = appManager.run(path, childContext)

        if not completed then
            ui.drawHeader("Application error", device, VERSION)
            print("")
            print(tostring(reason))
            ui.pause()
        end
    end

    while true do
        local device = getDevice()
        local options = {
            {
                label = "Install or update MCNet",
                compactLabel = "Install / update",
                description = "Download the standalone installer, manifest and every listed file.",
                action = installOrUpdate
            },
            {
                label = "Configure this device",
                compactLabel = "Configure device",
                description = "Set the MCNet address, system name, optional friendly name and role.",
                action = configureDevice
            },
            {
                label = "View device information",
                compactLabel = "Device information",
                description = "Show this computer's persistent MCNet identity.",
                action = deviceInformation
            },
            {
                label = "Launch device application",
                compactLabel = "Device application",
                description = "Open the role-specific home screen for this device.",
                disabled = context.fromRole == true,
                action = launchRoleApplication
            },
            {
                label = "Network console",
                compactLabel = "Network",
                description = "Inspect tower selection, routes, endpoints, queues and message storage.",
                action = networkPage
            },
            {
                label = "Diagnostics and tests",
                compactLabel = "Diagnostics",
                description = "Run built-in checks and the MCNet test suite.",
                action = diagnosticsMenu
            },
            {
                label = "Console settings",
                compactLabel = "Settings",
                description = "Change theme, logos, layout, monitor and boot behaviour.",
                action = settingsMenu
            },
            {
                label = "System information",
                compactLabel = "System info",
                description = "Show screen, storage, peripheral and version information.",
                action = systemInformation
            },
            {
                label = "Reboot device",
                compactLabel = "Reboot",
                description = "Restart CraftOS and run MCNet startup again.",
                action = function()
                    ui.restoreNative()
                    os.reboot()
                end
            },
            {
                label = context.fromRole == true and "Return to device application" or "Shut down device",
                compactLabel = context.fromRole == true and "Return" or "Shut down",
                description = context.fromRole == true
                    and "Return without exposing the CraftOS shell."
                    or "Power off this computer safely.",
                back = context.fromRole == true,
                action = context.fromRole == true and nil or function()
                    ui.drawHeader("Shut down", device, VERSION)
                    print("")
                    if ui.askYesNo("Shut down this device?") then
                        ui.restoreNative()
                        os.shutdown()
                    end
                end
            }
        }

        local selected = menu.choose(ui, "System console", options, device, VERSION)
        if selected.back then
            return
        end
        selected.action()
    end
end

return application