-- MCNet keyboard, mouse and monitor-touch menu controller

local module = {}

local function findBackOption(options)
    for _, option in ipairs(options) do
        if option.back or option.exit then
            return option
        end
    end
    return nil
end

local function moveSelection(options, selected, direction)
    if #options == 0 then
        return 1
    end

    local attempts = 0
    repeat
        selected = selected + direction
        if selected < 1 then
            selected = #options
        elseif selected > #options then
            selected = 1
        end
        attempts = attempts + 1
    until not options[selected].disabled or attempts >= #options

    return selected
end

function module.choose(ui, title, options, device, version)
    if type(options) ~= "table" or #options == 0 then
        error("Menu requires at least one option", 0)
    end

    local selected = 1
    local firstVisible = 1

    if options[selected].disabled then
        selected = moveSelection(options, selected, 1)
    end

    while true do
        local startY = ui.drawHeader(title, device, version)
        local layout = ui.getLayout()
        local palette = ui.getPalette()
        local bottom = layout.contentBottom
        local availableRows = math.max(1, bottom - startY + 1)

        if selected < firstVisible then
            firstVisible = selected
        elseif selected >= firstVisible + availableRows then
            firstVisible = selected - availableRows + 1
        end

        local lastVisible = math.min(#options, firstVisible + availableRows - 1)

        for index = firstVisible, lastVisible do
            local option = options[index]
            local row = startY + index - firstVisible
            local label = option.label

            if layout.compact and option.compactLabel then
                label = option.compactLabel
            end

            local numberPrefix = ""
            if index <= 9 then
                numberPrefix = tostring(index) .. ". "
            end

            local pointer = index == selected and "> " or "  "
            local text = pointer .. numberPrefix .. tostring(label)

            if option.disabled then
                ui.writeAt(layout.left, row, ui.clip(text, layout.usableWidth), palette.muted)
            elseif index == selected then
                ui.fillLine(row, palette.accent, layout.left, layout.right)
                ui.writeAt(layout.left, row, ui.clip(text, layout.usableWidth), palette.selectedText, palette.accent)
                ui.resetColours()
            else
                ui.writeAt(layout.left, row, ui.clip(text, layout.usableWidth), palette.foreground)
            end
        end

        if firstVisible > 1 then
            ui.writeAt(layout.right, startY, "^", palette.warning)
        end

        if lastVisible < #options then
            ui.writeAt(layout.right, bottom, "v", palette.warning)
        end

        local selectedOption = options[selected]
        if not layout.compact and selectedOption and selectedOption.description then
            ui.drawFooter(selectedOption.description)
        else
            ui.drawFooter(layout.compact and "Arrows Enter  Q back" or "Arrows/scroll select  Enter/click open  Q back")
        end

        local event = { os.pullEvent() }
        local eventName = event[1]

        if eventName == "key" then
            local key = event[2]

            if key == keys.up then
                selected = moveSelection(options, selected, -1)
            elseif key == keys.down then
                selected = moveSelection(options, selected, 1)
            elseif key == keys.enter then
                if not options[selected].disabled then
                    return options[selected]
                end
            elseif key == keys.q or key == keys.backspace then
                local back = findBackOption(options)
                if back then
                    return back
                end
            end
        elseif eventName == "char" then
            local number = tonumber(event[2])
            if number and options[number] and not options[number].disabled then
                return options[number]
            end
        elseif eventName == "mouse_scroll" then
            local direction = event[2]
            selected = moveSelection(options, selected, direction > 0 and 1 or -1)
        elseif eventName == "mouse_click" or eventName == "monitor_touch" then
            local x = event[3]
            local y = event[4]

            if x >= layout.left and x <= layout.right and y >= startY and y <= bottom then
                local clicked = firstVisible + y - startY
                if options[clicked] and not options[clicked].disabled then
                    selected = clicked
                    return options[selected]
                end
            end
        elseif eventName == "term_resize" or eventName == "monitor_resize" then
            -- The next loop redraws using the new dimensions.
        end
    end
end

return module
