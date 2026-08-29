-- MCNet detailed passenger network map
-- Version 0.9.7
-- ComputerCraft 1.75 / CraftOS 1.7 compatible.
--
-- IMPORTANT DISPLAY INTENT
-- ------------------------
-- This is the LARGE, complete Tube-style map. It is deliberately intended
-- for a larger wall than the ordinary station "line map".
--
-- Recommended physical Advanced Monitor:
--     5 blocks wide x 3 blocks high at text scale 0.5
--
-- Minimum worth using:
--     4 blocks wide x 3 blocks high at text scale 0.5
--
-- The renderer preserves the aspect ratio of the hand-authored schematic
-- instead of stretching X and Y independently. That keeps the yellow
-- parallelogram/diamond and the branch geometry consistent.
--
-- The ordinary station line diagram lives in:
--     services/trains/line_map.lua

local network = {}

local pixel = dofile("services/ui/pixel.lua")

local VERSION = "0.9.7"

local function colour(name, fallback)
    if colors and colors[name] then
        return colors[name]
    end
    return fallback
end

local PALETTE = {
    background = colour("black", 32768),
    foreground = colour("white", 1),
    secondary = colour("lightGray", 256),
    selected = colour("lime", 32),
    selectedText = colour("yellow", 16),

    CIRCLE = colour("yellow", 16),
    HONEY_LINE = colour("pink", 64),
    CENTRAL_LINE = colour("lightBlue", 8),
    EASTERN_LINE = colour("lime", 32),
    LITTLE_MEXICO_EXPRESS = colour("orange", 2),
    ACME_ELECTRIC = colour("red", 16384)
}

