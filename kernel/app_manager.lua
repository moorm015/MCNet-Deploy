-- MCNet application loader and device-role mapper
-- Version 0.9.1

local module = {}

local SYSTEM_CONSOLE =
    "applications/system/console.lua"

local GENERIC_APPLICATION =
    "applications/roles/generic.lua"

local roleApplications = {
    SERVER =
        "applications/roles/server.lua",

    TOWER =
        "applications/roles/tower.lua",

    PDA =
        "applications/roles/pda.lua",

    STATION =
        "applications/roles/station.lua",

    DISPLAY =
        "applications/roles/display.lua",

    ARCHIVE =
        "applications/roles/archive_reader.lua"
}

function module.getSystemConsolePath()
    return SYSTEM_CONSOLE
end

function module.getRolePath(deviceType)
    local normalisedType =
        string.upper(
            tostring(
                deviceType
                or ""
            )
        )

    return roleApplications[normalisedType]
        or GENERIC_APPLICATION
end

function module.choose(
    settings,
    device,
    deviceModule
)
    settings =
        type(settings) == "table"
        and settings
        or {}

    device =
        type(device) == "table"
        and device
        or {}

    if not deviceModule
        or type(deviceModule.isConfigured)
            ~= "function" then

        return SYSTEM_CONSOLE
    end

    if not deviceModule.isConfigured(
        device
    ) then
        return SYSTEM_CONSOLE
    end

    if settings.bootTarget == "role" then
        return module.getRolePath(
            device.type
        )
    end

    return SYSTEM_CONSOLE
end

function module.run(path, context)
    if type(path) ~= "string"
        or path == "" then

        return false,
            "Application path is invalid"
    end

    if not fs.exists(path) then
        return false,
            "Application is missing: "
            .. tostring(path)
    end

    local loaded,
        application =
        pcall(
            dofile,
            path
        )

    if not loaded then
        return false,
            "Could not load "
            .. tostring(path)
            .. ": "
            .. tostring(application)
    end

    if type(application) ~= "table"
        or type(application.run)
            ~= "function" then

        return false,
            "Application has no run function: "
            .. tostring(path)
    end

    local completed,
        reason =
        pcall(
            application.run,
            context
        )

    if not completed then
        return false,
            tostring(reason)
    end

    return true
end

return module