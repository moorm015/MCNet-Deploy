-- MCNet station configuration service
-- Version 0.9.2
--
-- Stores the permanent identity and local operating configuration for one
-- railway station.
--
-- This module does not directly control trains, signals or points. It stores
-- the configuration used by the later station, platform and display services.

local module = {}

local PATH = ".mcnet/station.lua"

local STATION_STATUSES = {
    "OPEN",
    "CLOSED",
    "MAINTENANCE",
    "EMERGENCY",
    "PLANNED"
}

local PLATFORM_STATUSES = {
    "OPEN",
    "CLOSED",
    "MAINTENANCE"
}

local PLATFORM_DIRECTIONS = {
    "CLOCKWISE",
    "ANTICLOCKWISE",
    "INBOUND",
    "OUTBOUND",
    "NORTHBOUND",
    "SOUTHBOUND",
    "EASTBOUND",
    "WESTBOUND",
    "BOTH",
    "UNKNOWN"
}

local DISPLAY_ROLES = {
    "STATION_SIGN",
    "MAP",
    "DEPARTURES",
    "PLATFORM",
    "STATUS"
}

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

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end

    return false
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

local function cleanShortName(value)
    value =
        string.upper(
            tostring(value or "")
        )

    value =
        string.gsub(
            value,
            "[^A-Z0-9]",
            ""
        )

    return string.sub(value, 1, 8)
end

local function cleanText(value)
    value = tostring(value or "")

    value =
        string.gsub(
            value,
            "[\r\n\t]",
            " "
        )

    value =
        string.gsub(
            value,
            "%s+",
            " "
        )

    value =
        string.gsub(
            value,
            "^%s+",
            ""
        )

    value =
        string.gsub(
            value,
            "%s+$",
            ""
        )

    return value
end

