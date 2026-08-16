-- MCNet station operator application
-- Version 0.9.2
--
-- Foreground operator interface for a STATION computer.
--
-- Physical detector/locking-track control remains in the background:
--
--   services/trains/platform_controller.lua
--   services/trains/station_controller.lua
--
-- This application only reads the station-controller snapshot and issues
-- deliberate operator commands such as HOLD, RELEASE and fault reset.

local application = {}

function application.run(context)
    local ui =
        context.ui

    local menu =
        context.menu

    local deviceModule =
        context.deviceModule

    local appManager =
        context.appManager

    local stationConfigModule =
        context.stationConfigModule

    local railConfig =
        context.railConfig

    local railTimetable =
        context.railTimetable

    local stationController =
        context.stationController

    local function getDevice()
        return deviceModule.load(
            nil,
            context.version,
            context.protocol
        )
    end

    local function getStationConfig()
        if stationController
            and stationController.getStationConfig then

            return stationController.getStationConfig()
        end

        if stationConfigModule
            and stationConfigModule.load then

            return stationConfigModule.load()
        end

        return {}
    end

    local function getStationId()
        local config =
            getStationConfig()

        return config.stationId
            or config.mapId
            or "CENTRAL"
    end

    local function getStationName()
        local config =
            getStationConfig()

        if config.name
            and tostring(config.name)
                ~= "" then

            return tostring(
                config.name
            )
        end

        if railConfig
            and railConfig.getStationName then

            return railConfig.getStationName(
                getStationId()
            )
        end

        return getStationId()
    end

    local function placeholder(
        title,
        message
    )
        local start =
            ui.drawHeader(
                title,
                getDevice(),
                context.version
            )

        local layout =
            ui.getLayout()

        ui.writeAt(
            layout.left,
            start,
            message,
            ui.getPalette().warning
        )

        ui.pause()
    end

    local function showMessage(
        title,
        lines
    )
        ui.drawHeader(
            title,
            getDevice(),
            context.version
        )

        print("")

        if type(lines) == "table" then
            for _, value in ipairs(
                lines
            ) do
                print(
                    tostring(value)
                )
            end
        else
            print(
                tostring(
                    lines
                    or ""
                )
            )
        end

        ui.pause()
    end

    local function stateColour(state)
        state =
            string.upper(
                tostring(
                    state
                    or ""
                )
            )

        if state == "EMPTY" then
            return colors.lime
        elseif state == "BERTHED" then
            return colors.cyan
        elseif state == "APPROACHING"
            or state == "ENTERING" then

            return colors.yellow
        elseif state == "RELEASED"
            or state == "DEPARTING" then

            return colors.orange
        elseif state == "FAULT" then
            return colors.red
        end

        return colors.white
    end

    local function setTextColour(colour)
        if term.setTextColor then
            term.setTextColor(
                colour
                or colors.white
            )
        end
    end

    local function systemConsole()
        local child = {}

        for key, value in pairs(
            context
        ) do
            child[key] =
                value
        end

        child.fromRole =
            true

        local completed,
            reason =
            appManager.run(
                appManager.getSystemConsolePath(),
                child
            )

        if not completed then
            placeholder(
                "System console error",
                tostring(reason)
            )
        end
    end

    local function getPlatformIds()
        if not stationController
            or not stationController.getPlatformIds then

            return {}
        end

        return stationController.getPlatformIds()
            or {}
    end

    local function choosePlatform(
        title
    )
        local ids =
            getPlatformIds()

        local options = {}

        for _, id in ipairs(
            ids
        ) do
            local platformId =
                id

            local state =
                stationController.getPlatformState(
                    platformId
                )
                or {}

            options[
                #options + 1
            ] = {
                label =
                    tostring(platformId)
                    .. "  "
                    .. tostring(
                        state.state
                        or "UNKNOWN"
                    ),

                compactLabel =
                    tostring(
                        platformId
                    ),

                description =
                    state.fault
                    and tostring(
                        state.fault.message
                    )
                    or (
                        state.trainId
                        and (
                            "Train "
                            .. tostring(
                                state.trainId
                            )
                        )
                        or "No assigned train"
                    ),

                platformId =
                    platformId
            }
        end

        if #options == 0 then
            options[
                #options + 1
            ] = {
                label =
                    "No configured platforms",
                disabled = true
            }
        end

        options[
            #options + 1
        ] = {
            label = "Back",
            back = true
        }

        local selected =
            menu.choose(
                ui,
                title
                or "Select platform",
                options,
                getDevice(),
                context.version
            )

        if selected.back then
            return nil
        end

        return selected.platformId
    end

    local function printDetector(
        label,
        active
    )
        setTextColour(
            active
            and colors.lime
            or colors.lightGray
        )

        print(
            label
            .. ": "
            .. (
                active
                and "ON"
                or "OFF"
            )
        )

        setTextColour(
            colors.white
        )
    end

    local function livePlatformScreen(
        platformId
    )
        if not stationController then
            placeholder(
                "Platform control",
                "Station controller is not running."
            )

            return
        end

        while true do
            local state =
                stationController.getPlatformState(
                    platformId
                )

            if not state then
                placeholder(
                    "Platform control",
                    "Unknown platform "
                    .. tostring(
                        platformId
                    )
                )

                return
            end

            ui.restoreNative()

            term.clear()

            term.setCursorPos(
                1,
                1
            )

            print(
                "MCNet Rail | "
                .. getStationName()
            )

            print(
                "Platform "
                .. tostring(
                    platformId
                )
            )

            print(
                string.rep(
                    "-",
                    math.min(
                        30,
                        select(
                            1,
                            term.getSize()
                        )
                    )
                )
            )

            setTextColour(
                stateColour(
                    state.state
                )
            )

            print(
                "State: "
                .. tostring(
                    state.state
                    or "UNKNOWN"
                )
            )

            setTextColour(
                colors.white
            )

            print(
                "Occupied: "
                .. (
                    state.occupied
                    and "YES"
                    or "NO"
                )
            )

            print(
                "Train: "
                .. tostring(
                    state.trainId
                    or "-"
                )
            )

            print("")

            printDetector(
                "D1 approach",
                state.d1
            )

            printDetector(
                "D2 berth",
                state.d2
            )

            printDetector(
                "D3 exit",
                state.d3
            )

            print("")

            setTextColour(
                state.desiredRelease
                and colors.orange
                or colors.lime
            )

            print(
                "H1 command: "
                .. (
                    state.desiredRelease
                    and "RELEASE"
                    or "HOLD"
                )
            )

            setTextColour(
                colors.white
            )

            if state.fault then
                print("")

                setTextColour(
                    colors.red
                )

                print(
                    "FAULT: "
                    .. tostring(
                        state.fault.code
                        or "UNKNOWN"
                    )
                )

                print(
                    tostring(
                        state.fault.message
                        or ""
                    )
                )

                setTextColour(
                    colors.white
                )
            end

            print("")
            print(
                "Q = back"
            )

            local timer =
                os.startTimer(
                    0.5
                )

            while true do
                local event = {
                    os.pullEvent()
                }

                if event[1] == "timer"
                    and event[2] == timer then

                    break
                elseif event[1] == "char"
                    and string.lower(
                        event[2]
                    ) == "q" then

                    ui.restoreNative()

                    return
                end
            end
        end
    end

    local function showAllPlatforms()
        if not stationController then
            placeholder(
                "Platforms",
                "Station controller is not running."
            )

            return
        end

        while true do
            local snapshot =
                stationController.getSnapshot()

            ui.restoreNative()

            term.clear()

            term.setCursorPos(
                1,
                1
            )

            print(
                "MCNet Rail | "
                .. getStationName()
            )

            print(
                "Platform overview"
            )

            print("")

            local ids =
                getPlatformIds()

            if #ids == 0 then
                print(
                    "No configured platforms."
                )
            end

            for _, id in ipairs(
                ids
            ) do
                local item =
                    snapshot.platforms
                    and snapshot.platforms[id]
                    or nil

                local state =
                    item
                    and item.state
                    or {}

                setTextColour(
                    stateColour(
                        state.state
                    )
                )

                local right =
                    state.state
                    or "UNKNOWN"

                if state.trainId then
                    right =
                        right
                        .. " "
                        .. tostring(
                            state.trainId
                        )
                end

                print(
                    tostring(id)
                    .. "  "
                    .. tostring(right)
                )
            end

            setTextColour(
                colors.white
            )

            print("")

            if snapshot.emergencyHold then
                setTextColour(
                    colors.red
                )

                print(
                    "STATION EMERGENCY HOLD ACTIVE"
                )

                setTextColour(
                    colors.white
                )
            end

            print(
                "Q = back"
            )

            local timer =
                os.startTimer(
                    0.5
                )

            while true do
                local event = {
                    os.pullEvent()
                }

                if event[1] == "timer"
                    and event[2] == timer then

                    break
                elseif event[1] == "char"
                    and string.lower(
                        event[2]
                    ) == "q" then

                    ui.restoreNative()

                    return
                end
            end
        end
    end

    local function showArrivals()
        local stationId =
            getStationId()

        if not railTimetable
            or not railTimetable.getDepartures then

            placeholder(
                "Next departures",
                "Train timing service is not installed yet."
            )

            return
        end

        local departures =
            railTimetable.getDepartures(
                stationId,
                10
            )

        ui.drawHeader(
            "Next departures",
            getDevice(),
            context.version
        )

        print("")
        print(
            getStationName()
        )

        print("")

        if not departures
            or #departures == 0 then

            print(
                "No scheduled departures."
            )
        else
            for _, departure in ipairs(
                departures
            ) do
                local due =
                    departure.status
                    and departure.status
                        ~= "ON TIME"
                    and departure.status
                    or (
                        tostring(
                            departure.minutes
                            or "?"
                        )
                        .. "m"
                    )

                print(
                    tostring(
                        departure.platform
                        or "-"
                    )
                    .. "  "
                    .. tostring(
                        departure.destination
                        or "Unknown"
                    )
                    .. "  "
                    .. tostring(due)
                )
            end
        end

        print("")

        if railTimetable.isTestData
            and railTimetable.isTestData() then

            setTextColour(
                colors.yellow
            )

            print(
                "TEST TIMETABLE - timings not yet measured"
            )

            setTextColour(
                colors.white
            )
        end

        ui.pause()
    end

    local function platformStatusMenu()
        local platformId =
            choosePlatform(
                "Platform status"
            )

        if not platformId then
            return
        end

        livePlatformScreen(
            platformId
        )
    end

    local function releasePlatform()
        if not stationController then
            placeholder(
                "Release train",
                "Station controller is not running."
            )

            return
        end

        local platformId =
            choosePlatform(
                "Authorise departure"
            )

        if not platformId then
            return
        end

        local state =
            stationController.getPlatformState(
                platformId
            )
            or {}

        if state.state
            ~= "BERTHED" then

            showMessage(
                "Departure refused",
                {
                    "Platform "
                        .. tostring(
                            platformId
                        )
                        .. " is "
                        .. tostring(
                            state.state
                            or "UNKNOWN"
                        )
                        .. ".",

                    "",

                    "A train may only be released from BERTHED state."
                }
            )

            return
        end

        local options = {
            {
                label =
                    "AUTHORISE "
                    .. tostring(
                        platformId
                    )
                    .. " DEPARTURE",
                compactLabel =
                    "Authorise",
                description =
                    "Power H1 and allow the berthed train to leave.",
                confirm = true
            },
            {
                label = "Cancel",
                back = true
            }
        }

        local selected =
            menu.choose(
                ui,
                "Confirm train release",
                options,
                getDevice(),
                context.version
            )

        if selected.back then
            return
        end

        local ok, reason =
            stationController.requestDeparture(
                platformId
            )

        if ok then
            showMessage(
                "Departure authorised",
                {
                    "Platform "
                        .. tostring(
                            platformId
                        )
                        .. " H1 is released.",

                    "",

                    "H1 will return to HOLD when D3 detects the departing train."
                }
            )
        else
            showMessage(
                "Departure refused",
                tostring(
                    reason
                    or "Unknown reason"
                )
            )
        end
    end

    local function holdPlatform()
        if not stationController then
            return
        end

        local platformId =
            choosePlatform(
                "Hold platform"
            )

        if not platformId then
            return
        end

        local ok, reason =
            stationController.holdPlatform(
                platformId
            )

        if ok then
            showMessage(
                "Platform held",
                "Platform "
                .. tostring(
                    platformId
                )
                .. " H1 is now HOLD."
            )
        else
            showMessage(
                "Hold failed",
                tostring(
                    reason
                    or "Unknown reason"
                )
            )
        end
    end

    local function clearPlatformFault()
        if not stationController then
            return
        end

        local platformId =
            choosePlatform(
                "Clear platform fault"
            )

        if not platformId then
            return
        end

        local state =
            stationController.getPlatformState(
                platformId
            )
            or {}

        if state.state ~= "FAULT" then
            showMessage(
                "Platform fault",
                "Platform "
                .. tostring(
                    platformId
                )
                .. " is not faulted."
            )

            return
        end

        local ok, reason =
            stationController.clearPlatformFault(
                platformId
            )

        if ok then
            showMessage(
                "Fault cleared",
                "Platform "
                .. tostring(
                    platformId
                )
                .. " returned to EMPTY."
            )
        else
            showMessage(
                "Fault not cleared",
                tostring(
                    reason
                    or "Unknown reason"
                )
            )
        end
    end

    local function forceResync()
        if not stationController then
            return
        end

        local platformId =
            choosePlatform(
                "Maintenance resync"
            )

        if not platformId then
            return
        end

        local states = {
            {
                label =
                    "Reset as EMPTY",
                compactLabel =
                    "EMPTY",
                description =
                    "Use only after physically confirming the entire platform is clear.",
                state =
                    "EMPTY"
            },
            {
                label =
                    "Reset as BERTHED",
                compactLabel =
                    "BERTHED",
                description =
                    "Use only after physically confirming a complete train is safely berthed on H1.",
                state =
                    "BERTHED"
            },
            {
                label = "Cancel",
                back = true
            }
        }

        local selected =
            menu.choose(
                ui,
                "Physical inspection required",
                states,
                getDevice(),
                context.version
            )

        if selected.back then
            return
        end

        local confirmations = {
            {
                label =
                    "I HAVE PHYSICALLY CHECKED "
                    .. tostring(
                        platformId
                    ),
                compactLabel =
                    "Confirm",
                state =
                    selected.state
            },
            {
                label = "Cancel",
                back = true
            }
        }

        local confirmed =
            menu.choose(
                ui,
                "Confirm maintenance resync",
                confirmations,
                getDevice(),
                context.version
            )

        if confirmed.back then
            return
        end

        local ok, reason =
            stationController.forceResetPlatform(
                platformId,
                nil,
                confirmed.state
            )

        if ok then
            showMessage(
                "Platform resynchronised",
                "MCNet now treats "
                .. tostring(
                    platformId
                )
                .. " as "
                .. tostring(
                    confirmed.state
                )
                .. "."
            )
        else
            showMessage(
                "Resync failed",
                tostring(
                    reason
                    or "Unknown reason"
                )
            )
        end
    end

    local function emergencyHoldMenu()
        if not stationController then
            return
        end

        local active =
            stationController.isEmergencyHold()

        local options = {}

        if active then
            options[
                #options + 1
            ] = {
                label =
                    "Release station emergency hold",
                compactLabel =
                    "Release hold",
                description =
                    "Return H1 outputs to their platform-controller commands.",
                action =
                    "release"
            }
        else
            options[
                #options + 1
            ] = {
                label =
                    "ACTIVATE STATION EMERGENCY HOLD",
                compactLabel =
                    "Emergency hold",
                description =
                    "Immediately force every platform H1 to HOLD.",
                action =
                    "hold"
            }
        end

        options[
            #options + 1
        ] = {
            label = "Cancel",
            back = true
        }

        local selected =
            menu.choose(
                ui,
                "Station emergency hold",
                options,
                getDevice(),
                context.version
            )

        if selected.back then
            return
        end

        if selected.action
            == "hold" then

            stationController.setEmergencyHold(
                true,
                "Activated from station operator console"
            )

            showMessage(
                "Emergency hold",
                {
                    "ALL PLATFORM H1 OUTPUTS ARE HOLD.",
                    "",
                    "No train can be newly released until the emergency hold is removed."
                }
            )
        else
            stationController.setEmergencyHold(
                false,
                "Released from station operator console"
            )

            showMessage(
                "Emergency hold released",
                "Normal platform release control restored."
            )
        end
    end

    local function manualControl()
        if not stationController then
            placeholder(
                "Railway control",
                "Station controller is not running."
            )

            return
        end

        while true do
            local emergency =
                stationController.isEmergencyHold()

            local options = {
                {
                    label =
                        "Platform live status",
                    compactLabel =
                        "Status",
                    description =
                        "Inspect D1, D2, D3, H1 and the platform state machine.",
                    action =
                        platformStatusMenu
                },
                {
                    label =
                        "Authorise departure",
                    compactLabel =
                        "Release",
                    description =
                        "Release H1 for a train in BERTHED state.",
                    action =
                        releasePlatform
                },
                {
                    label =
                        "Hold platform",
                    compactLabel =
                        "Hold",
                    description =
                        "Cancel a pending release and return H1 to HOLD.",
                    action =
                        holdPlatform
                },
                {
                    label =
                        emergency
                        and "Emergency hold: ACTIVE"
                        or "Emergency hold: OFF",
                    compactLabel =
                        "Emergency",
                    description =
                        "Force every platform locking track to HOLD.",
                    action =
                        emergencyHoldMenu
                },
                {
                    label =
                        "Clear platform fault",
                    compactLabel =
                        "Clear fault",
                    description =
                        "Only succeeds when D1, D2 and D3 are all clear.",
                    action =
                        clearPlatformFault
                },
                {
                    label =
                        "Maintenance resynchronisation",
                    compactLabel =
                        "Resync",
                    description =
                        "Dangerous maintenance operation after physical inspection.",
                    action =
                        forceResync
                },
                {
                    label = "Back",
                    back = true
                }
            }

            local selected =
                menu.choose(
                    ui,
                    "Manual railway control",
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

    local function stationStatus()
        local device =
            getDevice()

        local stationConfig =
            getStationConfig()

        local snapshot =
            stationController
            and stationController.getSnapshot()
            or nil

        local start =
            ui.drawHeader(
                "Station status",
                device,
                context.version
            )

        ui.printField(
            "Station",
            getStationName(),
            start
        )

        ui.printField(
            "Station ID",
            tostring(
                stationConfig.stationId
                or "-"
            ),
            start + 1
        )

        ui.printField(
            "Address",
            device.address,
            start + 2
        )

        ui.printField(
            "Region",
            device.region,
            start + 3
        )

        ui.printField(
            "Device status",
            device.status,
            start + 4
        )

        ui.printField(
            "Rail controller",
            stationController
            and "RUNNING"
            or "NOT AVAILABLE",
            start + 5
        )

        if snapshot then
            ui.printField(
                "Emergency hold",
                snapshot.emergencyHold
                and "ACTIVE"
                or "OFF",
                start + 6
            )

            local platformCount = 0

            for _ in pairs(
                snapshot.platforms
                or {}
            ) do
                platformCount =
                    platformCount + 1
            end

            ui.printField(
                "Platforms",
                tostring(
                    platformCount
                ),
                start + 7
            )
        end

        ui.pause()
    end

    local function destinationSelector()
        placeholder(
            "Destinations",
            "Passenger route selection will be connected after route and junction control are installed."
        )
    end

    while true do
        local device =
            getDevice()

        local emergency =
            stationController
            and stationController.isEmergencyHold()
            or false

        local options = {
            {
                label =
                    "Next train departures",
                compactLabel =
                    "Departures",
                description =
                    "Show the current test timetable for this station.",
                action =
                    showArrivals
            },
            {
                label =
                    "Platform overview",
                compactLabel =
                    "Platforms",
                description =
                    "Live state of every locally controlled platform.",
                action =
                    showAllPlatforms
            },
            {
                label =
                    emergency
                    and "Manual railway control  [EMERGENCY HOLD]"
                    or "Manual railway control",
                compactLabel =
                    "Rail control",
                description =
                    "Platform hold/release, detector diagnostics and fault recovery.",
                action =
                    manualControl
            },
            {
                label =
                    "Select destination",
                compactLabel =
                    "Destinations",
                description =
                    "Passenger route and destination information.",
                action =
                    destinationSelector
            },
            {
                label =
                    "Station status",
                compactLabel =
                    "Status",
                description =
                    "Station identity and local railway-controller status.",
                action =
                    stationStatus
            },
            {
                label =
                    "Open system console",
                compactLabel =
                    "System console",
                description =
                    "Open installation, settings and diagnostics.",
                action =
                    systemConsole
            },
            {
                label =
                    "Exit to CraftOS",
                compactLabel =
                    "Exit",
                exit = true
            }
        }

        local selected =
            menu.choose(
                ui,
                getStationName(),
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