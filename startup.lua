-- MCNet supervised startup entry
-- Version 0.9.0

local BOOT_PATH = "kernel/boot.lua"
local LOG_PATH = ".mcnet/supervisor.log"

local function appendLog(message)
    if not fs.exists(".mcnet") then fs.makeDir(".mcnet") end
    local file = fs.open(LOG_PATH, "a")
    if file then
        file.writeLine("Day " .. tostring(os.day and os.day() or 0)
            .. " " .. tostring(os.time and os.time() or 0)
            .. " | " .. tostring(message))
        file.close()
    end
end

local failures = 0

while true do
    if not fs.exists(BOOT_PATH) then
        term.clear()
        term.setCursorPos(1, 1)
        print("MCNet boot kernel is missing.")
        print("Run bootstrap to repair the installation.")
        return
    end

    local completed = os.run(getfenv(), BOOT_PATH)
    failures = failures + 1

    if completed then
        appendLog("Kernel exited; supervisor restarting it")
    else
        appendLog("Kernel failed; supervisor restarting it")
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    print("MCNet supervisor")
    print("Restarting MCNet after an unexpected stop...")
    sleep(math.min(10, 2 + failures))
end