local function numberInRange(
    value,
    fallback,
    minimum,
    maximum
)
    value =
        tonumber(value)
        or fallback

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function booleanValue(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    return fallback == true
end

local function normaliseStringList(value)
    local result = {}
    local seen = {}

    if type(value) ~= "table" then
        return result
    end

    for _, item in ipairs(value) do
        local cleaned =
            cleanIdentifier(item)

        if cleaned ~= ""
            and not seen[cleaned] then

            seen[cleaned] = true
            result[#result + 1] =
                cleaned
        end
    end

    return result
end

local function normalisePlatform(value, index)
    value =
        type(value) == "table"
        and value
        or {}

    local platformId =
        cleanIdentifier(
            value.id
            or value.platformId
            or ("P" .. tostring(index))
        )

    if platformId == "" then
        platformId =
            "P" .. tostring(index)
    end

    local status =
        string.upper(
            tostring(
                value.status
                or "OPEN"
            )
        )

    if not contains(
        PLATFORM_STATUSES,
        status
    ) then
        status = "OPEN"
    end

    local direction =
        string.upper(
            tostring(
                value.direction
                or "UNKNOWN"
            )
        )

    if not contains(
        PLATFORM_DIRECTIONS,
        direction
    ) then
        direction = "UNKNOWN"
    end

    -- v0.9.1/v0.9.2 compatibility:
    -- Older station files used one generic sensor and one signal field.
    -- Keep those values if present, but expose the actual station hardware
    -- model we have now agreed:
    --
    --   D1 approach detector
    --   D2 berth detector
    --   H1 locking-track release
    --   D3 exit detector
    --
    -- The values are logical IDs only. Physical bundled-cable colours are
    -- configured later by the local platform-controller service.
    local legacySensor =
        cleanIdentifier(
            value.sensor
        )

    local legacySignal =
        cleanIdentifier(
            value.signal
        )

    local approachSensor =
        cleanIdentifier(
            value.approachSensor
        )

    local berthSensor =
        cleanIdentifier(
            value.berthSensor
            or legacySensor
        )

    local exitSensor =
        cleanIdentifier(
            value.exitSensor
        )

    local holdOutput =
        cleanIdentifier(
            value.holdOutput
        )

    return {
        id = platformId,

        name =
            cleanText(
                value.name
                or ("Platform " .. tostring(index))
            ),

        status = status,

        direction = direction,

        lines =
            normaliseStringList(
                value.lines
                or (
                    value.line
                    and { value.line }
                    or {}
                )
            ),

        enabled =
            booleanValue(
                value.enabled,
                true
            ),

        -- Logical station-control points.
        approachSensor = approachSensor,
        berthSensor = berthSensor,
        exitSensor = exitSensor,
        holdOutput = holdOutput,

        -- Kept for compatibility with older saved configurations.
        sensor = legacySensor,
        signal = legacySignal,

        notes =
            cleanText(
                value.notes
            )
    }
end

local function normalisePlatforms(value)
    local result = {}
    local seen = {}

    if type(value) ~= "table" then
        value = {}
    end

    for index, item in ipairs(value) do
        local platform =
            normalisePlatform(
                item,
                index
            )

        if not seen[platform.id] then
            seen[platform.id] = true

            result[#result + 1] =
                platform
        end
    end

    if #result == 0 then
        result[1] =
            normalisePlatform(
                {
                    id = "P1",
                    name = "Platform 1",
                    direction = "BOTH",
                    status = "OPEN",
                    enabled = true,
                    lines = {},
                    approachSensor = "",
                    berthSensor = "",
                    exitSensor = "",
                    holdOutput = ""
                },
                1
            )
    end

    return result
end

local function normaliseDisplay(value, index)
    value =
        type(value) == "table"
        and value
        or {}

    local displayId =
        cleanIdentifier(
            value.id
            or value.displayId
            or ("DISPLAY-" .. tostring(index))
        )

    if displayId == "" then
        displayId =
            "DISPLAY-" .. tostring(index)
    end

    local role =
        string.upper(
            tostring(
                value.role
                or value.type
                or "STATUS"
            )
        )

    if not contains(
        DISPLAY_ROLES,
        role
    ) then
        role = "STATUS"
    end

    return {
        id = displayId,

        role = role,

        peripheral =
            cleanText(
                value.peripheral
                or value.side
            ),

        platform =
            cleanIdentifier(
                value.platform
            ),

        enabled =
            booleanValue(
                value.enabled,
                true
            ),

        textScale =
            numberInRange(
                value.textScale,
                0.5,
                0.5,
                5
            ),

        refreshInterval =
            numberInRange(
                value.refreshInterval,
                1,
                0.2,
                60
            )
    }
end

local function normaliseDisplays(value)
    local result = {}
    local seen = {}

    if type(value) ~= "table" then
        return result
    end

    for index, item in ipairs(value) do
        local display =
            normaliseDisplay(
                item,
                index
            )

        if not seen[display.id] then
            seen[display.id] = true

            result[#result + 1] =
                display
        end
    end

    return result
end

local function normaliseAccess(value)
    value =
        type(value) == "table"
        and value
        or {}

    return {
        pdaEnabled =
            booleanValue(
                value.pdaEnabled,
                true
            ),

        range =
            numberInRange(
                value.range,
                12,
                1,
                128
            ),

        roles =
            normaliseStringList(
                value.roles
                or {
                    "NETWORK_ADMIN",
                    "RAIL_ADMIN"
                }
            )
    }
end

local function normaliseBanner(value)
    value =
        type(value) == "table"
        and value
        or {}

    local categories =
        normaliseStringList(
            value.categories
            or {
                "EMERGENCY",
                "SERVICE",
                "SAFETY",
                "ADVICE",
                "NEWS",
                "JOKE"
            }
        )

    return {
        enabled =
            booleanValue(
                value.enabled,
                true
            ),

        interval =
            numberInRange(
                value.interval,
                10,
                2,
                300
            ),

        scrollSpeed =
            numberInRange(
                value.scrollSpeed,
                0.15,
                0.05,
                2
            ),

        categories = categories,

        localMessages =
            type(value.localMessages)
                == "table"
            and deepCopy(
                value.localMessages
            )
            or {}
    }
end

function module.getSuggestedStationID()
    return "STN-"
        .. string.format(
            "%03d",
            os.getComputerID()
        )
end

function module.createDefault()
    return {
        format = 2,

        -- Unique MCNet identity of this physical station controller.
        stationId =
            module.getSuggestedStationID(),

        -- Logical passenger-network location used by the Tube map,
        -- timetable and display systems.
        --
        -- Examples:
        -- CENTRAL
        -- LABORATORIES
        -- ATOLL_REEF
        -- BEE_GARDENS
        -- HALF_WALL
        -- EASTERN_VILLAGE
        -- LITTLE_MEXICO
        -- THE_SPA
        -- NEW_EGYPT
        -- ACME_ESC
        mapId = "CENTRAL",

        name = "",

        shortName = "",

        region = "UNKNOWN",

        status = "PLANNED",

        lines = {},

        platforms = {
            {
                id = "P1",
                name = "Platform 1",
                status = "OPEN",
                direction = "BOTH",
                lines = {},
                enabled = true,

                -- Standard MCNet platform hardware:
                -- D1 = approach detector
                -- D2 = berth detector
                -- H1 = locking-track release
                -- D3 = exit detector
                approachSensor = "",
                berthSensor = "",
                exitSensor = "",
                holdOutput = "",

                -- Legacy fields retained for old configuration files.
                sensor = "",
                signal = "",

                notes = ""
            }
        },

        -- Station-local display declarations are retained because they may
        -- later be useful for station-owned displays. Independent DISPLAY
        -- computers use services/system/display_config.lua instead.
        displays = {},

        banner = {
            enabled = true,
            interval = 10,
            scrollSpeed = 0.15,
            categories = {
                "EMERGENCY",
                "SERVICE",
                "SAFETY",
                "ADVICE",
                "NEWS",
                "JOKE"
            },
            localMessages = {}
        },

        access = {
            pdaEnabled = true,
            range = 12,
            roles = {
                "NETWORK_ADMIN",
                "RAIL_ADMIN"
            }
        },

        timezone = "MINECRAFT",

        notes = ""
    }
end

function module.normalise(config)
    local result =
        module.createDefault()

    config =
        type(config) == "table"
        and config
        or {}

    result.format =
        math.max(
            1,
            math.floor(
                tonumber(
                    config.format
                ) or result.format
            )
        )

    result.stationId =
        cleanIdentifier(
            config.stationId
            or config.address
            or result.stationId
        )

    if result.stationId == "" then
        result.stationId =
            module.getSuggestedStationID()
    end

    result.mapId =
        cleanIdentifier(
            config.mapId
            or config.station
            or result.mapId
        )

    if result.mapId == "" then
        result.mapId = "CENTRAL"
    end

    result.name =
        cleanText(
            config.name
            or config.friendlyName
        )

    result.shortName =
        cleanShortName(
            config.shortName
        )

    if result.shortName == ""
        and result.name ~= "" then

        local suggested =
            string.gsub(
                result.name,
                "[^A-Za-z0-9]",
                ""
            )

        result.shortName =
            cleanShortName(
                suggested
            )
    end

    result.region =
        cleanIdentifier(
            config.region
            or "UNKNOWN"
        )

    if result.region == "" then
        result.region = "UNKNOWN"
    end

    result.status =
        string.upper(
            tostring(
                config.status
                or "PLANNED"
            )
        )

    if not contains(
        STATION_STATUSES,
        result.status
    ) then
        result.status = "PLANNED"
    end

    result.lines =
        normaliseStringList(
            config.lines
        )

    result.platforms =
        normalisePlatforms(
            config.platforms
        )

    result.displays =
        normaliseDisplays(
            config.displays
        )

    result.banner =
        normaliseBanner(
            config.banner
        )

    result.access =
        normaliseAccess(
            config.access
        )

    result.timezone =
        cleanIdentifier(
            config.timezone
            or "MINECRAFT"
        )

    if result.timezone == "" then
        result.timezone =
            "MINECRAFT"
    end

    result.notes =
        cleanText(
            config.notes
        )

    return result
end

function module.validate(config)
    if type(config) ~= "table" then
        return false,
            "Station configuration must be a table"
    end

    local value =
        module.normalise(config)

    if value.stationId == "" then
        return false,
            "Station ID is required"
    end

    if value.mapId == "" then
        return false,
            "Station map ID is required"
    end

    if value.name == "" then
        return false,
            "Station name is required"
    end

    if value.shortName == "" then
        return false,
            "Station short name is required"
    end

    if #value.platforms == 0 then
        return false,
            "At least one platform is required"
    end

    local platformIds = {}

    for _, platform in ipairs(
        value.platforms
    ) do
        if platformIds[platform.id] then
            return false,
                "Duplicate platform ID: "
                .. tostring(platform.id)
        end

        platformIds[platform.id] = true
    end

    for _, display in ipairs(
        value.displays
    ) do
        if display.role == "PLATFORM"
            and display.platform ~= ""
            and not platformIds[
                display.platform
            ] then

            return false,
                "Display "
                .. tostring(display.id)
                .. " references unknown platform "
                .. tostring(display.platform)
        end
    end

    return true
end

function module.isConfigured(config)
    local valid =
        module.validate(config)

    return valid == true
end

function module.load(path)
    path = path or PATH

    if not fs.exists(path) then
        return module.createDefault()
    end

    local loaded, config =
        pcall(
            dofile,
            path
        )

    if not loaded
        or type(config) ~= "table" then

        return module.createDefault()
    end

    return module.normalise(config)
end

function module.save(config, path)
    path = path or PATH

    local normalised =
        module.normalise(config)

    local valid, reason =
        module.validate(normalised)

    if not valid then
        return false, reason
    end

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
            "Could not open station configuration file"
    end

    file.write("return ")

    file.write(
        textutils.serialize(
            normalised
        )
    )

    file.write("\n")
    file.close()

    local checked, savedValue =
        pcall(
            dofile,
            temporary
        )

    if not checked
        or type(savedValue) ~= "table" then

        fs.delete(temporary)

        return false,
            "Could not verify station configuration file"
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

function module.findPlatform(config, platformId)
    config =
        module.normalise(config)

    platformId =
        cleanIdentifier(
            platformId
        )

    for _, platform in ipairs(
        config.platforms
    ) do
        if platform.id == platformId then
            return deepCopy(platform)
        end
    end

    return nil
end

function module.findDisplay(config, displayId)
    config =
        module.normalise(config)

    displayId =
        cleanIdentifier(
            displayId
        )

    for _, display in ipairs(
        config.displays
    ) do
        if display.id == displayId then
            return deepCopy(display)
        end
    end

    return nil
end

function module.getStationStatuses()
    return deepCopy(
        STATION_STATUSES
    )
end

function module.getPlatformStatuses()
    return deepCopy(
        PLATFORM_STATUSES
    )
end

function module.getPlatformDirections()
    return deepCopy(
        PLATFORM_DIRECTIONS
    )
end

function module.getDisplayRoles()
    return deepCopy(
        DISPLAY_ROLES
    )
end

function module.getPath()
    return PATH
end

return module