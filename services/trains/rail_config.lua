-- MCNet rail network definition
-- Version 0.9.2
--
-- Authoritative static definition of the MCNet passenger rail network.
--
-- This file defines:
--   - station IDs and display names
--   - railway lines and colours
--   - station order on each line
--   - Tube-map coordinates
--   - public/private visibility
--   - basic operating metadata
--
-- It does NOT control trains, points, signals or timetables.
-- Those services should refer to this module instead of hard-coding names.

local module = {}

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

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end

    return false
end

local function getColour(name, fallback)
    if colors
        and colors[name] then
        return colors[name]
    end

    return fallback or 1
end

-- ---------------------------------------------------------------------------
-- Line definitions
-- ---------------------------------------------------------------------------

local lines = {
    CIRCLE = {
        id = "CIRCLE",
        name = "Circle Line",
        shortName = "Circle",
        colourName = "yellow",
        colour = getColour("yellow", 16),
        public = true,
        passenger = true,
        electric = false,
        circular = true,
        notes = "Bidirectional Circle service. Clockwise and anticlockwise trains use separate tracks.",

        -- Ordered clockwise.
        stations = {
            "CENTRAL",
            "LABORATORIES",
            "ATOLL_REEF",
            "BEE_GARDENS"
        }
    },

    CENTRAL_LINE = {
        id = "CENTRAL_LINE",
        name = "Central Line",
        shortName = "Central",
        colourName = "red",
        colour = getColour("red", 16384),
        public = true,
        passenger = true,
        electric = false,
        circular = false,
        notes = "Main northern branch from Central Station through The Spa to New Egypt.",

        stations = {
            "CENTRAL",
            "THE_SPA",
            "NEW_EGYPT"
        }
    },

    EASTERN_LINE = {
        id = "EASTERN_LINE",
        name = "Eastern Line",
        shortName = "Eastern",
        colourName = "blue",
        colour = getColour("blue", 2048),
        public = true,
        passenger = true,
        electric = false,
        circular = false,
        notes = "Eastern branch from Central Station through Half Wall to Eastern Village.",

        stations = {
            "CENTRAL",
            "HALF_WALL",
            "EASTERN_VILLAGE"
        }
    },

    LITTLE_MEXICO_EXPRESS = {
        id = "LITTLE_MEXICO_EXPRESS",
        name = "Little Mexico Express",
        shortName = "Mexico Exp.",
        colourName = "purple",
        colour = getColour("purple", 1024),
        public = true,
        passenger = true,
        electric = false,
        circular = false,
        singleTrack = true,
        notes = "Single-track express between Eastern Village and Little Mexico.",

        stations = {
            "EASTERN_VILLAGE",
            "LITTLE_MEXICO"
        }
    },

    HONEY_LINE = {
        id = "HONEY_LINE",
        name = "Honey Line",
        shortName = "Honey",
        colourName = "lime",
        colour = getColour("lime", 32),
        public = true,
        passenger = true,
        electric = false,
        circular = false,
        notes = "Direct Bee Gardens to Laboratories service, bypassing Atoll Reef.",

        stations = {
            "BEE_GARDENS",
            "LABORATORIES"
        }
    },

    ACME_ELECTRIC = {
        id = "ACME_ELECTRIC",
        name = "ACME Electric Line",
        shortName = "ACME",
        colourName = "cyan",
        colour = getColour("cyan", 512),
        public = true,
        passenger = true,
        electric = true,
        circular = false,
        underConstruction = true,
        notes = "Purpose-built electric route to the ACME ESC industrial compound.",

        stations = {
            "CENTRAL",
            "ACME_ESC"
        }
    },

    PRIVATE_EXPRESS = {
        id = "PRIVATE_EXPRESS",
        name = "Private Express",
        shortName = "Private",
        colourName = "white",
        colour = getColour("white", 1),
        public = false,
        passenger = false,
        private = true,
        electric = false,
        circular = false,
        notes = "Private main-base express route. Final junctions and destinations are not yet locked.",

        stations = {
            "CENTRAL"
        }
    },

    LAIR_SPUR = {
        id = "LAIR_SPUR",
        name = "Lair Spur",
        shortName = "Lair",
        colourName = "gray",
        colour = getColour("gray", 128),
        public = false,
        passenger = false,
        private = true,
        hidden = true,
        electric = false,
        circular = false,
        notes = "Hidden access route associated with The Spa. Not shown on normal passenger maps.",

        stations = {
            "THE_SPA",
            "LAIR"
        }
    }
}

