-- MCNet Menu Library
-- Version: 0.6.0

local theme = dofile("services/ui/theme.lua")
local ui = dofile("services/ui/ui.lua")

local menu = {}

function menu.choose(title, options, device, version)
    local selected = 1

    while true do
        local startY = ui.drawHeader(title, device, version)
        local screenWidth, screenHeight = ui.getSize()
        local compactMode = ui.isCompact()

        for index, option in ipairs(options) do
            local y = startY + index - 1
            local label = option.label

            if #label > screenWidth - 6 then
                label = string.sub(label, 1, screenWidth - 9) .. "..."
            end

            if index == selected then
                local selectedText = " " .. label .. " "
                local fillWidth = math.min(screenWidth - 4, #selectedText)

                ui.setBackgroundColour(theme.accent)
                ui.setTextColour(theme.selectedText)
                ui.writeAt(3, y, string.sub(selectedText, 1, fillWidth))
                ui.resetColours()
            else
                ui.writeAt(3, y, "  " .. label, theme.foreground)
            end
        end

        local instructionY = math.min(screenHeight, startY + #options + 2)

        ui.writeAt(
            3,
            instructionY,
            compactMode and "Arrows + Enter" or "Up/Down: select   Enter: open",
            theme.muted
        )

        local event = { os.pullEvent() }

        if event[1] == "key" then
            local key = event[2]

            if key == keys.up then
                selected = selected - 1
                if selected < 1 then
                    selected = #options
                end
            elseif key == keys.down then
                selected = selected + 1
                if selected > #options then
                    selected = 1
                end
            elseif key == keys.enter then
                return options[selected]
            elseif key == keys.q or key == keys.backspace then
                for _, option in ipairs(options) do
                    if option.back or option.exit then
                        return option
                    end
                end
            end
        elseif event[1] == "char" then
            local number = tonumber(event[2])

            if number and number >= 1 and number <= #options then
                return options[number]
            end
        elseif event[1] == "mouse_click" then
            local mouseY = event[4]
            local clickedIndex = mouseY - startY + 1

            if clickedIndex >= 1 and clickedIndex <= #options then
                selected = clickedIndex
                return options[selected]
            end
        end
    end
end

return menu
