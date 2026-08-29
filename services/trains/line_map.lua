-- MCNet station line-map display
-- Version 0.9.6
-- ComputerCraft 1.75 / CraftOS 1.7 compatible.
--
-- This is the CLEAN local diagram intended for ordinary Tube-style stations.
-- It shows ONE served line at a time as a mostly-horizontal strip, using solid
-- colour cells and full station names.
--
-- At interchange stations, served lines rotate automatically every 12 seconds.
--
-- Recommended physical Advanced Monitor:
--     3 blocks wide x 2 blocks high at text scale 0.5
--
-- If you have wall space, 4 x 2 is even better at Central Station because it
-- serves more lines and gives the full names extra breathing room.

local lineMap = {}

local pixel = dofile("services/ui/pixel.lua")
local network = dofile("services/trains/network_map.lua")

local VERSION = "0.9.6"
local ROTATE_SECONDS = 12

local function colour(name, fallback)
    if colors and colors[name] then
        return colors[name]
    end
    return fallback
end

local BLACK = colour("black", 32768)
local WHITE = colour("white", 1)
local LIGHT_GRAY = colour("lightGray", 256)
local GRAY = colour("gray", 128)
local LIME = colour("lime", 32)
local YELLOW = colour("yellow", 16)

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end
    return false
end