-- ---------------------------------------------------------------------------
-- Station definitions
--
-- map.x / map.y are abstract Tube-map coordinates, NOT world coordinates.
-- They are deliberately schematic so the monitor renderer can use straight,
-- 45-degree and 90-degree segments later.
-- ---------------------------------------------------------------------------

local stations = {
    CENTRAL = {
        id = "CENTRAL",
        name = "Central Station",
        shortName = "Central",
        public = true,
        major = true,
        interchange = true,
        region = "HOME",

        lines = {
            "CIRCLE",
            "CENTRAL_LINE",
            "EASTERN_LINE",
            "ACME_ELECTRIC",
            "PRIVATE_EXPRESS"
        },

        map = {
            x = 24,
            y = 11,
            labelX = 26,
            labelY = 11
        },

        notes = "Primary passenger hub and future Grand Central-style concourse."
    },

    LABORATORIES = {
        id = "LABORATORIES",
        name = "Laboratories",
        shortName = "Labs",
        public = true,
        major = true,
        interchange = true,
        region = "HOME",

        lines = {
            "CIRCLE",
            "HONEY_LINE"
        },

        map = {
            x = 18,
            y = 17,
            labelX = 20,
            labelY = 17
        },

        notes = "Underwater laboratory station and Honey Line terminus/interchange."
    },

    ATOLL_REEF = {
        id = "ATOLL_REEF",
        name = "Atoll Reef",
        shortName = "Atoll",
        public = true,
        major = false,
        interchange = false,
        region = "ATOLL",

        lines = {
            "CIRCLE"
        },

        map = {
            x = 10,
            y = 17,
            labelX = 3,
            labelY = 17
        },

        notes = "Island village and scenic Circle Line stop."
    },

    BEE_GARDENS = {
        id = "BEE_GARDENS",
        name = "Bee Gardens",
        shortName = "Bees",
        public = true,
        major = true,
        interchange = true,
        region = "HOME",

        lines = {
            "CIRCLE",
            "HONEY_LINE"
        },

        map = {
            x = 8,
            y = 11,
            labelX = 1,
            labelY = 11
        },

        notes = "Forestry/apiary station and Honey Line interchange."
    },

    HALF_WALL = {
        id = "HALF_WALL",
        name = "Half Wall",
        shortName = "Half Wall",
        public = true,
        major = false,
        interchange = false,
        region = "EAST",

        lines = {
            "EASTERN_LINE"
        },

        map = {
            x = 34,
            y = 11,
            labelX = 36,
            labelY = 11
        },

        notes = "Village stop on the Eastern Line."
    },

    EASTERN_VILLAGE = {
        id = "EASTERN_VILLAGE",
        name = "Eastern Village",
        shortName = "Eastern",
        public = true,
        major = true,
        interchange = true,
        region = "EAST",

        lines = {
            "EASTERN_LINE",
            "LITTLE_MEXICO_EXPRESS"
        },

        map = {
            x = 46,
            y = 11,
            labelX = 48,
            labelY = 11
        },

        notes = "Eastern Line terminus/interchange for Little Mexico Express."
    },

    LITTLE_MEXICO = {
        id = "LITTLE_MEXICO",
        name = "Little Mexico",
        shortName = "Mexico",
        public = true,
        major = false,
        interchange = false,
        region = "SOUTH_EAST",

        lines = {
            "LITTLE_MEXICO_EXPRESS"
        },

        map = {
            x = 52,
            y = 17,
            labelX = 42,
            labelY = 17
        },

        notes = "Single-track express terminus serving the ziggurat/Mayan development."
    },

    THE_SPA = {
        id = "THE_SPA",
        name = "The Spa",
        shortName = "Spa",
        public = true,
        major = true,
        interchange = true,
        region = "NORTH",

        lines = {
            "CENTRAL_LINE",
            "LAIR_SPUR"
        },

        map = {
            x = 24,
            y = 6,
            labelX = 26,
            labelY = 6
        },

        notes = "Public Spa station with hidden private-lair infrastructure nearby."
    },

    NEW_EGYPT = {
        id = "NEW_EGYPT",
        name = "New Egypt",
        shortName = "Egypt",
        public = true,
        major = false,
        interchange = false,
        region = "NORTH",

        lines = {
            "CENTRAL_LINE"
        },

        map = {
            x = 24,
            y = 2,
            labelX = 26,
            labelY = 2
        },

        notes = "Northern Central Line terminus serving the pyramid area."
    },

    ACME_ESC = {
        id = "ACME_ESC",
        name = "ACME ESC Compound",
        shortName = "ACME",
        public = true,
        major = false,
        interchange = false,
        region = "NORTH_EAST",

        lines = {
            "ACME_ELECTRIC"
        },

        map = {
            x = 40,
            y = 4,
            labelX = 42,
            labelY = 4
        },

        notes = "Industrial compound for dangerous manufacturing. First purpose-built electric route."
    },

    LAIR = {
        id = "LAIR",
        name = "Lair",
        shortName = "Lair",
        public = false,
        major = false,
        interchange = false,
        hidden = true,
        region = "NORTH",

        lines = {
            "LAIR_SPUR"
        },

        map = {
            x = 31,
            y = 6,
            labelX = 33,
            labelY = 6
        },

        notes = "Hidden private destination. Omitted from public passenger maps."
    }
}

