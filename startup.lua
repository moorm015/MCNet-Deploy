-- MCNet startup entry

local BOOT_PATH = "kernel/boot.lua"

if not fs.exists(BOOT_PATH) then
    term.clear()
    term.setCursorPos(1, 1)
    print("MCNet boot kernel is missing.")
    print("Run bootstrap to repair the installation.")
    return
end

local completed = shell.run(BOOT_PATH)

if not completed then
    print("")
    print("MCNet closed with an error.")
    print("Run bootstrap to repair or update MCNet.")
end