local function chooseLine(stationId, requestedLine)
    local lines = network.getStationLines(stationId)

    if #lines == 0 then
        return nil, lines, 0
    end

    if requestedLine and contains(lines, requestedLine) then
        for index, id in ipairs(lines) do
            if id == requestedLine then
                return id, lines, index
            end
        end
    end

    if #lines == 1 then
        return lines[1], lines, 1
    end

    local tick = math.floor(os.clock() / ROTATE_SECONDS)
    local index = (tick % #lines) + 1

    return lines[index], lines, index
end

local function drawConnectionSwatches(stationId, activeLine, x, y)
    local lineIds = network.getStationLines(stationId)
    local swatches = {}

    for _, lineId in ipairs(lineIds) do
        if lineId ~= activeLine then
            swatches[#swatches + 1] = lineId
        end
    end

    if #swatches == 0 then
        return
    end

    local startX = x - math.floor((#swatches - 1) / 2)

    for index, lineId in ipairs(swatches) do
        local info = network.getLine(lineId)

        if info then
            pixel.cell(
                startX + index - 1,
                y,
                info.colour
            )
        end
    end
end

local function labelXForNode(nodeX, label, left, right)
    local x = nodeX - math.floor(#label / 2)

    if x < left then
        x = left
    end

    if x + #label - 1 > right then
        x = right - #label + 1
    end

    return math.max(left, x)
end

local function drawDirectionHints(lineInfo, routeY, left, right)
    if lineInfo.circular then
        pixel.text(
            left,
            routeY - 1,
            "< Anticlockwise",
            LIGHT_GRAY,
            BLACK
        )

        local text = "Clockwise >"
        pixel.text(
            right - #text + 1,
            routeY - 1,
            text,
            LIGHT_GRAY,
            BLACK
        )

        return
    end

    local firstStation = network.getStation(lineInfo.stations[1])
    local lastStation = network.getStation(lineInfo.stations[#lineInfo.stations])

    if firstStation then
        local text = "< " .. firstStation.name
        pixel.text(
            left,
            routeY - 1,
            text,
            LIGHT_GRAY,
            BLACK
        )
    end

    if lastStation then
        local text = lastStation.name .. " >"
        pixel.text(
            right - #text + 1,
            routeY - 1,
            text,
            LIGHT_GRAY,
            BLACK
        )
    end
end

function lineMap.getVersion()
    return VERSION
end

function lineMap.draw(options)
    options = type(options) == "table" and options or {}

    local width, height = term.getSize()
    local stationId = tostring(options.selectedStation or "CENTRAL")

    if width < 38 or height < 12 then
        pixel.centerText(
            math.max(3, math.floor(height / 2)),
            "Line map needs a larger monitor",
            YELLOW,
            BLACK
        )
        return true
    end

    local lineId, servedLines, lineIndex =
        chooseLine(
            stationId,
            options.lineId
        )

    if not lineId then
        pixel.centerText(
            math.max(3, math.floor(height / 2)),
            "No passenger lines configured",
            YELLOW,
            BLACK
        )
        return true
    end

    local lineInfo = network.getLine(lineId)
    local selectedStation = network.getStation(stationId)

    if not lineInfo then
        return false, "Unknown rail line"
    end

    -- Row 1 is the dashboard title written by display.lua.
    local titleY = 2
    local subY = 3

    pixel.text(
        2,
        titleY,
        lineInfo.name,
        lineInfo.colour,
        BLACK
    )

    if selectedStation then
        local stationText = selectedStation.name
        pixel.text(
            width - #stationText,
            titleY,
            stationText,
            WHITE,
            BLACK
        )
    end

    if #servedLines > 1 then
        local rotateText =
            "Line "
            .. tostring(lineIndex)
            .. "/"
            .. tostring(#servedLines)
            .. " - rotates"

        pixel.text(
            2,
            subY,
            rotateText,
            GRAY,
            BLACK
        )
    elseif lineInfo.circular then
        pixel.text(
            2,
            subY,
            "Circle service - both directions",
            GRAY,
            BLACK
        )
    else
        pixel.text(
            2,
            subY,
            "Route diagram",
            GRAY,
            BLACK
        )
    end

    local routeY = math.max(
        8,
        math.floor(height / 2)
    )

    local left = 6
    local right = width - 6
    local routeWidth = right - left

    if routeWidth < 20 then
        left = 3
        right = width - 3
        routeWidth = right - left
    end

    drawDirectionHints(
        lineInfo,
        routeY,
        left,
        right
    )

    local count = #lineInfo.stations
    local nodeXs = {}

    if count == 1 then
        nodeXs[1] = math.floor((left + right) / 2)
    else
        for index = 1, count do
            nodeXs[index] =
                left
                + math.floor(
                    ((index - 1) / (count - 1))
                    * routeWidth
                    + 0.5
                )
        end
    end

    -- Solid route band.
    for index = 1, count - 1 do
        pixel.hLine(
            nodeXs[index],
            nodeXs[index + 1],
            routeY,
            lineInfo.colour
        )
    end

    local useRoundels = height >= 16

    -- Station markers.
    for index, routeStationId in ipairs(lineInfo.stations) do
        local selected = routeStationId == stationId

        pixel.station(
            nodeXs[index],
            routeY,
            WHITE,
            selected and LIME or nil,
            useRoundels and 3 or 1
        )
    end

    -- Full station names alternate above and below the line. This gives the
    -- labels much more room than the complete-network map.
    for index, routeStationId in ipairs(lineInfo.stations) do
        local station = network.getStation(routeStationId)

        if station then
            local above = (index % 2) == 1
            local labelY =
                above
                and (routeY - 3)
                or (routeY + 2)

            local labelX =
                labelXForNode(
                    nodeXs[index],
                    station.name,
                    1,
                    width
                )

            pixel.text(
                labelX,
                labelY,
                station.name,
                routeStationId == stationId
                    and LIME
                    or WHITE,
                BLACK
            )

            -- Tiny solid colour swatches show connections without adding more
            -- text clutter to the route strip.
            drawConnectionSwatches(
                routeStationId,
                lineId,
                nodeXs[index],
                above
                    and (routeY + 2)
                    or (routeY - 2)
            )
        end
    end

    local footerY = height

    if lineInfo.note then
        pixel.centerText(
            footerY,
            lineInfo.note,
            YELLOW,
            BLACK
        )
    elseif #servedLines > 1 then
        pixel.centerText(
            footerY,
            "Other lines at this station are shown automatically",
            LIGHT_GRAY,
            BLACK
        )
    elseif selectedStation then
        pixel.centerText(
            footerY,
            "You are here: " .. selectedStation.name,
            YELLOW,
            BLACK
        )
    end

    return true
end

return lineMap
