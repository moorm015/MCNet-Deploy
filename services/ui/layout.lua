-- MCNet responsive layout calculator

local module = {}

local function chooseMode(width, height, forced)
    if forced == "compact" then
        return "compact"
    end

    if forced == "full" then
        if width >= 60 then
            return "wide"
        end
        return "standard"
    end

    if width < 39 or height < 19 then
        return "compact"
    end

    if width >= 70 and height >= 20 then
        return "wide"
    end

    return "standard"
end

function module.calculate(width, height, forced, showFooter)
    width = math.max(1, tonumber(width) or 1)
    height = math.max(1, tonumber(height) or 1)

    local mode = chooseMode(width, height, forced)
    local compact = mode == "compact"
    local framed = not compact and width >= 24 and height >= 12
    local left = compact and 1 or 3
    local right = compact and width or width - 2
    local footerRows = showFooter == false and 0 or 1
    local footerRow = height

    if framed then
        footerRow = height - 1
    end

    local contentBottom = footerRow - footerRows

    return {
        width = width,
        height = height,
        mode = mode,
        compact = compact,
        wide = mode == "wide",
        framed = framed,
        left = left,
        right = right,
        usableWidth = math.max(1, right - left + 1),
        footerRow = footerRow,
        contentBottom = math.max(1, contentBottom),
        minimumUsable = width >= 18 and height >= 10
    }
end

function module.describe(layout)
    if not layout then
        return "unknown"
    end

    return layout.mode .. " (" .. tostring(layout.width) .. "x" .. tostring(layout.height) .. ")"
end

return module
