-- MCNet graphical railway network map
-- Version 0.9.3
--
-- ComputerCraft 1.75 / CraftOS 1.7 compatible.
--
-- This module owns the PASSENGER MAP LAYOUT used by DISPLAY computers.
-- It deliberately does not represent exact Minecraft geography. It is a
-- schematic tube-style diagram matching the physical railway topology.
--
-- Visual design locked from the 2026-08-29 sketch:
--
--                     ACME -------- Electric -------- CENTRAL
--                                                 /   | | |
--                    BEE GARDENS ----------------     | | |
--                      /                               | | |
--          Honey ---- /                                | | +-- Central Line
--                    /                                 | +---- Eastern Line
--              ATOLL ISLAND                            +------ Circle Line
--                    \                                     /
--          Honey -----\---------------- LABORATORIES --+
--
-- Both passenger branches leave the shared CENTRAL -> LABORATORIES side:
--   * Central Line separates first and runs to Spa Village -> New Egypt.
--   * Eastern Line continues beside the Circle Line, then separates and runs
--     to Half-Wall -> Eastern Village.
--   * Circle Line continues to Laboratories.
--
-- Honey Line runs parallel to the left/bottom Circle corridor but BYPASSES
-- Atoll Island: there is no Honey Line stop at Atoll.
--
-- Lines are drawn as FILLED monitor cells, not "-", "/", "|" text rails.
-- Station labels are still text because that is the clearest option within
-- native ComputerCraft monitor limitations.

local module = {}

local VERSION = "0.9.3"

-- Reference coordinates are scaled into the currently redirected terminal.
-- The layout is intentionally wide and only moderately tall.
local REFERENCE_WIDTH = 1000
local REFERENCE_HEIGHT = 560

local function colour(name, fallback)
    if colors and colors[name] then
        return colors[name]
    end

    return fallback
end

-- These colours match the latest user sketch rather than the older rail_config
-- palette. We can synchronise rail_config separately once this map is approved.
local LINES = {
    CIRCLE = {
        id = "CIRCLE",
        name = "Circle Line",
        shortName = "Circle",
        colour = colour("yellow", 16)
    },

    HONEY_LINE = {
        id = "HONEY_LINE",
        name = "Honey Line",
        shortName = "Honey",
        colour = colour("pink", 64)
    },

    CENTRAL_LINE = {
        id = "CENTRAL_LINE",
        name = "Central Line",
        shortName = "Central",
        colour = colour("lightBlue", 8)
    },

    EASTERN_LINE = {
        id = "EASTERN_LINE",
        name = "Eastern Line",
        shortName = "Eastern",
        -- Lime is deliberately used as the brighter ComputerCraft "green"
        -- so it remains readable against a black monitor.
        colour = colour("lime", 32)
    },

    LITTLE_MEXICO_EXPRESS = {
        id = "LITTLE_MEXICO_EXPRESS",
        name = "Little Mexico Express",
        shortName = "Mexico",
        colour = colour("orange", 2)
    },

    ACME_ELECTRIC = {
        id = "ACME_ELECTRIC",
        name = "Electric Line",
        shortName = "Electric",
        colour = colour("red", 16384)
    }
}

local LINE_ORDER = {
    "HONEY_LINE",
    "CIRCLE",
    "ACME_ELECTRIC",
    "CENTRAL_LINE",
    "EASTERN_LINE",
    "LITTLE_MEXICO_EXPRESS"
}

