-- MCNet station-level railway controller
-- Version 0.9.2
--
-- Owns the physical redstone/bundled-cable I/O for ONE railway station.
--
-- This is the layer above platform_controller.lua:
--
--   station_controller.lua
--       reads all station detector cables ONCE
--       updates P1 / P2 / P3 / ...
--       asks each platform whether H1 should be released
--       combines every requested release colour
--       writes ONE bundled output value
--
-- That means several platforms can safely share one bundled output cable
-- without their ComputerCraft outputs overwriting each other.
--
-- Standard Grand Central test wiring supplied by the default configuration:
--
-- INPUT A ("left") - first five platform roads
--
--   P1 D1 white       P1 D2 orange      P1 D3 magenta
--   P2 D1 lightBlue   P2 D2 yellow      P2 D3 lime
--   P3 D1 pink        P3 D2 gray        P3 D3 lightGray
--   P4 D1 cyan        P4 D2 purple      P4 D3 blue
--   P5 D1 brown       P5 D2 green       P5 D3 red
--
-- INPUT B ("back") - sixth platform road
--
--   P6 D1 white       P6 D2 orange      P6 D3 magenta
--
-- OUTPUT ("right")
--
--   P1 H1 white
--   P2 H1 orange
--   P3 H1 magenta
--   P4 H1 lightBlue
--   P5 H1 yellow
--   P6 H1 lime
--
-- All of those sides/colours are configurable in:
--
--   .mcnet/station_io.lua
--
-- FAIL SAFE:
--
--   - Construction immediately writes bundled output 0.
--   - A platform fault requests HOLD.
--   - Station emergency hold forces every H1 to HOLD.
--   - Unknown/unwired platforms cannot be released.
--   - stop() writes bundled output 0.
--
-- This controller does not yet decide routes or timetables. It only enforces
-- local station/platform state and exposes safe manual/automatic commands to
-- the station application and future Rail Control service.

local module = {}

local IO_PATH =
    ".mcnet/station_io.lua"

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local result = {}
    seen[value] = result

    for key, item in pairs(value) do
        result[deepCopy(key, seen)] =
            deepCopy(item, seen)
    end

    return result
end

local function cleanIdentifier(value)
    value =
        string.upper(
            tostring(value or "")
        )

    value =
        string.gsub(
            value,
            "%s+",
            "-"
        )

    value =
        string.gsub(
            value,
            "[^A-Z0-9%-_]",
            ""
        )

    return value
end

local function cleanSide(value, fallback)
    value =
        string.lower(
            tostring(
                value
                or fallback
                or ""
            )
        )

    local valid = {
        left = true,
        right = true,
        top = true,
        bottom = true,
        front = true,
        back = true
    }

    if valid[value] then
        return value
    end

    return fallback
        or "left"
end

local function nowClock()
    if os.clock then
        return os.clock()
    end

    return 0
end

local function bundledHas(value, colour)
    value =
        tonumber(value)
        or 0

    colour =
        tonumber(colour)
        or 0

    if colors
        and colors.test then

        return colors.test(
            value,
            colour
        )
    end

    if bit
        and bit.band then

        return bit.band(
            value,
            colour
        ) ~= 0
    end

    return false
end

local function bundledAdd(value, colour)
    value =
        tonumber(value)
        or 0

    colour =
        tonumber(colour)
        or 0

    if colors
        and colors.combine then

        return colors.combine(
            value,
            colour
        )
    end

    if bit
        and bit.bor then

        return bit.bor(
            value,
            colour
        )
    end

    return value + colour
end

local function normaliseColour(
    value,
    fallback
)
    value =
        tonumber(value)

    if not value
        or value <= 0 then

        return fallback
    end

    return value
end

