-- MCNet responsive terminal UI

local module = {}

function module.new(themeLibrary, layoutLibrary, logoLibrary)
    local ui = {}
    local settings = {}
    local palette = themeLibrary.get("green")
    local width, height = term.getSize()
    local activeDisplay = "native"
    local nativeTarget = nil

    if term.current then
        nativeTarget = term.current()
    elseif term.native then
        nativeTarget = term.native()
    end

    local function refreshSize()
        width, height = term.getSize()
    end

    local function colourSupported()
        if term.isColor then
            return term.isColor()
        end
        if term.isColour then
            return term.isColour()
        end
        return false
    end

    local function setText(colour)
        if colourSupported() then
            term.setTextColor(colour)
        end
    end

    local function setBackground(colour)
        if colourSupported() then
            term.setBackgroundColor(colour)
        end
    end

    local function restoreNativeTarget()
        if term.redirect and nativeTarget then
            term.redirect(nativeTarget)
        end
        activeDisplay = "native"
        refreshSize()
    end

    local function getPeripheralNames()
        if peripheral.getNames then
            return peripheral.getNames()
        end

        if rs and rs.getSides then
            return rs.getSides()
        end

        return {}
    end

    local function clip(value, maximum)
        local text = tostring(value or "")
        maximum = math.max(0, maximum or width)

        if #text <= maximum then
            return text
        end

        if maximum <= 3 then
            return string.sub(text, 1, maximum)
        end

        return string.sub(text, 1, maximum - 3) .. "..."
    end

    function ui.configure(newSettings)
        settings = newSettings or settings or {}
        palette = themeLibrary.get(settings.theme)
        restoreNativeTarget()

        if settings.display and settings.display ~= "native" then
            local displayName = settings.display
            local peripheralType = peripheral.getType and peripheral.getType(displayName) or nil

            if peripheralType == "monitor" and peripheral.wrap and term.redirect then
                local monitor = peripheral.wrap(displayName)

                if monitor then
                    if monitor.setTextScale then
                        pcall(function()
                            monitor.setTextScale(settings.monitorScale or 1)
                        end)
                    end

                    term.redirect(monitor)
                    activeDisplay = displayName
                    refreshSize()
                    return true
                end
            end

            restoreNativeTarget()
            return false, "Monitor " .. tostring(displayName) .. " is unavailable"
        end

        refreshSize()
        return true
    end

    function ui.restoreNative()
        restoreNativeTarget()
    end

    function ui.getSettings()
        return settings
    end

    function ui.getPalette()
        return palette
    end

    function ui.getSize()
        refreshSize()
        return width, height
    end

    function ui.getLayout()
        refreshSize()
        return layoutLibrary.calculate(width, height, settings.layout, settings.showFooter)
    end

    function ui.isCompact()
        return ui.getLayout().compact
    end

    function ui.getDisplayName()
        return activeDisplay
    end

    function ui.listMonitors()
        local result = {}

        for _, name in ipairs(getPeripheralNames()) do
            local peripheralType = peripheral.getType and peripheral.getType(name) or nil
            if peripheralType == "monitor" then
                table.insert(result, name)
            end
        end

        table.sort(result)
        return result
    end

    function ui.resetColours()
        setBackground(palette.background)
        setText(palette.foreground)
    end

    function ui.clear()
        refreshSize()
        ui.resetColours()
        term.clear()
        term.setCursorPos(1, 1)
    end

    function ui.clip(value, maximum)
        return clip(value, maximum)
    end

    function ui.writeAt(x, y, text, textColour, backgroundColour)
        refreshSize()

        if y < 1 or y > height then
            return
        end

        x = math.max(1, x)
        text = clip(text, math.max(0, width - x + 1))

        if backgroundColour then
            setBackground(backgroundColour)
        end

        if textColour then
            setText(textColour)
        end

        term.setCursorPos(x, y)
        write(text)
    end

    function ui.centreAt(y, text, textColour)
        refreshSize()
        text = clip(text, width)
        local x = math.max(1, math.floor((width - #text) / 2) + 1)
        ui.writeAt(x, y, text, textColour)
    end

    function ui.fillLine(y, backgroundColour, startX, endX)
        refreshSize()
        startX = math.max(1, startX or 1)
        endX = math.min(width, endX or width)

        if y < 1 or y > height or endX < startX then
            return
        end

        setBackground(backgroundColour or palette.background)
        term.setCursorPos(startX, y)
        write(string.rep(" ", endX - startX + 1))
        ui.resetColours()
    end

    function ui.drawFrame()
        local layout = ui.getLayout()
        if not layout.framed then
            return
        end

        ui.writeAt(1, 1, "+" .. string.rep("-", layout.width - 2) .. "+", palette.border)

        for y = 2, layout.height - 1 do
            ui.writeAt(1, y, "|", palette.border)
            ui.writeAt(layout.width, y, "|", palette.border)
        end

        ui.writeAt(1, layout.height, "+" .. string.rep("-", layout.width - 2) .. "+", palette.border)
        ui.resetColours()
    end

    function ui.drawHeader(pageTitle, device, version)
        ui.resetLogo()
        ui.clear()
        local layout = ui.getLayout()
        ui.drawFrame()

        local left = layout.left
        local right = layout.right
        local versionText = "v" .. tostring(version or "")

        if layout.compact then
            ui.writeAt(left, 1, "MCNet", palette.title)
            ui.writeAt(math.max(left, right - #versionText + 1), 1, versionText, palette.muted)
            ui.writeAt(left, 2, clip(pageTitle, layout.usableWidth), palette.foreground)

            local row = 3
            if device then
                local displayName = device.friendlyName
                if not displayName or displayName == "" then
                    displayName = device.systemName or device.address or "Unconfigured"
                end

                ui.writeAt(left, row, clip(displayName, layout.usableWidth), palette.muted)
                row = row + 1

                local addressText = tostring(device.address or "UNKNOWN")
                if settings.showStatus ~= false then
                    addressText = addressText .. "  " .. tostring(device.status or "UNKNOWN")
                end

                ui.writeAt(left, row, clip(addressText, layout.usableWidth), device.address == "UNKNOWN" and palette.warning or palette.success)
                row = row + 1
            end

            ui.writeAt(left, row, string.rep("-", layout.usableWidth), palette.border)
            return row + 1
        end

        ui.writeAt(left, 2, "MCNet Console", palette.title)
        ui.writeAt(math.max(left, right - #versionText + 1), 2, versionText, palette.muted)
        ui.writeAt(left, 3, clip(pageTitle, layout.usableWidth), palette.foreground)
        ui.writeAt(left, 4, string.rep("-", layout.usableWidth), palette.border)

        local row = 5
        if device then
            local displayName = device.friendlyName
            if not displayName or displayName == "" then
                displayName = device.systemName or device.address or "Unconfigured"
            end

            local summary = tostring(displayName) .. "  |  " .. tostring(device.address or "UNKNOWN")
            if settings.showStatus ~= false then
                summary = summary .. "  |  " .. tostring(device.status or "UNKNOWN")
            end

            ui.writeAt(left, row, clip(summary, layout.usableWidth), device.status == "ONLINE" and palette.success or palette.muted)
            row = row + 1
            ui.writeAt(left, row, string.rep("-", layout.usableWidth), palette.border)
            row = row + 1
        end

        return row
    end

    function ui.drawFooter(text)
        local layout = ui.getLayout()
        if settings.showFooter == false then
            return
        end

        ui.fillLine(layout.footerRow, palette.background, layout.left, layout.right)
        ui.writeAt(layout.left, layout.footerRow, clip(text, layout.usableWidth), palette.muted)
    end

    function ui.drawPanel(y, title, lines)
        local layout = ui.getLayout()
        local row = y

        if not layout.compact then
            ui.writeAt(layout.left, row, "[ " .. tostring(title) .. " ]", palette.title)
            row = row + 1
        elseif title then
            ui.writeAt(layout.left, row, tostring(title), palette.title)
            row = row + 1
        end

        for _, line in ipairs(lines or {}) do
            if row > layout.contentBottom then
                break
            end
            ui.writeAt(layout.left, row, clip(line, layout.usableWidth), palette.foreground)
            row = row + 1
        end

        return row
    end

    function ui.drawProgressBar(y, fraction, label)
        refreshSize()
        local layout = ui.getLayout()
        local maximum = layout.compact and 18 or 34
        local barWidth = math.max(8, math.min(maximum, width - 8))
        fraction = math.max(0, math.min(1, tonumber(fraction) or 0))
        local filled = math.floor(barWidth * fraction)
        local x = math.max(1, math.floor((width - barWidth - 2) / 2) + 1)

        if colourSupported() then
            ui.writeAt(x, y, "[", palette.foreground)
            ui.fillLine(y, palette.emptyBar, x + 1, x + barWidth)
            if filled > 0 then
                ui.fillLine(y, palette.accent, x + 1, x + filled)
            end
            ui.writeAt(x + barWidth + 1, y, "]", palette.foreground)
        else
            local bar = "[" .. string.rep("#", filled) .. string.rep("-", barWidth - filled) .. "]"
            ui.writeAt(x, y, bar, palette.foreground)
        end

        ui.centreAt(y + 1, tostring(math.floor(fraction * 100)) .. "%", palette.foreground)

        if label then
            ui.centreAt(y + 3, clip(label, math.max(1, width - 4)), palette.muted)
        end

        ui.resetColours()
    end

    local currentLogo = nil

    function ui.resetLogo()
        currentLogo = nil
    end

    function ui.drawLogo(name, startY)
        local layout = ui.getLayout()

        if not currentLogo then
            currentLogo =
                logoLibrary.choose(
                    name or "random",
                    layout.compact
                )
        end

        local selected = currentLogo

        if not selected then
            return 0, nil
        end

        local row = startY
        local drawn = 0

        for _, line in ipairs(selected.lines) do
            if row > layout.contentBottom - 3 then
                break
            end

            ui.centreAt(
                row,
                line,
                palette.accent
            )

            row = row + 1
            drawn = drawn + 1
        end

        if drawn > 0
            and row <= layout.contentBottom - 2 then
            ui.centreAt(
                row,
                selected.label,
                palette.muted
            )

            drawn = drawn + 1
        end

        return drawn, selected.name
    end

    function ui.spinner(frame)
        local frames = { "|", "/", "-", "\\" }
        local index = ((tonumber(frame) or 1) - 1) % #frames + 1
        return frames[index]
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

            setText(palette.error)
            print("Please enter Y or N.")
            ui.resetColours()
        end
    end

    function ui.readDefault(prompt, default)
        ui.resetColours()

        local layout = ui.getLayout()
        local defaultText = ""

        if default ~= nil then
            defaultText = tostring(default)
        end

        if layout.compact then
            print(
                ui.clip(
                    tostring(prompt),
                    layout.usableWidth
                )
            )

            if defaultText ~= "" then
                setText(palette.muted)
                print(
                    ui.clip(
                        "Current: " .. defaultText,
                        layout.usableWidth
                    )
                )
                ui.resetColours()
            end

            write("> ")
        else
            write(tostring(prompt))

            if defaultText ~= "" then
                setText(palette.muted)
                write(
                    " ["
                    .. defaultText
                    .. "]"
                )
                ui.resetColours()
            end

            write(": ")
        end

        if term.setCursorBlink then
            term.setCursorBlink(true)
        end

        local value = read()

        if term.setCursorBlink then
            term.setCursorBlink(false)
        end

        if value == "" then
            return default
        end

        return value
    end

    function ui.printField(label, value, y, valueColour)
        local layout = ui.getLayout()
        local text = tostring(label) .. ": " .. tostring(value)
        ui.writeAt(layout.left, y, clip(text, layout.usableWidth), valueColour or palette.foreground)
    end

    return ui
end

return module
