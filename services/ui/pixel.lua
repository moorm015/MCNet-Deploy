-- MCNet pixel drawing helpers
-- Version 0.9.6
-- ComputerCraft 1.75 / CraftOS 1.7 compatible.
--
-- Small reusable primitives for colour-cell artwork on Advanced Monitors.
-- A monitor "pixel" here is one terminal character cell whose background is
-- painted a solid colour. This is the same foundation we can later reuse for
-- loading bars, trains, mobs, network diagrams and other MCNet pixel art.

local pixel = {}

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

function pixel.size()
    return term.getSize()
end

function pixel.setColours(foreground, background)
    if background then
        setBackground(background)
    end
    if foreground then
        setText(foreground)
    end
end

function pixel.clear(background)
    background = background or colors.black
    setBackground(background)
    term.clear()
end

function pixel.cell(x, y, colour)
    local width, height = term.getSize()

    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)

    if x < 1 or x > width or y < 1 or y > height then
        return
    end

    setBackground(colour)
    setText(colour)
    term.setCursorPos(x, y)
    term.write(" ")
end

function pixel.text(x, y, value, foreground, background)
    local width, height = term.getSize()

    x = math.floor(tonumber(x) or 1)
    y = math.floor(tonumber(y) or 1)
    value = tostring(value or "")

    if y < 1 or y > height or value == "" then
        return
    end

    if x < 1 then
        value = string.sub(value, 2 - x)
        x = 1
    end

    if x > width or value == "" then
        return
    end

    local available = width - x + 1
    if #value > available then
        value = string.sub(value, 1, available)
    end

    setBackground(background or colors.black)
    setText(foreground or colors.white)
    term.setCursorPos(x, y)
    term.write(value)
end

function pixel.centerText(y, value, foreground, background, left, right)
    local width = term.getSize()

    value = tostring(value or "")
    left = math.floor(tonumber(left) or 1)
    right = math.floor(tonumber(right) or width)

    local area = math.max(1, right - left + 1)
    local x = left + math.floor((area - #value) / 2)

    pixel.text(x, y, value, foreground, background)
end

function pixel.hLine(x1, x2, y, colour)
    x1 = math.floor(x1)
    x2 = math.floor(x2)

    if x2 < x1 then
        x1, x2 = x2, x1
    end

    for x = x1, x2 do
        pixel.cell(x, y, colour)
    end
end

function pixel.vLine(x, y1, y2, colour)
    y1 = math.floor(y1)
    y2 = math.floor(y2)

    if y2 < y1 then
        y1, y2 = y2, y1
    end

    for y = y1, y2 do
        pixel.cell(x, y, colour)
    end
end

function pixel.line(x1, y1, x2, y2, colour)
    x1 = math.floor(x1)
    y1 = math.floor(y1)
    x2 = math.floor(x2)
    y2 = math.floor(y2)

    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy
    local x = x1
    local y = y1

    while true do
        pixel.cell(x, y, colour)

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

function pixel.rect(x1, y1, x2, y2, colour)
    x1 = math.floor(x1)
    y1 = math.floor(y1)
    x2 = math.floor(x2)
    y2 = math.floor(y2)

    if x2 < x1 then
        x1, x2 = x2, x1
    end

    if y2 < y1 then
        y1, y2 = y2, y1
    end

    for y = y1, y2 do
        pixel.hLine(x1, x2, y, colour)
    end
end

function pixel.frame(x1, y1, x2, y2, colour)
    pixel.hLine(x1, x2, y1, colour)
    pixel.hLine(x1, x2, y2, colour)
    pixel.vLine(x1, y1, y2, colour)
    pixel.vLine(x2, y1, y2, colour)
end

-- Compact tube-map station marker.
-- size=1: one solid square
-- size=3: a small white/selected ring with black centre
function pixel.station(x, y, ringColour, selectedColour, size)
    size = tonumber(size) or 1
    ringColour = ringColour or colors.white

    if size < 3 then
        pixel.cell(x, y, selectedColour or ringColour)
        return
    end

    pixel.cell(x, y - 1, ringColour)
    pixel.cell(x - 1, y, ringColour)
    pixel.cell(x + 1, y, ringColour)
    pixel.cell(x, y + 1, ringColour)
    pixel.cell(x, y, selectedColour or colors.black)
end

-- Filled progress bar, reusable by the future loading-screen redesign.
function pixel.progressBar(x, y, width, percent, fillColour, emptyColour)
    width = math.max(1, math.floor(tonumber(width) or 1))
    percent = math.max(0, math.min(1, tonumber(percent) or 0))

    local filled = math.floor((width * percent) + 0.5)

    for i = 0, width - 1 do
        pixel.cell(
            x + i,
            y,
            i < filled and fillColour or (emptyColour or colors.gray)
        )
    end
end

return pixel