function module.defaultIOConfig()
    return {
        format = 1,

        pollInterval = 0.10,

        outputSide = "right",

        platforms = {
            P1 = {
                inputSide = "left",
                d1 = colors.white,
                d2 = colors.orange,
                d3 = colors.magenta,
                h1 = colors.white
            },

            P2 = {
                inputSide = "left",
                d1 = colors.lightBlue,
                d2 = colors.yellow,
                d3 = colors.lime,
                h1 = colors.orange
            },

            P3 = {
                inputSide = "left",
                d1 = colors.pink,
                d2 = colors.gray,
                d3 = colors.lightGray,
                h1 = colors.magenta
            },

            P4 = {
                inputSide = "left",
                d1 = colors.cyan,
                d2 = colors.purple,
                d3 = colors.blue,
                h1 = colors.lightBlue
            },

            P5 = {
                inputSide = "left",
                d1 = colors.brown,
                d2 = colors.green,
                d3 = colors.red,
                h1 = colors.yellow
            },

            P6 = {
                inputSide = "back",
                d1 = colors.white,
                d2 = colors.orange,
                d3 = colors.magenta,
                h1 = colors.lime
            }
        }
    }
end

function module.normaliseIOConfig(value)
    local default =
        module.defaultIOConfig()

    value =
        type(value) == "table"
        and value
        or {}

    local result = {
        format =
            math.max(
                1,
                math.floor(
                    tonumber(
                        value.format
                    )
                    or default.format
                )
            ),

        pollInterval =
            math.max(
                0.05,
                math.min(
                    2,
                    tonumber(
                        value.pollInterval
                    )
                    or default.pollInterval
                )
            ),

        outputSide =
            cleanSide(
                value.outputSide,
                default.outputSide
            ),

        platforms = {}
    }

    local source =
        type(value.platforms)
            == "table"
        and value.platforms
        or default.platforms

    for platformId, wiring in pairs(
        source
    ) do
        local id =
            cleanIdentifier(
                platformId
            )

        wiring =
            type(wiring) == "table"
            and wiring
            or {}

        local fallback =
            default.platforms[id]
            or {
                inputSide = "left",
                d1 = colors.white,
                d2 = colors.orange,
                d3 = colors.magenta,
                h1 = colors.white
            }

        if id ~= "" then
            result.platforms[id] = {
                inputSide =
                    cleanSide(
                        wiring.inputSide,
                        fallback.inputSide
                    ),

                d1 =
                    normaliseColour(
                        wiring.d1,
                        fallback.d1
                    ),

                d2 =
                    normaliseColour(
                        wiring.d2,
                        fallback.d2
                    ),

                d3 =
                    normaliseColour(
                        wiring.d3,
                        fallback.d3
                    ),

                h1 =
                    normaliseColour(
                        wiring.h1,
                        fallback.h1
                    )
            }
        end
    end

    return result
end

function module.loadIOConfig(path)
    path =
        path
        or IO_PATH

    if not fs.exists(path) then
        return module.defaultIOConfig()
    end

    local loaded, value =
        pcall(
            dofile,
            path
        )

    if not loaded
        or type(value) ~= "table" then

        return module.defaultIOConfig()
    end

    return module.normaliseIOConfig(
        value
    )
end

function module.saveIOConfig(
    value,
    path
)
    path =
        path
        or IO_PATH

    value =
        module.normaliseIOConfig(
            value
        )

    local directory =
        fs.getDir(path)

    if directory ~= ""
        and not fs.exists(directory) then

        fs.makeDir(directory)
    end

    local temporary =
        path .. ".tmp"

    if fs.exists(temporary) then
        fs.delete(temporary)
    end

    local file =
        fs.open(
            temporary,
            "w"
        )

    if not file then
        return false,
            "Could not write station I/O configuration"
    end

    file.write("return ")

    file.write(
        textutils.serialize(
            value
        )
    )

    file.write("\n")
    file.close()

    local checked, saved =
        pcall(
            dofile,
            temporary
        )

    if not checked
        or type(saved) ~= "table" then

        fs.delete(temporary)

        return false,
            "Could not verify station I/O configuration"
    end

    if fs.exists(path) then
        fs.delete(path)
    end

    fs.move(
        temporary,
        path
    )

    return true
end

local function loadPlatformModule(
    supplied
)
    if supplied
        and type(supplied) == "table"
        and type(supplied.new) == "function" then

        return supplied
    end

    local path =
        "services/trains/platform_controller.lua"

    if not fs.exists(path) then
        return nil,
            "Missing "
            .. path
    end

    local loaded, value =
        pcall(
            dofile,
            path
        )

    if not loaded
        or type(value) ~= "table"
        or type(value.new) ~= "function" then

        return nil,
            "Could not load "
            .. path
    end

    return value
end

