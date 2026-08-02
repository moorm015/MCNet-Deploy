-- MCNet PDA inactivity shutdown manager
-- Version 0.9.0

local module = {}

function module.new(settings, device)
    local manager = {}
    local running = false
    local timeout = tonumber(settings and settings.pdaIdleShutdown) or 300
    local enabled = settings and settings.pdaIdleEnabled ~= false
        and device and device.type == "PDA" and timeout > 0

    function manager.isEnabled() return enabled end

    function manager.run()
        if not enabled then return end
        running = true
        local timer = os.startTimer(timeout)
        while running do
            local event = { os.pullEvent() }
            local name = event[1]
            if name == "timer" and event[2] == timer then
                term.clear()
                term.setCursorPos(1, 1)
                print("MCNet PDA sleeping")
                print("Power on to reconnect and collect messages.")
                sleep(0.5)
                os.shutdown()
            elseif name == "key" or name == "char" or name == "paste"
                or name == "mouse_click" or name == "mouse_scroll"
                or name == "monitor_touch" then
                timer = os.startTimer(timeout)
            end
        end
    end

    function manager.stop() running = false end
    return manager
end

return module
