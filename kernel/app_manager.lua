-- MCNet application loader and device-role mapper

local module = {}
local SYSTEM_CONSOLE = "applications/system/console.lua"

local roleApplications = {
    PDA = "applications/roles/pda.lua",
    STATION = "applications/roles/station.lua",
    TOWER = "applications/roles/tower.lua"
}

function module.getSystemConsolePath()
    return SYSTEM_CONSOLE
end

function module.getRolePath(deviceType)
    return roleApplications[deviceType] or "applications/roles/generic.lua"
end

function module.choose(settings, device, deviceModule)
    if not deviceModule.isConfigured(device) then
        return SYSTEM_CONSOLE
    end

    if settings.bootTarget == "role" then
        return module.getRolePath(device.type)
    end

    return SYSTEM_CONSOLE
end

function module.run(path, context)
    if not fs.exists(path) then
        return false, "Application is missing: " .. tostring(path)
    end

    local loaded, application = pcall(dofile, path)
    if not loaded then
        return false, "Could not load " .. tostring(path) .. ": " .. tostring(application)
    end

    if type(application) ~= "table" or type(application.run) ~= "function" then
        return false, "Application has no run function: " .. tostring(path)
    end

    local completed, reason = pcall(application.run, context)
    if not completed then
        return false, tostring(reason)
    end

    return true
end

return module