local function loadStationConfig(
    supplied
)
    if supplied
        and type(supplied) == "table"
        and supplied.stationId then

        return supplied
    end

    local path =
        "services/trains/station_config.lua"

    if not fs.exists(path) then
        return nil,
            "Missing "
            .. path
    end

    local loaded, configModule =
        pcall(
            dofile,
            path
        )

    if not loaded
        or type(configModule) ~= "table"
        or type(configModule.load) ~= "function" then

        return nil,
            "Could not load "
            .. path
    end

    return configModule.load()
end

function module.new(options)
    options =
        type(options) == "table"
        and options
        or {}

    local platformModule,
        platformReason =
        loadPlatformModule(
            options.platformControllerModule
        )

    if not platformModule then
        return nil,
            platformReason
    end

    local stationConfig,
        stationReason =
        loadStationConfig(
            options.stationConfig
        )

    if not stationConfig then
        return nil,
            stationReason
    end

    local ioConfig =
        module.normaliseIOConfig(
            options.ioConfig
            or module.loadIOConfig(
                options.ioPath
            )
        )

    local controller = {}

    local platforms = {}

    local platformOrder = {}

    local running = false

    local emergencyHold = false

    local stationFault = nil

    local eventQueue = {}

    local lastSnapshot = nil

    local lastOutput = nil

    local function queueEvent(
        eventType,
        details
    )
        local event = {
            type =
                tostring(
                    eventType
                    or "UNKNOWN"
                ),

            stationId =
                stationConfig.stationId,

            mapId =
                stationConfig.mapId,

            time =
                nowClock()
        }

        if type(details)
            == "table" then

            for key, value in pairs(
                details
            ) do
                event[key] =
                    deepCopy(value)
            end
        end

        eventQueue[#eventQueue + 1] =
            event
    end

    local function buildPlatforms()
        for _, platformConfig in ipairs(
            stationConfig.platforms
            or {}
        ) do
            if platformConfig.enabled
                ~= false then

                local id =
                    cleanIdentifier(
                        platformConfig.id
                    )

                local wiring =
                    ioConfig.platforms[
                        id
                    ]

                if id ~= ""
                    and wiring then

                    local instance =
                        platformModule.new({
                            id = id,

                            name =
                                platformConfig.name
                                or id,

                            approachTimeout =
                                tonumber(
                                    platformConfig.approachTimeout
                                )
                                or 0,

                            departureTimeout =
                                tonumber(
                                    platformConfig.departureTimeout
                                )
                                or 0
                        })

                    if instance then
                        platforms[id] = {
                            controller =
                                instance,

                            config =
                                deepCopy(
                                    platformConfig
                                ),

                            wiring =
                                deepCopy(
                                    wiring
                                )
                        }

                        platformOrder[
                            #platformOrder + 1
                        ] = id
                    end
                end
            end
        end

        table.sort(
            platformOrder
        )
    end

    local function writeFailSafe()
        redstone.setBundledOutput(
            ioConfig.outputSide,
            0
        )

        lastOutput = 0
    end

    local function getInputSides()
        local seen = {}
        local result = {}

        for _, id in ipairs(
            platformOrder
        ) do
            local wiring =
                platforms[id].wiring

            local side =
                wiring.inputSide

            if not seen[side] then
                seen[side] =
                    true

                result[
                    #result + 1
                ] = side
            end
        end

        return result
    end

    local function readInputCache()
        local result = {}

        for _, side in ipairs(
            getInputSides()
        ) do
            result[side] =
                redstone.getBundledInput(
                    side
                )
        end

        return result
    end

    local function collectPlatformInputs(
        inputCache,
        wiring
    )
        local bundled =
            inputCache[
                wiring.inputSide
            ]
            or 0

        return {
            d1 =
                bundledHas(
                    bundled,
                    wiring.d1
                ),

            d2 =
                bundledHas(
                    bundled,
                    wiring.d2
                ),

            d3 =
                bundledHas(
                    bundled,
                    wiring.d3
                )
        }
    end

    local function calculateOutput()
        if emergencyHold
            or stationFault then

            return 0
        end

        local output = 0

        for _, id in ipairs(
            platformOrder
        ) do
            local item =
                platforms[id]

            if item.controller.wantsRelease()
                and not item.controller.isFaulted() then

                output =
                    bundledAdd(
                        output,
                        item.wiring.h1
                    )
            end
        end

        return output
    end

    local function writeCombinedOutput()
        local output =
            calculateOutput()

        if lastOutput
            ~= output then

            redstone.setBundledOutput(
                ioConfig.outputSide,
                output
            )

            lastOutput =
                output
        end

        return output
    end

    local function updatePlatforms()
        local inputCache =
            readInputCache()

        local cycleEvents = {}

        for _, id in ipairs(
            platformOrder
        ) do
            local item =
                platforms[id]

            local inputs =
                collectPlatformInputs(
                    inputCache,
                    item.wiring
                )

            local state,
                platformEvents =
                item.controller.update(
                    inputs
                )

            for _, event in ipairs(
                platformEvents
                or {}
            ) do
                event.stationId =
                    stationConfig.stationId

                event.mapId =
                    stationConfig.mapId

                cycleEvents[
                    #cycleEvents + 1
                ] =
                    deepCopy(event)

                eventQueue[
                    #eventQueue + 1
                ] =
                    deepCopy(event)
            end
        end

        return cycleEvents
    end

    local function makeSnapshot()
        local snapshot = {
            stationId =
                stationConfig.stationId,

            mapId =
                stationConfig.mapId,

            name =
                stationConfig.name,

            status =
                stationConfig.status,

            emergencyHold =
                emergencyHold,

            stationFault =
                deepCopy(
                    stationFault
                ),

            outputSide =
                ioConfig.outputSide,

            outputValue =
                lastOutput
                or 0,

            time =
                nowClock(),

            platforms = {}
        }

        for _, id in ipairs(
            platformOrder
        ) do
            local item =
                platforms[id]

            snapshot.platforms[id] = {
                state =
                    item.controller.getState(),

                wiring =
                    deepCopy(
                        item.wiring
                    ),

                config =
                    deepCopy(
                        item.config
                    )
            }
        end

        return snapshot
    end

    -- Put the whole station into its safest physical state before doing
    -- anything else.
    writeFailSafe()

    buildPlatforms()

    lastSnapshot =
        makeSnapshot()

    function controller.update()
        local cycleEvents =
            updatePlatforms()

        writeCombinedOutput()

        lastSnapshot =
            makeSnapshot()

        return deepCopy(
            lastSnapshot
        ),
            deepCopy(
                cycleEvents
            )
    end

    function controller.getSnapshot()
        if not lastSnapshot then
            lastSnapshot =
                makeSnapshot()
        end

        return deepCopy(
            lastSnapshot
        )
    end

    function controller.getStationConfig()
        return deepCopy(
            stationConfig
        )
    end

    function controller.getIOConfig()
        return deepCopy(
            ioConfig
        )
    end

    function controller.getPlatformIds()
        return deepCopy(
            platformOrder
        )
    end

    function controller.getPlatformState(
        platformId
    )
        platformId =
            cleanIdentifier(
                platformId
            )

        local item =
            platforms[
                platformId
            ]

        if not item then
            return nil
        end

        return item.controller.getState()
    end

    function controller.getEvents(
        clear
    )
        local result =
            deepCopy(
                eventQueue
            )

        if clear ~= false then
            eventQueue = {}
        end

        return result
    end

    function controller.assignTrain(
        platformId,
        trainId
    )
        platformId =
            cleanIdentifier(
                platformId
            )

        local item =
            platforms[
                platformId
            ]

        if not item then
            return false,
                "Unknown or unwired platform "
                .. tostring(
                    platformId
                )
        end

        return item.controller.assignTrain(
            trainId
        )
    end

    function controller.requestDeparture(
        platformId,
        trainId
    )
        if emergencyHold then
            return false,
                "Station emergency hold is active"
        end

        if stationFault then
            return false,
                "Station is faulted"
        end

        platformId =
            cleanIdentifier(
                platformId
            )

        local item =
            platforms[
                platformId
            ]

        if not item then
            return false,
                "Unknown or unwired platform "
                .. tostring(
                    platformId
                )
        end

        local released, reason =
            item.controller.requestDeparture(
                trainId
            )

        if released then
            writeCombinedOutput()

            queueEvent(
                "DEPARTURE_AUTHORISED",
                {
                    platformId =
                        platformId,

                    trainId =
                        trainId
                }
            )
        end

        return released,
            reason
    end

    function controller.cancelDeparture(
        platformId
    )
        platformId =
            cleanIdentifier(
                platformId
            )

        local item =
            platforms[
                platformId
            ]

        if not item then
            return false,
                "Unknown or unwired platform "
                .. tostring(
                    platformId
                )
        end

        local ok, reason =
            item.controller.cancelDeparture()

        writeCombinedOutput()

        return ok,
            reason
    end

    function controller.holdPlatform(
        platformId
    )
        platformId =
            cleanIdentifier(
                platformId
            )

        local item =
            platforms[
                platformId
            ]

        if not item then
            return false,
                "Unknown or unwired platform "
                .. tostring(
                    platformId
                )
        end

        item.controller.hold()

        writeCombinedOutput()

        queueEvent(
            "PLATFORM_HELD",
            {
                platformId =
                    platformId
            }
        )

        return true
    end

    function controller.setEmergencyHold(
        enabled,
        reason
    )
        emergencyHold =
            enabled
            == true

        if emergencyHold then
            writeFailSafe()

            queueEvent(
                "EMERGENCY_HOLD",
                {
                    enabled = true,

                    reason =
                        tostring(
                            reason
                            or "Manual station emergency hold"
                        )
                }
            )
        else
            writeCombinedOutput()

            queueEvent(
                "EMERGENCY_HOLD",
                {
                    enabled = false,

                    reason =
                        tostring(
                            reason
                            or "Emergency hold released"
                        )
                }
            )
        end

        lastSnapshot =
            makeSnapshot()

        return true
    end

    function controller.isEmergencyHold()
        return emergencyHold
    end

    function controller.clearPlatformFault(
        platformId
    )
        platformId =
            cleanIdentifier(
                platformId
            )

        local item =
            platforms[
                platformId
            ]

        if not item then
            return false,
                "Unknown or unwired platform "
                .. tostring(
                    platformId
                )
        end

        local ok, reason =
            item.controller.clearFault()

        writeCombinedOutput()

        return ok,
            reason
    end

    function controller.forceResetPlatform(
        platformId,
        trainId,
        newState
    )
        platformId =
            cleanIdentifier(
                platformId
            )

        local item =
            platforms[
                platformId
            ]

        if not item then
            return false,
                "Unknown or unwired platform "
                .. tostring(
                    platformId
                )
        end

        local ok, reason =
            item.controller.forceReset(
                trainId,
                newState
            )

        writeCombinedOutput()

        if ok then
            queueEvent(
                "PLATFORM_FORCE_RESET",
                {
                    platformId =
                        platformId,

                    trainId =
                        trainId,

                    newState =
                        newState
                }
            )
        end

        return ok,
            reason
    end

    function controller.setStationFault(
        code,
        message
    )
        stationFault = {
            code =
                tostring(
                    code
                    or "STATION_FAULT"
                ),

            message =
                tostring(
                    message
                    or "Station fault"
                ),

            time =
                nowClock()
        }

        writeFailSafe()

        queueEvent(
            "STATION_FAULT",
            stationFault
        )

        lastSnapshot =
            makeSnapshot()

        return true
    end

    function controller.clearStationFault()
        stationFault = nil

        writeCombinedOutput()

        queueEvent(
            "STATION_FAULT_CLEARED"
        )

        lastSnapshot =
            makeSnapshot()

        return true
    end

    function controller.run()
        running = true

        -- First update establishes detector state. If a platform detector is
        -- active at startup, platform_controller will fail safe and request
        -- operator resynchronisation.
        controller.update()

        local timer =
            os.startTimer(
                ioConfig.pollInterval
            )

        while running do
            local event = {
                os.pullEvent()
            }

            if event[1] == "timer"
                and event[2] == timer then

                controller.update()

                timer =
                    os.startTimer(
                        ioConfig.pollInterval
                    )

            elseif event[1] == "redstone" then
                controller.update()

            elseif event[1] == "terminate" then
                controller.stop()

                return
            end
        end
    end

    function controller.stop()
        running = false

        for _, id in ipairs(
            platformOrder
        ) do
            platforms[
                id
            ].controller.stop()
        end

        writeFailSafe()
    end

    function controller.isRunning()
        return running
    end

    return controller
end

function module.getIOPath()
    return IO_PATH
end

return module