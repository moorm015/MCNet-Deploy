-- MCNet railway timetable service
-- Version 0.9.2
--
-- Provides provisional scheduled departures for station and platform displays.
--
-- IMPORTANT:
-- The running times in this file are TEST VALUES only.
-- They exist so the new MCNet station displays can be tested before the real
-- railway has been timed.
--
-- Once the physical railway is measured, replace the offsets/frequencies here
-- with the real values. Later, the live Rail Control service will add actual
-- train position, delay, stop-skipping and cancellation information.
--
-- Public API used by applications/roles/display.lua:
--
--   getDepartures(stationId [, limit])
--   getPlatformDepartures(stationId, platformId [, limit])
--
-- Additional helpers are included now so the file can grow into the live
-- timetable layer without changing every display later.

local module = {}

local railConfig = nil

if fs.exists("services/trains/rail_config.lua") then
    local loaded, value =
        pcall(
            dofile,
            "services/trains/rail_config.lua"
        )

    if loaded
        and type(value) == "table" then

        railConfig = value
    end
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

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
            "_"
        )

    value =
        string.gsub(
            value,
            "[^A-Z0-9_%-]",
            ""
        )

    return value
end

local function clampInteger(
    value,
    fallback,
    minimum,
    maximum
)
    value =
        math.floor(
            tonumber(value)
            or fallback
        )

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function stationName(id)
    if railConfig
        and railConfig.getStationName then

        return railConfig.getStationName(
            id
        )
    end

    return tostring(id or "UNKNOWN")
end

local function lineName(id)
    if railConfig
        and railConfig.getLineName then

        return railConfig.getLineName(
            id
        )
    end

    return tostring(id or "UNKNOWN")
end

local function normaliseMinute(value)
    value =
        math.floor(
            tonumber(value)
            or 0
        )

    while value < 0 do
        value =
            value + 1440
    end

    return value % 1440
end

local function formatClock(minutes)
    minutes =
        normaliseMinute(
            minutes
        )

    local hour =
        math.floor(
            minutes / 60
        )

    local minute =
        minutes % 60

    return string.format(
        "%02d:%02d",
        hour,
        minute
    )
end

local function getMinecraftMinute()
    if os.time then
        local value =
            tonumber(
                os.time()
            )

        if value then
            return normaliseMinute(
                math.floor(
                    value * 60
                )
            )
        end
    end

    -- Fallback for tests outside a full ComputerCraft world.
    return normaliseMinute(
        math.floor(
            os.clock()
        )
    )
end

local function minutesUntil(
    now,
    target
)
    now =
        normaliseMinute(now)

    target =
        normaliseMinute(target)

    local difference =
        target - now

    if difference < 0 then
        difference =
            difference + 1440
    end

    return difference
end

-- ---------------------------------------------------------------------------
-- Provisional service patterns
--
-- frequency:
--   Minecraft-clock minutes between successive services of this pattern.
--
-- startOffset:
--   Offset within that frequency used to stagger opposing directions.
--
-- stops:
--   offset is the provisional journey time from the pattern origin.
--
-- Platform numbers are DRAFT assignments for the test system. They are kept
-- here rather than in display.lua so they can be changed later in one place.
-- ---------------------------------------------------------------------------

