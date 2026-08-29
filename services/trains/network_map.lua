-- MCNet railway network map renderer
-- Version 0.9.5
-- ComputerCraft 1.75 / CraftOS 1.7 compatible.
--
-- This is the compact, SOLID-line renderer for normal station displays.
-- It keeps full station names and follows the approved schematic:
--
--   * Yellow Circle Line forms the tilted diamond/parallelogram.
--   * Pink Honey Line runs parallel outside the left/bottom edge and
--     BYPASSES Atoll Island.
--   * Blue + Green + Yellow share the Central -> Laboratories corridor.
--   * Blue branches first to Spa Village -> New Egypt.
--   * Green continues beside Yellow and branches second to
--     Half-Wall -> Eastern Village.
--   * Yellow alone continues to Laboratories.
--   * Red Electric Line runs ACME -> Central Station.
--   * Orange Little Mexico route runs Eastern Village -> Little Mexico.
--
-- Route lines are drawn as SOLID coloured background cells. At monitor text
-- scale 0.5, one cell is the minimum true solid thickness available in classic
-- ComputerCraft. Clarity comes from layout, spacing and compact station markers.

local map = {}

local VERSION = "0.9.5"
local REF_W = 1200
local REF_H = 520

local function ccColour(name, fallback)
    if colors and colors[name] then
        return colors[name]
    end
    return fallback
end

local BLACK = ccColour("black", 32768)
local WHITE = ccColour("white", 1)
local LIGHT_GRAY = ccColour("lightGray", 256)
local LIME = ccColour("lime", 32)
local YELLOW = ccColour("yellow", 16)