-- Passenger stations.
--
-- IDs deliberately match rail_config.lua even where the passenger-facing label
-- is slightly different from the old config name.
local STATIONS = {
    ACME_ESC = {
        id = "ACME_ESC",
        name = "ACME",
        shortName = "ACME",
        x = 72,
        y = 78,
        terminus = true,
        label = {
            anchor = "right",
            dx = 2,
            dy = -1
        }
    },

    BEE_GARDENS = {
        id = "BEE_GARDENS",
        name = "Bee Gardens",
        shortName = "Bees",
        x = 258,
        y = 160,
        interchange = true,
        label = {
            anchor = "left",
            dx = -2,
            dy = -1
        }
    },

    CENTRAL = {
        id = "CENTRAL",
        name = "Central Station",
        shortName = "Central",
        x = 565,
        y = 160,
        interchange = true,
        label = {
            anchor = "right",
            dx = 2,
            dy = -1
        }
    },

    ATOLL_REEF = {
        id = "ATOLL_REEF",
        name = "Atoll Island",
        shortName = "Atoll",
        x = 155,
        y = 455,
        label = {
            anchor = "left",
            dx = -2,
            dy = 1
        }
    },

    LABORATORIES = {
        id = "LABORATORIES",
        name = "Laboratories",
        shortName = "Labs",
        x = 465,
        y = 455,
        interchange = true,
        label = {
            anchor = "right",
            dx = 2,
            dy = 1
        }
    },

    THE_SPA = {
        id = "THE_SPA",
        name = "Spa Village",
        shortName = "Spa",
        x = 720,
        y = 245,
        label = {
            anchor = "below",
            dx = 0,
            dy = 1
        }
    },

    NEW_EGYPT = {
        id = "NEW_EGYPT",
        name = "New Egypt",
        shortName = "Egypt",
        x = 940,
        y = 245,
        terminus = true,
        label = {
            anchor = "right",
            dx = 2,
            dy = 0
        }
    },

    HALF_WALL = {
        id = "HALF_WALL",
        name = "Half-Wall",
        shortName = "Half-Wall",
        x = 690,
        y = 355,
        label = {
            anchor = "above",
            dx = 0,
            dy = -1
        }
    },

    EASTERN_VILLAGE = {
        id = "EASTERN_VILLAGE",
        name = "Eastern Village",
        shortName = "Eastern",
        x = 850,
        y = 355,
        interchange = true,
        label = {
            anchor = "right",
            dx = 2,
            dy = 0
        }
    },

    LITTLE_MEXICO = {
        id = "LITTLE_MEXICO",
        name = "Little Mexico",
        shortName = "Mexico",
        x = 935,
        y = 480,
        terminus = true,
        label = {
            anchor = "right",
            dx = 2,
            dy = 0
        }
    }
}

local STATION_ORDER = {
    "ACME_ESC",
    "BEE_GARDENS",
    "CENTRAL",
    "ATOLL_REEF",
    "LABORATORIES",
    "THE_SPA",
    "NEW_EGYPT",
    "HALF_WALL",
    "EASTERN_VILLAGE",
    "LITTLE_MEXICO"
}

-- Junctions are NOT passenger stops. They only provide geometry for the shared
-- right-hand corridor and branch separation.
local POINTS = {
    -- Yellow Circle centre-line waypoints.
    SPA_JUNCTION_YELLOW = {
        x = 540,
        y = 245
    },

    EAST_JUNCTION_YELLOW = {
        x = 505,
        y = 355
    },

    -- Blue runs to the RIGHT of yellow from Central to the Spa junction.
    SPA_JUNCTION_BLUE = {
        x = 552,
        y = 245
    },

    -- Green runs to the LEFT of yellow down the shared corridor.
    SPA_JUNCTION_GREEN = {
        x = 528,
        y = 245
    },

    EAST_JUNCTION_GREEN = {
        x = 493,
        y = 355
    },

    -- Honey line sits outside the Circle line around Atoll.
    HONEY_LEFT_TOP = {
        x = 238,
        y = 182
    },

    HONEY_LEFT_BOTTOM = {
        x = 125,
        y = 448
    },

    HONEY_ATOLL_BYPASS = {
        x = 132,
        y = 490
    },

    HONEY_BOTTOM_LEFT = {
        x = 190,
        y = 510
    },

    HONEY_BOTTOM_RIGHT = {
        x = 430,
        y = 510
    },

    -- Electric route is mainly horizontal, then bends down into Central.
    ELECTRIC_BEND = {
        x = 445,
        y = 78
    },

    -- Little Mexico route mirrors the user's angled-down then horizontal sketch.
    MEXICO_BEND = {
        x = 800,
        y = 480
    }
}

local function stationPoint(id)
    local station = STATIONS[id]

    return {
        x = station.x,
        y = station.y
    }
end