-- ---------------------------------------------------------------------------
-- Schematic map segments
--
-- The renderer can use these directly instead of trying to infer geometry
-- from station order. Each segment may be drawn independently in its line
-- colour. This allows a Tube-style schematic map rather than geography.
-- ---------------------------------------------------------------------------

local mapSegments = {
    -- Circle Line schematic loop.
    {
        line = "CIRCLE",
        from = "CENTRAL",
        to = "LABORATORIES"
    },
    {
        line = "CIRCLE",
        from = "LABORATORIES",
        to = "ATOLL_REEF"
    },
    {
        line = "CIRCLE",
        from = "ATOLL_REEF",
        to = "BEE_GARDENS"
    },
    {
        line = "CIRCLE",
        from = "BEE_GARDENS",
        to = "CENTRAL"
    },

    -- Eastern Line.
    {
        line = "EASTERN_LINE",
        from = "CENTRAL",
        to = "HALF_WALL"
    },
    {
        line = "EASTERN_LINE",
        from = "HALF_WALL",
        to = "EASTERN_VILLAGE"
    },

    -- Central / Spa / New Egypt.
    {
        line = "CENTRAL_LINE",
        from = "CENTRAL",
        to = "THE_SPA"
    },
    {
        line = "CENTRAL_LINE",
        from = "THE_SPA",
        to = "NEW_EGYPT"
    },

    -- Honey shortcut.
    {
        line = "HONEY_LINE",
        from = "BEE_GARDENS",
        to = "LABORATORIES"
    },

    -- Little Mexico.
    {
        line = "LITTLE_MEXICO_EXPRESS",
        from = "EASTERN_VILLAGE",
        to = "LITTLE_MEXICO"
    },

    -- ACME electric.
    {
        line = "ACME_ELECTRIC",
        from = "CENTRAL",
        to = "ACME_ESC"
    },

    -- Hidden Lair spur.
    {
        line = "LAIR_SPUR",
        from = "THE_SPA",
        to = "LAIR",
        hidden = true
    }
}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function module.getStation(id)
    id = cleanIdentifier(id)

    if not stations[id] then
        return nil
    end

    return deepCopy(
        stations[id]
    )
end

function module.getLine(id)
    id = cleanIdentifier(id)

    if not lines[id] then
        return nil
    end

    return deepCopy(
        lines[id]
    )
