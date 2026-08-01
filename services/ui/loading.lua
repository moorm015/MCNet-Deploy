-- MCNet step-based loading screen

local module = {}

function module.new(ui, version, totalSteps, heading)
    local loading = {}
    local current = 0
    totalSteps = math.max(1, tonumber(totalSteps) or 1)
    heading = heading or "MCNet"

    local function draw(label)
        local settings = ui.getSettings()
        local layout = ui.getLayout()
        ui.clear()
        ui.centreAt(1, heading, ui.getPalette().title)
        ui.centreAt(2, "Network Systems " .. tostring(version or ""), ui.getPalette().muted)

        local logoHeight = 0
        if settings.logo ~= "off" then
            logoHeight = ui.drawLogo(settings.logo or "random", 4)
        end

        local y = 5 + logoHeight
        if y > layout.contentBottom - 3 then
            y = math.max(4, layout.contentBottom - 3)
        end

        local fraction = current / totalSteps
        ui.drawProgressBar(y, fraction, ui.spinner(current + 1) .. " " .. tostring(label or "Loading..."))
    end

    function loading.step(label)
        current = math.min(totalSteps, current + 1)
        draw(label)

        if ui.getSettings().animations ~= false then
            sleep(0.08)
        end
    end

    function loading.finish(label)
        current = totalSteps
        draw(label or "Ready")

        if ui.getSettings().animations ~= false then
            sleep(0.18)
        end
    end

    function loading.redraw(label)
        draw(label)
    end

    return loading
end

return module