-- Each route is an explicit polyline. This is intentional: the graphical map
-- should remain faithful to the approved schematic even if rail_config map
-- coordinates change for some other purpose.
local ROUTES = {
    {
        line = "CIRCLE",
        points = {
            stationPoint("BEE_GARDENS"),
            stationPoint("CENTRAL"),
            POINTS.SPA_JUNCTION_YELLOW,
            POINTS.EAST_JUNCTION_YELLOW,
            stationPoint("LABORATORIES"),
            stationPoint("ATOLL_REEF"),
            stationPoint("BEE_GARDENS")
        }
    },

    {
        line = "HONEY_LINE",
        points = {
            stationPoint("BEE_GARDENS"),
            POINTS.HONEY_LEFT_TOP,
            POINTS.HONEY_LEFT_BOTTOM,
            POINTS.HONEY_ATOLL_BYPASS,
            POINTS.HONEY_BOTTOM_LEFT,
            POINTS.HONEY_BOTTOM_RIGHT,
            stationPoint("LABORATORIES")
        }
    },

    {
        line = "CENTRAL_LINE",
        points = {
            stationPoint("CENTRAL"),

            -- Shared corridor: blue alongside yellow and green.
            {
                x = 572,
                y = 175
            },
            POINTS.SPA_JUNCTION_BLUE,

            -- Blue separates FIRST.
            {
                x = 610,
                y = 245
            },
            stationPoint("THE_SPA"),
            stationPoint("NEW_EGYPT")
        }
    },

    {
        line = "EASTERN_LINE",
        points = {
            stationPoint("CENTRAL"),

            -- Shared corridor: green remains alongside the Circle after the
            -- Central Line has branched away.
            {
                x = 552,
                y = 174
            },
            POINTS.SPA_JUNCTION_GREEN,
            POINTS.EAST_JUNCTION_GREEN,

            -- Green separates SECOND.
            {
                x = 545,
                y = 355
            },
            stationPoint("HALF_WALL"),
            stationPoint("EASTERN_VILLAGE")
        }
    },

    {
        line = "LITTLE_MEXICO_EXPRESS",
        points = {
            stationPoint("EASTERN_VILLAGE"),
            POINTS.MEXICO_BEND,
            stationPoint("LITTLE_MEXICO")
        }
    },

    {
        line = "ACME_ELECTRIC",
        points = {
            stationPoint("ACME_ESC"),
            POINTS.ELECTRIC_BEND,
            stationPoint("CENTRAL")
        }
    }
}

local function copy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, item in pairs(value) do
        result[key] = copy(item)
    end

    return result
end

local function setText(colourValue)
    if term.setTextColor then
        term.setTextColor(colourValue)
    elseif term.setTextColour then
        term.setTextColour(colourValue)
    end
end

local function setBackground(colourValue)
    if term.setBackgroundColor then
        term.setBackgroundColor(colourValue)
    elseif term.setBackgroundColour then
        term.setBackgroundColour(colourValue)
    end
end

local function safeWrite(text)
    write(
        tostring(
            text or ""
        )
    )
end

local function paintCell(
    x,
    y,
    background
)
    local width, height =
        term.getSize()

    x =
        math.floor(
            tonumber(x) or 0
        )

    y =
        math.floor(
            tonumber(y) or 0
        )

    if x < 1
        or x > width
        or y < 1
        or y > height then

        return
    end

    term.setCursorPos(
        x,
        y
    )

    setBackground(
        background
    )

    safeWrite(" ")
end

local function drawFilledLine(
    x1,
    y1,
    x2,
    y2,
    colourValue
)
    x1 = math.floor(x1)
    y1 = math.floor(y1)
    x2 = math.floor(x2)
    y2 = math.floor(y2)

    local dx =
        math.abs(
            x2 - x1
        )

    local dy =
        math.abs(
            y2 - y1
        )

    local sx =
        x1 < x2
        and 1
        or -1

    local sy =
        y1 < y2
        and 1
        or -1

    local err =
        dx - dy

    local x =
        x1

    local y =
        y1

    while true do
        paintCell(
            x,
            y,
            colourValue
        )

        if x == x2
            and y == y2 then

            break
        end

        local e2 =
            2 * err

        if e2 > -dy then
            err =
                err - dy

            x =
                x + sx
        end

        if e2 < dx then
            err =
                err + dx

            y =
                y + sy
        end
    end
end