local services = {
    {
        id = "CIRCLE-CW",
        line = "CIRCLE",
        displayLine = "Circle Line (Clockwise)",
        destination = "CENTRAL",
        direction = "CLOCKWISE",
        frequency = 12,
        startOffset = 0,
        status = "ON TIME",

        stops = {
            {
                station = "CENTRAL",
                offset = 0,
                platform = "P1"
            },
            {
                station = "LABORATORIES",
                offset = 3,
                platform = "P1"
            },
            {
                station = "ATOLL_REEF",
                offset = 6,
                platform = "P1"
            },
            {
                station = "BEE_GARDENS",
                offset = 9,
                platform = "P1"
            },
            {
                station = "CENTRAL",
                offset = 12,
                platform = "P1",
                terminating = true
            }
        }
    },

    {
        id = "CIRCLE-ACW",
        line = "CIRCLE",
        displayLine = "Circle Line (Anticlockwise)",
        destination = "CENTRAL",
        direction = "ANTICLOCKWISE",
        frequency = 12,
        startOffset = 6,
        status = "ON TIME",

        stops = {
            {
                station = "CENTRAL",
                offset = 0,
                platform = "P2"
            },
            {
                station = "BEE_GARDENS",
                offset = 3,
                platform = "P2"
            },
            {
                station = "ATOLL_REEF",
                offset = 6,
                platform = "P2"
            },
            {
                station = "LABORATORIES",
                offset = 9,
                platform = "P2"
            },
            {
                station = "CENTRAL",
                offset = 12,
                platform = "P2",
                terminating = true
            }
        }
    },

    {
        id = "CENTRAL-NORTH",
        line = "CENTRAL_LINE",
        displayLine = "Central Line",
        destination = "NEW_EGYPT",
        direction = "NORTHBOUND",
        frequency = 15,
        startOffset = 0,
        status = "ON TIME",

        stops = {
            {
                station = "CENTRAL",
                offset = 0,
                platform = "P5"
            },
            {
                station = "THE_SPA",
                offset = 5,
                platform = "P1"
            },
            {
                station = "NEW_EGYPT",
                offset = 10,
                platform = "P1",
                terminating = true
            }
        }
    },

    {
        id = "CENTRAL-SOUTH",
        line = "CENTRAL_LINE",
        displayLine = "Central Line",
        destination = "CENTRAL",
        direction = "SOUTHBOUND",
        frequency = 15,
        startOffset = 7,
        status = "ON TIME",

        stops = {
            {
                station = "NEW_EGYPT",
                offset = 0,
                platform = "P1"
            },
            {
                station = "THE_SPA",
                offset = 5,
                platform = "P2"
            },
            {
                station = "CENTRAL",
                offset = 10,
                platform = "P5",
                terminating = true
            }
        }
    },

    {
        id = "EASTERN-OUT",
        line = "EASTERN_LINE",
        displayLine = "Eastern Line",
        destination = "EASTERN_VILLAGE",
        direction = "EASTBOUND",
        frequency = 12,
        startOffset = 2,
        status = "ON TIME",

        stops = {
            {
                station = "CENTRAL",
                offset = 0,
                platform = "P3"
            },
            {
                station = "HALF_WALL",
                offset = 4,
                platform = "P1"
            },
            {
                station = "EASTERN_VILLAGE",
                offset = 8,
                platform = "P1",
                terminating = true
            }
        }
    },

    {
        id = "EASTERN-IN",
        line = "EASTERN_LINE",
        displayLine = "Eastern Line",
        destination = "CENTRAL",
        direction = "WESTBOUND",
        frequency = 12,
        startOffset = 8,
        status = "ON TIME",

        stops = {
            {
                station = "EASTERN_VILLAGE",
                offset = 0,
                platform = "P2"
            },
            {
                station = "HALF_WALL",
                offset = 4,
                platform = "P2"
            },
            {
                station = "CENTRAL",
                offset = 8,
                platform = "P4",
                terminating = true
            }
        }
    },

    {
        id = "HONEY-NORTH",
        line = "HONEY_LINE",
        displayLine = "Honey Line",
        destination = "BEE_GARDENS",
        direction = "NORTHBOUND",
        frequency = 18,
        startOffset = 3,
        status = "ON TIME",

        stops = {
            {
                station = "LABORATORIES",
                offset = 0,
                platform = "P3"
            },
            {
                station = "BEE_GARDENS",
                offset = 6,
                platform = "P3",
                terminating = true
            }
        }
    },

    {
        id = "HONEY-SOUTH",
        line = "HONEY_LINE",
        displayLine = "Honey Line",
        destination = "LABORATORIES",
        direction = "SOUTHBOUND",
        frequency = 18,
        startOffset = 12,
        status = "ON TIME",

        stops = {
            {
                station = "BEE_GARDENS",
                offset = 0,
                platform = "P3"
            },
            {
                station = "LABORATORIES",
                offset = 6,
                platform = "P3",
                terminating = true
            }
        }
    },

    {
        id = "MEXICO-OUT",
        line = "LITTLE_MEXICO_EXPRESS",
        displayLine = "Little Mexico Express",
        destination = "LITTLE_MEXICO",
        direction = "SOUTHBOUND",
        frequency = 24,
        startOffset = 4,
        status = "ON TIME",

        stops = {
            {
                station = "EASTERN_VILLAGE",
                offset = 0,
                platform = "P3"
            },
            {
                station = "LITTLE_MEXICO",
                offset = 12,
                platform = "P1",
                terminating = true
            }
        }
    },

    {
        id = "MEXICO-IN",
        line = "LITTLE_MEXICO_EXPRESS",
        displayLine = "Little Mexico Express",
        destination = "EASTERN_VILLAGE",
        direction = "NORTHBOUND",
        frequency = 24,
        startOffset = 16,
        status = "ON TIME",

        stops = {
            {
                station = "LITTLE_MEXICO",
                offset = 0,
                platform = "P1"
            },
            {
                station = "EASTERN_VILLAGE",
                offset = 12,
                platform = "P3",
                terminating = true
            }
        }
    },

    {
        id = "ACME-OUT",
        line = "ACME_ELECTRIC",
        displayLine = "ACME Electric Line",
        destination = "ACME_ESC",
        direction = "NORTH_EAST",
        frequency = 20,
        startOffset = 5,
        status = "TESTING",

        stops = {
            {
                station = "CENTRAL",
                offset = 0,
                platform = "P6"
            },
            {
                station = "ACME_ESC",
                offset = 8,
                platform = "P1",
                terminating = true
            }
        }
    },

    {
        id = "ACME-IN",
        line = "ACME_ELECTRIC",
        displayLine = "ACME Electric Line",
        destination = "CENTRAL",
        direction = "SOUTH_WEST",
        frequency = 20,
        startOffset = 15,
        status = "TESTING",

        stops = {
            {
                station = "ACME_ESC",
                offset = 0,
                platform = "P1"
            },
            {
                station = "CENTRAL",
                offset = 8,
                platform = "P6",
                terminating = true
            }
        }
    }
}