local LINES = {
    CIRCLE = {
        id = "CIRCLE",
        name = "Circle Line",
        legend = "Circle",
        colour = ccColour("yellow", 16)
    },
    HONEY_LINE = {
        id = "HONEY_LINE",
        name = "Honey Line",
        legend = "Honey",
        colour = ccColour("pink", 64)
    },
    CENTRAL_LINE = {
        id = "CENTRAL_LINE",
        name = "Central Line",
        legend = "Central",
        colour = ccColour("lightBlue", 8)
    },
    EASTERN_LINE = {
        id = "EASTERN_LINE",
        name = "Eastern Line",
        legend = "Eastern",
        colour = ccColour("lime", 32)
    },
    LITTLE_MEXICO_EXPRESS = {
        id = "LITTLE_MEXICO_EXPRESS",
        name = "Little Mexico Express",
        legend = "Mexico",
        colour = ccColour("orange", 2)
    },
    ACME_ELECTRIC = {
        id = "ACME_ELECTRIC",
        name = "Electric Line",
        legend = "Electric",
        colour = ccColour("red", 16384)
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

-- The labels deliberately leave more margin than v0.9.3 so full station names
-- remain readable on a normal 3x2/large station monitor.
local STATIONS = {
    ACME_ESC = {
        id = "ACME_ESC",
        name = "ACME",
        x = 70, y = 65,
        terminus = true,
        label = { anchor = "right", dx = 2, dy = -1 }
    },
    BEE_GARDENS = {
        id = "BEE_GARDENS",
        name = "Bee Gardens",
        x = 260, y = 150,
        interchange = true,
        label = { anchor = "left", dx = -2, dy = -1 }
    },
    CENTRAL = {
        id = "CENTRAL",
        name = "Central Station",
        x = 600, y = 150,
        interchange = true,
        label = { anchor = "right", dx = 2, dy = -1 }
    },
    ATOLL_REEF = {
        id = "ATOLL_REEF",
        name = "Atoll Island",
        x = 170, y = 430,
        label = { anchor = "left", dx = -2, dy = 1 }
    },
    LABORATORIES = {
        id = "LABORATORIES",
        name = "Laboratories",
        x = 480, y = 430,
        interchange = true,
        label = { anchor = "right", dx = 2, dy = 1 }
    },
    THE_SPA = {
        id = "THE_SPA",
        name = "Spa Village",
        x = 760, y = 235,
        label = { anchor = "below", dx = 0, dy = 1 }
    },
    NEW_EGYPT = {
        id = "NEW_EGYPT",
        name = "New Egypt",
        x = 1020, y = 235,
        terminus = true,
        label = { anchor = "right", dx = 2, dy = 0 }
    },
    HALF_WALL = {
        id = "HALF_WALL",
        name = "Half-Wall",
        x = 710, y = 335,
        label = { anchor = "above", dx = 0, dy = -1 }
    },
    EASTERN_VILLAGE = {
        id = "EASTERN_VILLAGE",
        name = "Eastern Village",
        x = 900, y = 335,
        interchange = true,
        label = { anchor = "right", dx = 2, dy = 0 }
    },
    LITTLE_MEXICO = {
        id = "LITTLE_MEXICO",
        name = "Little Mexico",
        x = 1020, y = 455,
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

-- Yellow centre-line points on the Central -> Laboratories side.
local P = {
    SPA_Y = { x = 564, y = 234 },
    EAST_Y = { x = 522, y = 332 },

    -- Green sits immediately to the outside/right of Yellow.
    SPA_G = { x = 586, y = 240 },
    EAST_G = { x = 544, y = 338 },

    -- Blue is the outermost shared route and leaves first.
    SPA_B = { x = 608, y = 246 },

    -- Fan-out points make the three lines visibly separate just below Central.
    GREEN_FAN = { x = 606, y = 178 },
    BLUE_FAN = { x = 626, y = 184 },

    -- Honey is outside the Circle line and deliberately misses Atoll.
    HONEY_TOP = { x = 242, y = 176 },
    HONEY_LEFT = { x = 132, y = 414 },
    HONEY_BYPASS = { x = 132, y = 466 },
    HONEY_BOTTOM_L = { x = 195, y = 470 },
    HONEY_BOTTOM_R = { x = 445, y = 470 },

    -- Electric route follows the user's horizontal top line then drops to Central.
    ELECTRIC_BEND = { x = 590, y = 65 },

    -- Little Mexico keeps the angled-down then horizontal shape.
    MEXICO_BEND = { x = 850, y = 455 }
}

local function stationPoint(id)
    local s = STATIONS[id]
    return { x = s.x, y = s.y }
end

local ROUTES = {
    {
        line = "CIRCLE",
        points = {
            stationPoint("BEE_GARDENS"),
            stationPoint("CENTRAL"),
            P.SPA_Y,
            P.EAST_Y,
            stationPoint("LABORATORIES"),
            stationPoint("ATOLL_REEF"),
            stationPoint("BEE_GARDENS")
        }
    },
    {
        line = "HONEY_LINE",
        points = {
            stationPoint("BEE_GARDENS"),
            P.HONEY_TOP,
            P.HONEY_LEFT,
            P.HONEY_BYPASS,
            P.HONEY_BOTTOM_L,
            P.HONEY_BOTTOM_R,
            stationPoint("LABORATORIES")
        }
    },
    {
        line = "CENTRAL_LINE",
        points = {
            stationPoint("CENTRAL"),
            P.BLUE_FAN,
            P.SPA_B,
            { x = 665, y = 246 },
            stationPoint("THE_SPA"),
            stationPoint("NEW_EGYPT")
        }
    },
    {
        line = "EASTERN_LINE",
        points = {
            stationPoint("CENTRAL"),
            P.GREEN_FAN,
            P.SPA_G,
            P.EAST_G,
            { x = 600, y = 338 },
            stationPoint("HALF_WALL"),
            stationPoint("EASTERN_VILLAGE")
        }
    },
    {
        line = "LITTLE_MEXICO_EXPRESS",
        points = {
            stationPoint("EASTERN_VILLAGE"),
            P.MEXICO_BEND,
            stationPoint("LITTLE_MEXICO")
        }
    },
    {
        line = "ACME_ELECTRIC",
        points = {
            stationPoint("ACME_ESC"),
            P.ELECTRIC_BEND,
            stationPoint("CENTRAL")
        }
    }
}

local function setText(colour)
    if term.setTextColor then
        term.setTextColor(colour)
    else
        term.setTextColour(colour)
    end
end

local function setBackground(colour)
    if term.setBackgroundColor then
        term.setBackgroundColor(colour)
    else
        term.setBackgroundColour(colour)
    end
end

local function safeWrite(value)
    term.write(tostring(value or ""))
end

local function writeAt(x, y, text, colour)
    local w, h = term.getSize()
    x = math.floor(tonumber(x) or 1)
    y = math.floor(tonumber(y) or 1)
    text = tostring(text or "")

    if y < 1 or y > h or text == "" then
        return
    end

    if x < 1 then
        text = string.sub(text, 2 - x)
        x = 1
    end

    if x > w or text == "" then
        return
    end

    if #text > (w - x + 1) then
        text = string.sub(text, 1, w - x + 1)
    end

    setBackground(BLACK)
    setText(colour or WHITE)
    term.setCursorPos(x, y)
    safeWrite(text)
end

-- Draw one SOLID coloured route segment.
--
-- ComputerCraft monitors render background colour per whole character cell.
-- At text scale 0.5, one cell is the thinnest true solid line available.
-- The important improvement over v0.9.3 is therefore not "half a cell"
-- thickness (which classic ComputerCraft cannot do), but cleaner geometry,
-- smaller markers and more separation between parallel route lanes.
local function paintCell(x, y, colour)
    local w, h = term.getSize()

    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)

    if x < 1 or x > w or y < 1 or y > h then
        return
    end

    setBackground(colour)
    setText(colour)
    term.setCursorPos(x, y)
    safeWrite(" ")
end

local function drawSolidSegment(x1, y1, x2, y2, colour)
    x1 = math.floor(x1)
    y1 = math.floor(y1)
    x2 = math.floor(x2)
    y2 = math.floor(y2)

    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy
    local x, y = x1, y1

    while true do
        paintCell(x, y, colour)

        if x == x2 and y == y2 then
            break
        end

        local e2 = 2 * err

        if e2 > -dy then
            err = err - dy
            x = x + sx
        end

        if e2 < dx then
            err = err + dx
            y = y + sy
        end
    end
end

local function drawRoute(route, transform)
    local info = LINES[route.line]
    if not info then
        return
    end

    for i = 1, #route.points - 1 do
        local a = route.points[i]
        local b = route.points[i + 1]
        local x1, y1 = transform(a.x, a.y)
        local x2, y2 = transform(b.x, b.y)

        drawSolidSegment(x1, y1, x2, y2, info.colour)
    end
end

local function drawStation(station, x, y, selected)
    -- Keep stations deliberately compact: one solid cell. Interchanges and
    -- termini remain visually identifiable from the network topology and
    -- labels, while the selected station is highlighted lime.
    paintCell(
        x,
        y,
        selected and LIME or WHITE
    )
end

local function drawLabel(station, x, y, selected)
    local cfg = station.label or {}
    local anchor = cfg.anchor or "right"
    local dx = tonumber(cfg.dx) or 0
    local dy = tonumber(cfg.dy) or 0
    local label = station.name
    local tx = x + dx
    local ty = y + dy

    if anchor == "left" then
        tx = x - #label + dx
    elseif anchor == "above" then
        tx = x - math.floor(#label / 2) + dx
        ty = y - 1 + dy
    elseif anchor == "below" then
        tx = x - math.floor(#label / 2) + dx
        ty = y + 1 + dy
    end

    writeAt(
        tx,
        ty,
        label,
        selected and LIME or LIGHT_GRAY
    )
end

local function drawLegend(row, width)
    if width < 44 then
        return 0
    end

    local x = 2
    local y = row
    local rows = 1

    for _, id in ipairs(LINE_ORDER) do
        local info = LINES[id]
        local label = info.legend
        local needed = #label + 5

        if x + needed > width then
            x = 2
            y = y + 1
            rows = rows + 1
        end

        -- A single filled cell makes a clean colour swatch.
        setBackground(info.colour)
        term.setCursorPos(x, y)
        safeWrite(" ")

        setBackground(BLACK)
        writeAt(x + 2, y, label, LIGHT_GRAY)
        x = x + needed
    end

    return rows
end

function map.getVersion()
    return VERSION
end

function map.getStation(id)
    return STATIONS[tostring(id or "")]
end

function map.getLine(id)
    return LINES[tostring(id or "")]
end

function map.draw(options)
    options = type(options) == "table" and options or {}

    local width, height = term.getSize()

    if width < 30 or height < 12 then
        return false, "Monitor too small for rail map"
    end

    local selected = tostring(options.selectedStation or "CENTRAL")

    local legendRows = 0
    if options.showLegend ~= false and height >= 16 then
        legendRows = drawLegend(2, width)
    end

    local top = legendRows > 0 and (3 + legendRows) or 2
    local bottom = height - 2
    local left = 2
    local right = width - 2

    if bottom - top < 7 then
        top = 2
        bottom = height - 1
    end

    local usableW = math.max(1, right - left)
    local usableH = math.max(1, bottom - top)

    local function transform(mx, my)
        local x = left + math.floor((mx / REF_W) * usableW)
        local y = top + math.floor((my / REF_H) * usableH)
        return x, y
    end

    -- Routes first.
    for _, route in ipairs(ROUTES) do
        drawRoute(route, transform)
    end

    -- Station markers second.
    for _, id in ipairs(STATION_ORDER) do
        local station = STATIONS[id]
        local x, y = transform(station.x, station.y)
        drawStation(station, x, y, id == selected)
    end

    -- Full station names last so route strokes cannot overwrite them.
    for _, id in ipairs(STATION_ORDER) do
        local station = STATIONS[id]
        local x, y = transform(station.x, station.y)
        drawLabel(station, x, y, id == selected)
    end

    if height >= 14 then
        local station = STATIONS[selected]
        local name = station and station.name or selected
        local footer = "You are here: " .. name
        local fx = math.max(1, math.floor((width - #footer) / 2) + 1)

        writeAt(fx, height, footer, YELLOW)
    end

    setBackground(BLACK)
    setText(WHITE)

    return true
end

return map