end

function module.getStations(includeHidden)
    local result = {}

    for id, station in pairs(stations) do
        if includeHidden
            or station.hidden ~= true then

            result[#result + 1] =
                deepCopy(station)
        end
    end

    table.sort(
        result,
        function(a, b)
            return tostring(a.name)
                < tostring(b.name)
        end
    )

    return result
end

function module.getLines(includePrivate)
    local result = {}

    for id, line in pairs(lines) do
        if includePrivate
            or (
                line.public == true
                and line.hidden ~= true
            ) then

            result[#result + 1] =
                deepCopy(line)
        end
    end

    table.sort(
        result,
        function(a, b)
            return tostring(a.name)
                < tostring(b.name)
        end
    )

    return result
end

function module.getStationLines(stationId)
    local station =
        module.getStation(
            stationId
        )

    if not station then
        return {}
    end

    local result = {}

    for _, lineId in ipairs(
        station.lines or {}
    ) do
        local line =
            module.getLine(
                lineId
            )

        if line then
            result[#result + 1] =
                line
        end
    end

    return result
end

function module.getLineStations(lineId)
    local line =
        module.getLine(
            lineId
        )

    if not line then
        return {}
    end

    local result = {}

    for _, stationId in ipairs(
        line.stations or {}
    ) do
        local station =
            module.getStation(
                stationId
            )

        if station then
            result[#result + 1] =
                station
        end
    end

    return result
end

function module.stationHasLine(
    stationId,
    lineId
)
    local station =
        module.getStation(
            stationId
        )

    if not station then
        return false
    end

    lineId =
        cleanIdentifier(
            lineId
        )

    return contains(
        station.lines,
        lineId
    )
end

function module.getStationName(id)
    local station =
        module.getStation(
            id
        )

    if station then
        return station.name
    end

    return tostring(id or "UNKNOWN")
end

function module.getStationShortName(id)
    local station =
        module.getStation(
            id
        )

    if station then
        return station.shortName
    end

    return tostring(id or "UNKNOWN")
end

function module.getLineName(id)
    local line =
        module.getLine(
            id
        )

    if line then
        return line.name
    end

    return tostring(id or "UNKNOWN")
end

function module.getLineColour(id)
    local line =
        module.getLine(
            id
        )

    if line then
        return line.colour
    end

    return getColour(
        "white",
        1
    )
end

function module.getMapSegments(includeHidden)
    local result = {}

    for _, segment in ipairs(
        mapSegments
    ) do
        local line =
            lines[segment.line]

        if includeHidden
            or (
                segment.hidden ~= true
                and line
                and line.hidden ~= true
            ) then

            result[#result + 1] =
                deepCopy(segment)
        end
    end

    return result
end

function module.getMapBounds(includeHidden)
    local minimumX = nil
    local maximumX = nil
    local minimumY = nil
    local maximumY = nil

    for _, station in ipairs(
        module.getStations(
            includeHidden
        )
    ) do
        local map =
            station.map or {}

        local x =
            tonumber(map.x)

        local y =
            tonumber(map.y)

        if x and y then
            if not minimumX
                or x < minimumX then
                minimumX = x
            end

            if not maximumX
                or x > maximumX then
                maximumX = x
            end

            if not minimumY
                or y < minimumY then
                minimumY = y
            end

            if not maximumY
                or y > maximumY then
                maximumY = y
            end
        end
    end

    return {
        minX = minimumX or 1,
        maxX = maximumX or 1,
        minY = minimumY or 1,
        maxY = maximumY or 1
    }
end

function module.isKnownStation(id)
    id = cleanIdentifier(id)

    return stations[id]
        ~= nil
end

function module.isKnownLine(id)
    id = cleanIdentifier(id)

    return lines[id]
        ~= nil
end

function module.getRaw()
    return {
        stations =
            deepCopy(
                stations
            ),

        lines =
            deepCopy(
                lines
            ),

        mapSegments =
            deepCopy(
                mapSegments
            )
    }
end

return module