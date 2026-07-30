-- MCNet UI Library
-- Version: 0.6.0

local theme = dofile("services/ui/theme.lua")

local ui = {}

local screenWidth, screenHeight = term.getSize()
local compactMode = screenWidth < 40

local supportsColour = false
if term.isColor then
    supportsColour = term.isColor()
elseif term.isColour then
    supportsColour = term.isColour()
end

function ui.refreshSize()
    screenWidth, screenHeight = term.getSize()
    compactMode = screenWidth < 40
end

function ui.getSize()
    return screenWidth, screenHeight
end

function ui.isCompact()
    return compactMode
end

function ui.supportsColour()
    return supportsColour
end

function ui.setTextColour(colour)
    if supportsColour then
        term.setTextColor(colour)
    end
end

function ui.setBackgroundColour(colour)
    if supportsColour then
        term.setBackgroundColor(colour)
    end
end

function ui.resetColours()
    ui.setBackgroundColour(theme.background)
    ui.setTextColour(theme.foreground)
end

function ui.clear()
    ui.refreshSize()
    ui.resetColours()
    term.clear()
    term.setCursorPos(1, 1)
end

function ui.centreX(text)
    return math.max(1, math.floor((screenWidth - #text) / 2) + 1)
end

function ui.writeAt(x, y, text, colour, background)
    if y < 1 or y > screenHeight then
        return
    end

    if x < 1 then
        x = 1
    end

    term.setCursorPos(x, y)

    if background then
        ui.setBackgroundColour(background)
    end

    if colour then
        ui.setTextColour(colour)
    end

    write(tostring(text))
end

function ui.centreAt(y, text, colour)
    ui.writeAt(ui.centreX(text), y, text, colour)
end

local creeperLogo = {
    "  ########  ",
    " ########## ",
    " ########## ",
    " ##  ##  ## ",
    " ##  ##  ## ",
    " ########## ",
    " ####  #### ",
    " ###    ### ",
    " ### ## ### "
}

function ui.drawCreeper(startY)
    for index, line in ipairs(creeperLogo) do
        ui.centreAt(startY + index - 1, line, theme.accent)
    end
end

function ui.drawProgressBar(y, progress, label)
    local maximumBarWidth = compactMode and 20 or 34
    local barWidth = math.min(maximumBarWidth, screenWidth - 8)

    if barWidth < 8 then
        barWidth = 8
    end

    progress = math.max(0, math.min(1, progress))

    local filled = math.floor(barWidth * progress)
    local empty = barWidth - filled

    local bar =
        "["
        .. string.rep("=", filled)
        .. string.rep(" ", empty)
        .. "]"

    local percentage = tostring(math.floor(progress * 100)) .. "%"

    ui.centreAt(y, bar, theme.accent)
    ui.centreAt(y + 1, percentage, theme.foreground)

    if label then
        local displayLabel = tostring(label)
        if #displayLabel > screenWidth - 4 then
            displayLabel = string.sub(displayLabel, 1, screenWidth - 7) .. "..."
        end
        ui.centreAt(y + 3, displayLabel, theme.muted)
    end
end

function ui.transition(label, duration)
    duration = duration or 0.45

    ui.clear()

    ui.centreAt(1, "MCNet", theme.title)
    ui.centreAt(2, "Network Systems Console", theme.muted)

    if compactMode then
        ui.centreAt(5, "[ MCNET ]", theme.accent)
    else
        ui.drawCreeper(4)
    end

    local barY
    if compactMode then
        barY = math.min(screenHeight - 4, 9)
    else
        barY = math.min(screenHeight - 4, 14)
    end

    local steps = 24

    for step = 0, steps do
        local progress = step / steps

        ui.drawProgressBar(
            barY,
            progress,
            label or "Loading..."
        )

        local delay = duration / steps

        if step == 7 or step == 16 then
            delay = delay * 2.8
        elseif step == 12 then
            delay = delay * 1.8
        end

        sleep(delay)
    end
end

function ui.drawHeader(pageTitle, device, version)
    ui.clear()

    local titleText = compactMode and "MCNet" or "MCNet Console"
    ui.centreAt(1, titleText, theme.title)
    ui.centreAt(2, string.rep("=", #titleText), theme.accent)

    if version then
        local versionText = "v" .. tostring(version)
        ui.writeAt(
            math.max(1, screenWidth - #versionText + 1),
            1,
            versionText,
            theme.muted
        )
    end

    ui.writeAt(2, 4, pageTitle, theme.foreground)

    if device then
        local address = device.address or "UNKNOWN"
        local name = device.name or "Unconfigured Device"
        local status = device.status or "UNKNOWN"

        if compactMode then
            local shortName = name
            if #shortName > screenWidth - 10 then
                shortName = string.sub(shortName, 1, screenWidth - 13) .. "..."
            end

            ui.writeAt(2, 6, "Device: " .. shortName, theme.muted)
            ui.writeAt(
                2,
                7,
                "Addr: " .. address,
                address == "UNKNOWN" and theme.highlight or theme.success
            )
            ui.writeAt(
                2,
                8,
                "Status: " .. status,
                status == "ONLINE" and theme.success or theme.muted
            )

            return 10
        end

        ui.writeAt(2, 6, "Device : " .. name, theme.muted)
        ui.writeAt(
            2,
            7,
            "Address: " .. address,
            address == "UNKNOWN" and theme.highlight or theme.success
        )
        ui.writeAt(
            2,
            8,
            "Status : " .. status,
            status == "ONLINE" and theme.success or theme.muted
        )

        return 10
    end

    return 6
end

function ui.drawFooter(text)
    ui.resetColours()
    ui.writeAt(2, screenHeight, text, theme.muted)
end

function ui.pause(message)
    ui.resetColours()
    print("")
    write(message or "Press Enter to continue...")
    read()
end

function ui.askYesNo(question)
    while true do
        write(question .. " (Y/N): ")

        local answer = string.lower(read())

        if answer == "y" or answer == "yes" then
            return true
        end

        if answer == "n" or answer == "no" then
            return false
        end

        ui.setTextColour(theme.error)
        print("Please enter Y or N.")
        ui.setTextColour(theme.foreground)
    end
end

function ui.readDefault(prompt, default)
    write(prompt)

    if default and default ~= "" then
        ui.setTextColour(theme.muted)
        write(" [" .. tostring(default) .. "]")
        ui.setTextColour(theme.foreground)
    end

    write(": ")

    local value = read()

    if value == "" then
        return default
    end

    return value
end

return ui