local function drawPath(
    points,
    colourValue,
    transform
)
    for index = 1, #points - 1 do
        local x1, y1 =
            transform(
                points[index].x,
                points[index].y
            )

        local x2, y2 =
            transform(
                points[index + 1].x,
                points[index + 1].y
            )

        drawFilledLine(
            x1,
            y1,
            x2,
            y2,
            colourValue
        )
    end
end

local function writeClipped(
    x,
    y,
    text,
    colourValue
)
    local width, height =
        term.getSize()

    if y < 1
        or y > height then

        return
    end

    text =
        tostring(
            text or ""
        )

    if x < 1 then
        text =
            string.sub(
                text,
                2 - x
            )

        x = 1
    end

    if x > width
        or text == "" then

        return
    end

    local available =
        width - x + 1

    if #text > available then
        text =
            string.sub(
                text,
                1,
                available
            )
    end

    setBackground(
        colors.black
    )

    setText(
        colourValue
        or colors.white
    )

    term.setCursorPos(
        x,
        y
    )

    safeWrite(text)
end

local function drawCompactStation(
    x,
    y,
    selected
)
    setBackground(
        colors.black
    )

    setText(
        selected
        and colors.lime
        or colors.white
    )

    term.setCursorPos(
        x,
        y
    )

    safeWrite(
        selected
        and "@"
        or "O"
    )
end

local function drawLargeStation(
    x,
    y,
    selected,
    interchange,
    terminus
)
    -- Five filled monitor cells approximate a circular/diamond roundel:
    --
    --    #
    --   # #
    --    #
    --
    -- The centre remains black so route colours visibly run into the marker.
    local ringColour =
        selected
        and colors.lime
        or colors.white

    paintCell(
        x,
        y - 1,
        ringColour
    )

    paintCell(
        x - 1,
        y,
        ringColour
    )

    paintCell(
        x + 1,
        y,
        ringColour
    )

    paintCell(
        x,
        y + 1,
        ringColour
    )

    paintCell(
        x,
        y,
        colors.black
    )

    -- Interchanges receive one extra white/selected pixel to make the marker
    -- visually heavier without consuming a huge amount of map space.
    if interchange then
        paintCell(
            x + 1,
            y + 1,
            ringColour
        )
    elseif terminus then
        setBackground(
            colors.black
        )

        setText(
            ringColour
        )

        term.setCursorPos(
            x,
            y
        )

        safeWrite("o")
    end
end

local function drawLabel(
    station,
    x,
    y,
    compact,
    selected
)
    local label =
        compact
        and (
            station.shortName
            or station.name
        )
        or station.name

    local config =
        station.label
        or {}

    local anchor =
        config.anchor
        or "right"

    local dx =
        tonumber(
            config.dx
        )
        or 0

    local dy =
        tonumber(
            config.dy
        )
        or 0

    local textX =
        x + dx

    local textY =
        y + dy

    if anchor == "left" then
        textX =
            x
            - #label
            + dx

    elseif anchor == "above" then
        textX =
            x
            - math.floor(
                #label / 2
            )
            + dx

        textY =
            y - 1 + dy

    elseif anchor == "below" then
        textX =
            x
            - math.floor(
                #label / 2
            )
            + dx

        textY =
            y + 1 + dy

    elseif anchor == "right" then
        textX =
            x + dx

    end

    writeClipped(
        textX,
        textY,
        label,
        selected
        and colors.lime
        or colors.lightGray
    )
end

local function drawLegend(
    top,
    width
)
    if width < 55 then
        return 0
    end

    local items = {
        LINES.CIRCLE,
        LINES.HONEY_LINE,
        LINES.CENTRAL_LINE,
        LINES.EASTERN_LINE,
        LINES.LITTLE_MEXICO_EXPRESS,
        LINES.ACME_ELECTRIC
    }

    local x = 2
    local y = top
    local rowHeight = 1

    for _, lineInfo in ipairs(items) do
        local label =
            lineInfo.shortName

        local required =
            #label + 5

        if x + required > width then
            x = 2
            y =
                y + rowHeight
        end

        -- Small filled colour bar.
        paintCell(
            x,
            y,
            lineInfo.colour
        )

        paintCell(
            x + 1,
            y,
            lineInfo.colour
        )

        writeClipped(
            x + 3,
            y,
            label,
            colors.lightGray
        )

        x =
            x + required
    end

    return y - top + 1
