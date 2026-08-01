-- MCNet persistent device identity

local module = {}
local PATH = ".mcnet/device.lua"

local deviceTypes = {
    "SERVER",
    "TOWER",
    "PDA",
    "COMPUTER",
    "TRAIN",
    "STATION",
    "POWER",
    "STORAGE",
    "DISPLAY",
    "SECURITY",
    "BUILDING",
    "COMMAND",
    "OBSERVATORY",
    "FACTORY",
    "VILLAGE",
    "TEST",
    "UNKNOWN"
}

local prefixes = {
    SERVER = "SRV",
    TOWER = "TWR",
    PDA = "PDA",
    COMPUTER = "PC",
    TRAIN = "TRN",
    STATION = "STN",
    POWER = "PWR",
    STORAGE = "STR",
    DISPLAY = "DSP",
    SECURITY = "SEC",
    BUILDING = "BLD",
    COMMAND = "CMD",
    OBSERVATORY = "OBS",
    FACTORY = "FAC",
    VILLAGE = "VIL",
    TEST = "TST",
    UNKNOWN = "MCN"
}

local function isDeviceType(value)
    for _, deviceType in ipairs(deviceTypes) do
        if value == deviceType then
            return true
        end
    end
    return false
end

local function cleanIdentifier(value)
    value = string.upper(tostring(value or ""))
    value = string.gsub(value, "%s+", "-")
    value = string.gsub(value, "[^A-Z0-9%-_]", "")
    return value
end

function module.getSuggestedAddress(deviceType)
    deviceType = string.upper(tostring(deviceType or "UNKNOWN"))
    local prefix = prefixes[deviceType] or prefixes.UNKNOWN
    return prefix .. "-" .. string.format("%03d", os.getComputerID())
end

function module.getSuggestedSystemName(deviceType)
    return "MCNET-" .. module.getSuggestedAddress(deviceType)
end

function module.createDefault(version, protocol)
    return {
        address = "UNKNOWN",
        systemName = "MCNET-" .. tostring(os.getComputerID()),
        friendlyName = "",
        name = "",
        type = "UNKNOWN",
        region = "UNKNOWN",
        owner = "MCNet",
        status = "OFFLINE",
        computerID = os.getComputerID(),
        version = version or "UNKNOWN",
        protocol = protocol or 1
    }
end

function module.normalise(config, version, protocol)
    local result = module.createDefault(version, protocol)
    config = config or {}

    for key, value in pairs(config) do
        result[key] = value
    end

    if config.name and not config.friendlyName then
        result.friendlyName = config.name
    end

    result.address = cleanIdentifier(result.address)
    if result.address == "" then
        result.address = "UNKNOWN"
    end

    result.systemName = cleanIdentifier(result.systemName)
    if result.systemName == "" then
        result.systemName = "MCNET-" .. tostring(os.getComputerID())
    end

    result.friendlyName = tostring(result.friendlyName or "")
    result.name = result.friendlyName
    result.type = string.upper(tostring(result.type or "UNKNOWN"))

    if not isDeviceType(result.type) then
        result.type = "UNKNOWN"
    end

    result.region = cleanIdentifier(result.region)
    if result.region == "" then
        result.region = "UNKNOWN"
    end

    result.owner = tostring(result.owner or "MCNet")
    result.status = string.upper(tostring(result.status or "OFFLINE"))

    if result.status ~= "ONLINE" and result.status ~= "OFFLINE" and result.status ~= "MAINTENANCE" then
        result.status = "OFFLINE"
    end

    result.computerID = os.getComputerID()
    result.version = version or result.version or "UNKNOWN"
    result.protocol = protocol or result.protocol or 1

    return result
end

function module.validate(config)
    if type(config) ~= "table" then
        return false, "Configuration must be a table"
    end

    if not config.address or config.address == "" or config.address == "UNKNOWN" then
        return false, "MCNet address must be configured"
    end

    if not config.systemName or config.systemName == "" then
        return false, "System name is required"
    end

    if not isDeviceType(config.type) or config.type == "UNKNOWN" then
        return false, "Device type must be selected"
    end

    return true
end

function module.isConfigured(config)
    local valid = module.validate(config)
    return valid == true
end

function module.getDisplayName(config)
    config = config or {}

    if config.friendlyName and config.friendlyName ~= "" then
        return config.friendlyName
    end

    if config.systemName and config.systemName ~= "" then
        return config.systemName
    end

    return config.address or "Unconfigured Device"
end

function module.load(path, version, protocol)
    path = path or PATH

    if not fs.exists(path) then
        return module.createDefault(version, protocol)
    end

    local loaded, config = pcall(dofile, path)
    if not loaded or type(config) ~= "table" then
        return module.createDefault(version, protocol)
    end

    return module.normalise(config, version, protocol)
end

function module.save(config, path, version, protocol)
    path = path or PATH
    config = module.normalise(config, version, protocol)

    local valid, reason = module.validate(config)
    if not valid then
        return false, reason
    end

    local directory = fs.getDir(path)
    if directory ~= "" and not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local file = fs.open(path, "w")
    if not file then
        return false, "Could not open device configuration file"
    end

    file.write("return ")
    file.write(textutils.serialize(config))
    file.write("\n")
    file.close()
    return true
end

function module.getTypes(includeUnknown)
    local result = {}

    for _, value in ipairs(deviceTypes) do
        if includeUnknown or value ~= "UNKNOWN" then
            table.insert(result, value)
        end
    end

    return result
end

function module.getPath()
    return PATH
end

return module