-- Passenger-facing names follow the latest approved drawing.
local STATIONS = {
    ACME_ESC = {
        id = "ACME_ESC",
        name = "ACME",
        shortName = "ACME",
        x = 75, y = 55,
        terminus = true,
        label = { anchor = "right", dx = 2, dy = -1 }
    },
    BEE_GARDENS = {
        id = "BEE_GARDENS",
        name = "Bee Gardens",
        shortName = "Bee Gardens",
        x = 265, y = 125,
        interchange = true,
        label = { anchor = "left", dx = -2, dy = -1 }
    },
    CENTRAL = {
        id = "CENTRAL",
        name = "Central Station",
        shortName = "Central",
        x = 590, y = 125,
        interchange = true,
        major = true,
        label = { anchor = "right", dx = 2, dy = -1 }
    },
    ATOLL_REEF = {
        id = "ATOLL_REEF",
        name = "Atoll Island",
        shortName = "Atoll",
        x = 175, y = 355,
        label = { anchor = "left", dx = -2, dy = 1 }
    },
    LABORATORIES = {
        id = "LABORATORIES",
        name = "Laboratories",
        shortName = "Labs",
        x = 475, y = 355,
        interchange = true,
        label = { anchor = "right", dx = 2, dy = 1 }
    },
    THE_SPA = {
        id = "THE_SPA",
        name = "Spa Village",
        shortName = "Spa",
        x = 735, y = 200,
        label = { anchor = "below", dx = 0, dy = 1 }
    },
    NEW_EGYPT = {
        id = "NEW_EGYPT",
        name = "New Egypt",
        shortName = "New Egypt",
        x = 1015, y = 200,
        terminus = true,
        label = { anchor = "right", dx = 2, dy = 0 }
    },
    HALF_WALL = {
        id = "HALF_WALL",
        name = "Half-Wall",
        shortName = "Half-Wall",
        x = 700, y = 290,
        label = { anchor = "above", dx = 0, dy = -1 }
    },
    EASTERN_VILLAGE = {
        id = "EASTERN_VILLAGE",
        name = "Eastern Village",
        shortName = "Eastern",
        x = 880, y = 290,
        interchange = true,
        label = { anchor = "right", dx = 2, dy = 0 }
    },
    LITTLE_MEXICO = {
        id = "LITTLE_MEXICO",
        name = "Little Mexico",
        shortName = "Mexico",
        x = 1015, y = 400,
        terminus = true,
        label = { anchor = "right", dx = 2, dy = 0 }
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

-- Route order here is the passenger-facing order used by line diagrams too.
local LINES = {
    CIRCLE = {
        id = "CIRCLE",
        name = "Circle Line",
        shortName = "Circle",
        colour = PALETTE.CIRCLE,
        circular = true,
        stations = {
            "BEE_GARDENS",
            "CENTRAL",
            "LABORATORIES",
            "ATOLL_REEF"
        }
    },
    HONEY_LINE = {
        id = "HONEY_LINE",
        name = "Honey Line",
        shortName = "Honey",
        colour = PALETTE.HONEY_LINE,
        stations = {
            "BEE_GARDENS",
            "LABORATORIES"
        },
        note = "Non-stop service - bypasses Atoll Island."
    },
    CENTRAL_LINE = {
        id = "CENTRAL_LINE",
        name = "Central Line",
        shortName = "Central",
        colour = PALETTE.CENTRAL_LINE,
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
        colour = PALETTE.EASTERN_LINE,
        stations = {
            "CENTRAL",
            "HALF_WALL",
            "EASTERN_VILLAGE"
        }
    },
    LITTLE_MEXICO_EXPRESS = {
        id = "LITTLE_MEXICO_EXPRESS",
        name = "Little Mexico Express",
        shortName = "Mexico",
        colour = PALETTE.LITTLE_MEXICO_EXPRESS,
        stations = {
            "EASTERN_VILLAGE",
            "LITTLE_MEXICO"
        }
    },
    ACME_ELECTRIC = {
        id = "ACME_ELECTRIC",
        name = "Electric Line",
        shortName = "Electric",
        colour = PALETTE.ACME_ELECTRIC,
        stations = {
            "ACME_ESC",
            "CENTRAL"
        },
        underConstruction = true
    }
}

local LINE_ORDER = {
    "CIRCLE",
    "HONEY_LINE",
    "CENTRAL_LINE",
    "EASTERN_LINE",
    "LITTLE_MEXICO_EXPRESS",
    "ACME_ELECTRIC"
}

-- Hand-authored geometry based directly on the user's Paint drawing.
--
-- The critical shared corridor is explicit:
--
-- CENTRAL
--   Yellow + Green + Blue together
--        |
--   BLUE branches right -> Spa Village -> New Egypt
--        |
--   Yellow + Green together
--        |
--   GREEN branches right -> Half-Wall -> Eastern Village
--        |
--   Yellow continues -> Laboratories
--
-- The lines are parallel, not merged, so the routes remain readable.
local ROUTES = {
    -- Circle Line: yellow parallelogram/diamond.
    {
        line = "CIRCLE",
        points = {
            { x = 265, y = 125 }, -- Bee Gardens
            { x = 590, y = 125 }, -- Central
            { x = 565, y = 195 }, -- upper shared corridor
            { x = 525, y = 285 }, -- lower shared corridor
            { x = 475, y = 355 }, -- Laboratories
            { x = 175, y = 355 }, -- Atoll Island
            { x = 265, y = 125 }  -- Bee Gardens
        }
    },

    -- Honey Line shares the same physical corridor as the Circle Line from
    -- Bee Gardens to Laboratories. On the public map it is drawn immediately
    -- alongside the yellow route so passengers can see it uses the same tunnel.
    --
    -- It DOES NOT stop at Atoll Island, so there is deliberately no pink
    -- station marker there. The short fan-out/fan-in at Bee Gardens and
    -- Laboratories exists only to keep the two colours separately visible.
    {
        line = "HONEY_LINE",
        points = {
            { x = 265, y = 125 }, -- Bee Gardens
            { x = 255, y = 132 }, -- short visual separation
            { x = 165, y = 365 }, -- passes beside/below Atoll without stopping
            { x = 465, y = 365 }, -- parallel to Circle bottom corridor
            { x = 475, y = 355 }  -- Laboratories
        }
    },

    -- Electric line across the top, then down into Central.
    {
        line = "ACME_ELECTRIC",
        points = {
            { x = 75, y = 55 },
            { x = 590, y = 55 },
            { x = 590, y = 125 }
        }
    },

    -- Blue route is outermost on the upper shared corridor and leaves first.
    {
        line = "CENTRAL_LINE",
        points = {
            { x = 594, y = 128 },
            { x = 579, y = 198 },
            { x = 640, y = 200 },
            { x = 735, y = 200 },
            { x = 1015, y = 200 }
        }
    },

    -- Green route sits between blue and yellow until blue leaves, then remains
    -- beside yellow until the Eastern junction.
    {
        line = "EASTERN_LINE",
        points = {
            { x = 586, y = 128 },
            { x = 557, y = 194 },
            { x = 517, y = 284 },
            { x = 590, y = 290 },
            { x = 700, y = 290 },
            { x = 880, y = 290 }
        }
    },

    {
        line = "LITTLE_MEXICO_EXPRESS",
        points = {
            { x = 880, y = 290 },
            { x = 825, y = 400 },
            { x = 1015, y = 400 }
        }
    }
}

local REF_WIDTH = 1120
local REF_HEIGHT = 445

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

local function labelPosition(station, x, y)
    local cfg = station.label or {}
    local anchor = cfg.anchor or "right"
    local dx = tonumber(cfg.dx) or 0
    local dy = tonumber(cfg.dy) or 0
    local text = station.name

    local tx = x + dx
    local ty = y + dy

    if anchor == "left" then
        tx = x - #text + dx
    elseif anchor == "above" then
        tx = x - math.floor(#text / 2) + dx
        ty = y - 1 + dy
    elseif anchor == "below" then
        tx = x - math.floor(#text / 2) + dx
        ty = y + 1 + dy
    end

    return tx, ty
end

local function stationLines(stationId)
    local result = {}

    for _, lineId in ipairs(LINE_ORDER) do
        local lineInfo = LINES[lineId]

        for _, id in ipairs(lineInfo.stations) do
            if id == stationId then
                result[#result + 1] = lineId
                break
            end
        end
    end

    return result
end

local function drawLegend(row, width)
    local x = 2
    local y = row

    for _, lineId in ipairs(LINE_ORDER) do
        local lineInfo = LINES[lineId]
        local needed = #lineInfo.shortName + 5

        if x + needed > width then
            x = 2
            y = y + 1
        end

        pixel.cell(x, y, lineInfo.colour)
        pixel.cell(x + 1, y, lineInfo.colour)
        pixel.text(
            x + 3,
            y,
            lineInfo.shortName,
            PALETTE.secondary,
            PALETTE.background
        )

        x = x + needed
    end

    return y
end

function network.getVersion()
    return VERSION
end

function network.getPalette()
    return copy(PALETTE)
end

function network.getStation(id)
    local station = STATIONS[tostring(id or "")]
    return station and copy(station) or nil
end

function network.getStations()
    local result = {}

    for _, id in ipairs(STATION_ORDER) do
        result[#result + 1] = copy(STATIONS[id])
    end

    return result
end

function network.getLine(id)
    local line = LINES[tostring(id or "")]
    return line and copy(line) or nil
end

function network.getLines()
    local result = {}

    for _, id in ipairs(LINE_ORDER) do
        result[#result + 1] = copy(LINES[id])
    end

    return result
end

function network.getStationLines(stationId)
    return stationLines(tostring(stationId or ""))
end

function network.getStationName(stationId)
    local station = STATIONS[tostring(stationId or "")]
    return station and station.name or tostring(stationId or "")
end

function network.draw(options)
    options = type(options) == "table" and options or {}

    local width, height = term.getSize()

    -- This screen is intentionally a LARGE-map product. Small screens should
    -- use services/trains/line_map.lua instead.
    if width < 60 or height < 20 then
        pixel.centerText(
            math.max(3, math.floor(height / 2) - 1),
            "Full network map",
            PALETTE.foreground,
            PALETTE.background
        )
        pixel.centerText(
            math.max(4, math.floor(height / 2)),
            "Use a larger monitor wall",
            PALETTE.secondary,
            PALETTE.background
        )
        pixel.centerText(
            math.max(5, math.floor(height / 2) + 1),
            "Recommended: 5 x 3 blocks",
            PALETTE.selectedText,
            PALETTE.background
        )
        return true
    end

    local selectedStation = tostring(options.selectedStation or "CENTRAL")

    -- Row 1 belongs to display.lua's dashboard header.
    local legendBottom = drawLegend(2, width)

    local canvasLeft = 2
    local canvasRight = width - 2
    local canvasTop = legendBottom + 2
    local canvasBottom = height - 2

    local usableW = canvasRight - canvasLeft
    local usableH = canvasBottom - canvasTop

    -- Uniform scaling preserves the exact schematic proportions.
    local scaleX = usableW / REF_WIDTH
    local scaleY = usableH / REF_HEIGHT
    local scale = math.min(scaleX, scaleY)

    local drawnW = REF_WIDTH * scale
    local drawnH = REF_HEIGHT * scale
    local offsetX = canvasLeft + math.floor((usableW - drawnW) / 2)
    local offsetY = canvasTop + math.floor((usableH - drawnH) / 2)

    local function transform(mx, my)
        return
            offsetX + math.floor(mx * scale + 0.5),
            offsetY + math.floor(my * scale + 0.5)
    end

    -- Solid route cells first.
    for _, route in ipairs(ROUTES) do
        local lineInfo = LINES[route.line]

        if lineInfo then
            for index = 1, #route.points - 1 do
                local a = route.points[index]
                local b = route.points[index + 1]
                local x1, y1 = transform(a.x, a.y)
                local x2, y2 = transform(b.x, b.y)

                pixel.line(
                    x1,
                    y1,
                    x2,
                    y2,
                    lineInfo.colour
                )
            end
        end
    end

    local largeRoundels = width >= 75 and height >= 24

    -- Stations over routes.
    for _, stationId in ipairs(STATION_ORDER) do
        local station = STATIONS[stationId]
        local x, y = transform(station.x, station.y)
        local selected = stationId == selectedStation

        pixel.station(
            x,
            y,
            PALETTE.foreground,
            selected and PALETTE.selected or nil,
            largeRoundels and 3 or 1
        )
    end

    -- Labels last.
    for _, stationId in ipairs(STATION_ORDER) do
        local station = STATIONS[stationId]
        local x, y = transform(station.x, station.y)
        local tx, ty = labelPosition(station, x, y)

        pixel.text(
            tx,
            ty,
            station.name,
            stationId == selectedStation
                and PALETTE.selected
                or PALETTE.secondary,
            PALETTE.background
        )
    end

    if height >= 22 then
        local footer = "You are here: " .. network.getStationName(selectedStation)
        pixel.centerText(
            height,
            footer,
            PALETTE.selectedText,
            PALETTE.background
        )
    end

    return true
end

return network