end

function module.getVersion()
    return VERSION
end

function module.getLines()
    local result = {}

    for _, id in ipairs(LINE_ORDER) do
        result[#result + 1] =
            copy(
                LINES[id]
            )
    end

    return result
end

function module.getLine(id)
    id =
        tostring(
            id or ""
        )

    return LINES[id]
        and copy(
            LINES[id]
        )
        or nil
end

function module.getStations()
    local result = {}

    for _, id in ipairs(STATION_ORDER) do
        result[#result + 1] =
            copy(
                STATIONS[id]
            )
    end

    return result
end

function module.getStation(id)
    id =
        tostring(
            id or ""
        )

    return STATIONS[id]
        and copy(
            STATIONS[id]
        )
        or nil
end

function module.getStationLabel(id)
    local station =
        STATIONS[
            tostring(
                id or ""
            )
        ]

    return station
        and station.name
        or tostring(id)
end

function module.getRoutes()
    return copy(
        ROUTES
    )
end

function module.draw(options)
    options =
        type(options) == "table"
        and options
        or {}

    local width, height =
        term.getSize()

    -- Header row 1 is owned by display.lua.
    if width < 24
        or height < 10 then

        return false,
            "Monitor too small for rail map"
    end

    local selectedStation =
        tostring(
            options.selectedStation
            or "CENTRAL"
        )

    local legendRows = 0

    if options.showLegend ~= false
        and height >= 17 then

        legendRows =
            drawLegend(
                2,
                width
            )
    end

    local mapTop =
        2 + legendRows

    if legendRows > 0 then
        mapTop =
            mapTop + 1
    end

    local footerRows =
        height >= 14
        and 1
        or 0

    local mapBottom =
        height
        - footerRows

    local left =
        2

    local right =
        width - 2

    local top =
        mapTop

    local bottom =
        mapBottom - 1

    if bottom - top < 7 then
        top = 2
        bottom = height - 1
        footerRows = 0
    end

    local usableWidth =
        math.max(
            1,
            right - left
        )

    local usableHeight =
        math.max(
            1,
            bottom - top
        )

    local function transform(
        mapX,
        mapY
    )
        local x =
            left
            + math.floor(
                (
                    tonumber(mapX)
                    / REFERENCE_WIDTH
                )
                * usableWidth
            )

        local y =
            top
            + math.floor(
                (
                    tonumber(mapY)
                    / REFERENCE_HEIGHT
                )
                * usableHeight
            )

        return x, y
    end

    -- Draw filled route cells first. Station roundels and labels are layered
    -- over them afterwards, exactly like a tube-map diagram.
    for _, route in ipairs(ROUTES) do
        local lineInfo =
            LINES[
                route.line
            ]

        if lineInfo then
            drawPath(
                route.points,
                lineInfo.colour,
                transform
            )
        end
    end

    local largeMarkers =
        width >= 48
        and height >= 16

    local compactLabels =
        width < 44

    for _, id in ipairs(STATION_ORDER) do
        local station =
            STATIONS[id]

        local x, y =
            transform(
                station.x,
                station.y
            )

        local selected =
            id == selectedStation

        if largeMarkers
            and x > 2
            and x < width - 1
            and y > top
            and y < bottom then

            drawLargeStation(
                x,
                y,
                selected,
                station.interchange,
                station.terminus
            )
        else
            drawCompactStation(
                x,
                y,
                selected
            )
        end
    end

    -- Draw labels last so coloured tracks cannot overwrite station names.
    if width >= 34 then
        for _, id in ipairs(STATION_ORDER) do
            local station =
                STATIONS[id]

            local x, y =
                transform(
                    station.x,
                    station.y
                )

            drawLabel(
                station,
                x,
                y,
                compactLabels,
                id == selectedStation
            )
        end
    end

    if footerRows > 0 then
        local label =
            module.getStationLabel(
                selectedStation
            )

        local footer =
            "You are here: "
            .. tostring(label)

        local x =
            math.max(
                1,
                math.floor(
                    (width - #footer)
                    / 2
                ) + 1
            )

        writeClipped(
            x,
            height,
            footer,
            colors.yellow
        )
    end

    setBackground(
        colors.black
    )

    setText(
        colors.white
    )

    return true
end

return module