-- ---------------------------------------------------------------------------
-- Runtime overrides
--
-- These are deliberately memory-only in v0.9.2.
-- Later Rail Control can feed this information from actual train state.
-- ---------------------------------------------------------------------------

local runtime = {
    services = {}
}

local function getRuntime(serviceId)
    serviceId =
        cleanIdentifier(
            serviceId
        )

    if not runtime.services[
        serviceId
    ] then

        runtime.services[
            serviceId
        ] = {
            delay = 0,
            status = nil,
            cancelledStops = {}
        }
    end

    return runtime.services[
        serviceId
    ]
end

local function getServiceById(serviceId)
    serviceId =
        cleanIdentifier(
            serviceId
        )

    for _, service in ipairs(
        services
    ) do
        if cleanIdentifier(
            service.id
        ) == serviceId then

            return service
        end
    end

    return nil
end

local function findStopIndexes(
    service,
    stationId
)
    local result = {}

    stationId =
        cleanIdentifier(
            stationId
        )

    for index, stop in ipairs(
        service.stops or {}
    ) do
        if cleanIdentifier(
            stop.station
        ) == stationId then

            result[#result + 1] =
                index
        end
    end

    return result
end

local function callingPoints(
    service,
    stopIndex
)
    local result = {}
    local runtimeState =
        getRuntime(
            service.id
        )

    for index =
        stopIndex + 1,
        #(service.stops or {}) do

        local stop =
            service.stops[index]

        local stopId =
            cleanIdentifier(
                stop.station
            )

        if not runtimeState.cancelledStops[
            stopId
        ] then

            result[#result + 1] =
                stationName(
                    stop.station
                )
        end
    end

    return result
end

local function nextPatternDeparture(
    service,
    stop,
    now
)
    local frequency =
        clampInteger(
            service.frequency,
            10,
            1,
            1440
        )

    local base =
        normaliseMinute(
            tonumber(
                service.startOffset
            ) or 0
        )

    local offset =
        math.floor(
            tonumber(
                stop.offset
            ) or 0
        )

    local runtimeState =
        getRuntime(
            service.id
        )

    local delay =
        math.max(
            0,
            math.floor(
                tonumber(
                    runtimeState.delay
                ) or 0
            )
        )

    local first =
        normaliseMinute(
            base
            + offset
            + delay
        )

    local best = nil
    local bestWait = nil

    -- 1440 iterations is a hard upper bound for a 1-minute frequency.
    -- In normal configs this loop is only a handful of iterations.
    for step = 0, 1439 do
        local candidate =
            normaliseMinute(
                first
                + (
                    step
                    * frequency
                )
            )

        local wait =
            minutesUntil(
                now,
                candidate
            )

        if bestWait == nil
            or wait < bestWait then

            best =
                candidate

            bestWait =
                wait
        end

        if wait == 0 then
            break
        end

        if step > (
            math.ceil(
                1440
                / frequency
            ) + 2
        ) then
            break
        end
    end

    return best, bestWait or 0
end

local function makeDeparture(
    service,
    stopIndex,
    now
)
    local stop =
        service.stops[
            stopIndex
        ]

    if not stop then
        return nil
    end

    local runtimeState =
        getRuntime(
            service.id
        )

    local stationId =
        cleanIdentifier(
            stop.station
        )

    if runtimeState.cancelledStops[
        stationId
    ] then
        return nil
    end

    local scheduledMinute, wait =
        nextPatternDeparture(
            service,
            stop,
            now
        )

    local status =
        runtimeState.status
        or service.status
        or "ON TIME"

    local departure = {
        serviceId =
            service.id,

        line =
            service.line,

        lineName =
            service.displayLine
            or lineName(
                service.line
            ),

        direction =
            service.direction
            or "UNKNOWN",

        station =
            stationId,

        platform =
            stop.platform
            or "P1",

        destination =
            stationName(
                service.destination
            ),

        destinationId =
            cleanIdentifier(
                service.destination
            ),

        minutes =
            wait,

        scheduledMinute =
            scheduledMinute,

        scheduledTime =
            formatClock(
                scheduledMinute
            ),

        delay =
            math.max(
                0,
                math.floor(
                    tonumber(
                        runtimeState.delay
                    ) or 0
                )
            ),

        status =
            status,

        callingAt =
            callingPoints(
                service,
                stopIndex
            ),

        terminating =
            stop.terminating
            == true,

        testData = true
    }

    if departure.terminating then
        departure.callingAt = {}
    end

    return departure
end

local function sortDepartures(
    departures
)
    table.sort(
        departures,
        function(a, b)
            local aMinutes =
                tonumber(
                    a.minutes
                ) or 999999

            local bMinutes =
                tonumber(
                    b.minutes
                ) or 999999

            if aMinutes
                == bMinutes then

                return tostring(
                    a.serviceId
                )
                    < tostring(
                        b.serviceId
                    )
            end

            return aMinutes
                < bMinutes
        end
    )
end

local function limitResults(
    source,
    limit
)
    limit =
        clampInteger(
            limit,
            12,
            1,
            100
        )

    local result = {}

    for index = 1, math.min(
        #source,
        limit
    ) do
        result[index] =
            deepCopy(
                source[index]
            )
    end

    return result
end

-- ---------------------------------------------------------------------------
-- Public timetable API
-- ---------------------------------------------------------------------------

function module.getClockMinute()
    return getMinecraftMinute()
end

function module.formatClock(minutes)
    return formatClock(
        minutes
    )
end

function module.getServices()
    local result = {}

    for _, service in ipairs(
        services
    ) do
        result[#result + 1] =
            deepCopy(
                service
            )
    end

    return result
end

function module.getService(serviceId)
    local service =
        getServiceById(
            serviceId
        )

    if not service then
        return nil
    end

    local result =
        deepCopy(
            service
        )

    result.runtime =
        deepCopy(
            getRuntime(
                service.id
            )
        )

    return result
end

function module.getDepartures(
    stationId,
    limit
)
    stationId =
        cleanIdentifier(
            stationId
            or "CENTRAL"
        )

    local now =
        getMinecraftMinute()

    local result = {}

    for _, service in ipairs(
        services
    ) do
        local indexes =
            findStopIndexes(
                service,
                stationId
            )

        for _, stopIndex in ipairs(
            indexes
        ) do
            local departure =
                makeDeparture(
                    service,
                    stopIndex,
                    now
                )

            if departure
                and not departure.terminating then

                result[#result + 1] =
                    departure
            end
        end
    end

    sortDepartures(result)

    return limitResults(
        result,
        limit or 12
    )
end

function module.getPlatformDepartures(
    stationId,
    platformId,
    limit
)
    stationId =
        cleanIdentifier(
            stationId
            or "CENTRAL"
        )

    platformId =
        cleanIdentifier(
            platformId
            or "P1"
        )

    local all =
        module.getDepartures(
            stationId,
            100
        )

    local result = {}

    for _, departure in ipairs(
        all
    ) do
        if cleanIdentifier(
            departure.platform
        ) == platformId then

            result[#result + 1] =
                departure
        end
    end

    return limitResults(
        result,
        limit or 8
    )
end

function module.getLineDepartures(
    lineId,
    limit
)
    lineId =
        cleanIdentifier(
            lineId
        )

    local now =
        getMinecraftMinute()

    local result = {}

    for _, service in ipairs(
        services
    ) do
        if cleanIdentifier(
            service.line
        ) == lineId then

            for stopIndex, stop in ipairs(
                service.stops or {}
            ) do
                if not stop.terminating then
                    local departure =
                        makeDeparture(
                            service,
                            stopIndex,
                            now
                        )

                    if departure then
                        result[#result + 1] =
                            departure
                    end
                end
            end
        end
    end

    sortDepartures(result)

    return limitResults(
        result,
        limit or 20
    )
end

-- ---------------------------------------------------------------------------
-- Runtime controls
--
-- These are primarily for test-world use now. They model the controls the
-- future live Rail Control service will need.
-- ---------------------------------------------------------------------------

function module.setDelay(
    serviceId,
    minutes
)
    local service =
        getServiceById(
            serviceId
        )

    if not service then
        return false,
            "Unknown service: "
            .. tostring(
                serviceId
            )
    end

    local state =
        getRuntime(
            service.id
        )

    state.delay =
        clampInteger(
            minutes,
            0,
            0,
            240
        )

    return true
end

function module.setStatus(
    serviceId,
    status
)
    local service =
        getServiceById(
            serviceId
        )

    if not service then
        return false,
            "Unknown service: "
            .. tostring(
                serviceId
            )
    end

    status =
        string.upper(
            tostring(
                status
                or "ON TIME"
            )
        )

    getRuntime(
        service.id
    ).status =
        status

    return true
end

function module.cancelStop(
    serviceId,
    stationId,
    cancelled
)
    local service =
        getServiceById(
            serviceId
        )

    if not service then
        return false,
            "Unknown service: "
            .. tostring(
                serviceId
            )
    end

    stationId =
        cleanIdentifier(
            stationId
        )

    if #findStopIndexes(
        service,
        stationId
    ) == 0 then

        return false,
            "Service does not call at "
            .. tostring(
                stationId
            )
    end

    local state =
        getRuntime(
            service.id
        )

    if cancelled == false then
        state.cancelledStops[
            stationId
        ] = nil
    else
        state.cancelledStops[
            stationId
        ] = true
    end

    return true
end

function module.clearServiceOverride(
    serviceId
)
    serviceId =
        cleanIdentifier(
            serviceId
        )

    runtime.services[
        serviceId
    ] = nil

    return true
end

function module.clearOverrides()
    runtime = {
        services = {}
    }
end

function module.getRuntimeSnapshot()
    return deepCopy(
        runtime
    )
end

function module.isTestData()
    return true
end

return module