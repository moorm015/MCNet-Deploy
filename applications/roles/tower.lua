-- MCNet tower router application
-- Version 0.8.0

local application = {}

function application.run(context)
    local ui = context.ui
    local menu = context.menu
    local deviceModule = context.deviceModule
    local appManager = context.appManager
    local network = context.network

    local function getDevice()
        return deviceModule.load(
            nil,
            context.version,
            context.protocol
        )
    end

    local function showNotice(title, message)
        local start =
            ui.drawHeader(
                title,
                getDevice(),
                context.version
            )

        ui.writeAt(
            ui.getLayout().left,
            start,
            tostring(message),
            ui.getPalette().foreground
        )

        ui.pause()
    end

    local function systemConsole()
        local child = {}

        for key, value in pairs(context) do
            child[key] = value
        end

        child.fromRole = true

        local completed, reason =
            appManager.run(
                appManager.getSystemConsolePath(),
                child
            )

        if not completed then
            showNotice(
                "System console error",
                tostring(reason)
            )
        end
    end

    local function relayStatus()
        local status =
            network.getStatus()

        local start =
            ui.drawHeader(
                "Relay status",
                getDevice(),
                context.version
            )

        ui.printField(
            "Router",
            status.address,
            start
        )

        ui.printField(
            "Channel",
            status.channel,
            start + 1
        )

        ui.printField(
            "Modem",
            status.modemReady
                and "READY"
                or "UNAVAILABLE",
            start + 2
        )

        ui.printField(
            "Neighbours",
            status.neighbours,
            start + 3
        )

        ui.printField(
            "Endpoints",
            status.localEndpoints,
            start + 4
        )

        ui.printField(
            "Destinations",
            status.knownDestinations,
            start + 5
        )

        ui.printField(
            "Forwarded",
            status.counters.framesForwarded,
            start + 6
        )

        ui.printField(
            "Dropped",
            status.counters.framesDropped,
            start + 7
        )

        ui.pause()
    end

    local function listEntries(
        title,
        entries,
        labelFunction,
        detailFunction
    )
        local options = {}

        for _, entry in ipairs(entries) do
            local item = entry

            table.insert(options, {
                label = labelFunction(item),
                compactLabel =
                    item.address
                    or item.destination
                    or item.origin
                    or "Entry",
                description = detailFunction(item),
                action = function()
                    showNotice(
                        title,
                        detailFunction(item)
                    )
                end
            })
        end

        if #entries == 0 then
            table.insert(options, {
                label = "No entries are currently known",
                compactLabel = "No entries",
                disabled = true
            })
        end

        table.insert(options, {
            label = "Return to tower",
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
                    context.version
                )

            if selected.back then
                return
            end

            selected.action()
        end
    end

    local function neighbours()
        listEntries(
            "Tower neighbours",
            network.getNeighbours(),
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

    local function endpoints()
        listEntries(
            "Attached endpoints",
            network.getLocalEndpoints(),
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

    local function topology()
        listEntries(
            "Link-state database",
            network.getTopology(),
            function(item)
                return item.origin
                    .. "  seq "
                    .. tostring(item.sequence or 0)
            end,
            function(item)
                return item.origin
                    .. " advertises "
                    .. tostring(#(item.neighbours or {}))
                    .. " neighbours and "
                    .. tostring(#(item.endpoints or {}))
                    .. " endpoints"
            end
        )
    end

    local function destinations()
        listEntries(
            "Known destinations",
            network.getKnownDestinations(),
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

    while true do
        local device = getDevice()

        local options = {
            {
                label = "Relay status",
                compactLabel = "Relay status",
                description =
                    "Show modem, routing and traffic counters.",
                action = relayStatus
            },
            {
                label = "Direct tower neighbours",
                compactLabel = "Neighbours",
                description =
                    "Show towers currently inside wireless range.",
                action = neighbours
            },
            {
                label = "Attached endpoints",
                compactLabel = "Endpoints",
                description =
                    "Show PDAs and other devices registered here.",
                action = endpoints
            },
            {
                label = "Link-state database",
                compactLabel = "Topology",
                description =
                    "Show route advertisements learned from the mesh.",
                action = topology
            },
            {
                label = "Known destinations",
                compactLabel = "Destinations",
                description =
                    "Show towers and endpoints that can be routed.",
                action = destinations
            },
            {
                label = "Open system console",
                compactLabel = "System console",
                description =
                    "Open installation, settings and diagnostics.",
                action = systemConsole
            },
            {
                label = "Exit to CraftOS",
                compactLabel = "Exit",
                exit = true
            }
        }

        local selected =
            menu.choose(
                ui,
                deviceModule.getDisplayName(device),
                options,
                device,
                context.version
            )

        if selected.exit then
            return
        end

        selected.action()
    end
end

return application
