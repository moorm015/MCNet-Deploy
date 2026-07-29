--[[
    MCNet Device Configuration
    Version: 0.1.0

    Loads, validates and saves the local MCNet device identity.
]]

local packet = dofile("services/communications/packet.lua")

local deviceConfig = {}

deviceConfig.DEFAULT_PATH = ".mcnet/device.lua"

deviceConfig.TYPE = {
    UNKNOWN = "UNKNOWN",
    TOWER = "TOWER",
    PDA = "PDA",
    TRAIN = "TRAIN",
    STATION = "STATION",
    POWER = "POWER",
    STORAGE = "STORAGE",
    DISPLAY = "DISPLAY",
    SECURITY = "SECURITY",
    BUILDING = "BUILDING",
    SERVER = "SERVER",
    TEST = "TEST"
}

deviceConfig.STATUS = {
    ONLINE = "ONLINE",
    OFFLINE = "OFFLINE",
    MAINTENANCE = "MAINTENANCE"
}

local function isNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function normalise(value)
    if type(value) ~= "string" then
        return value
    end

    return string.upper(value)
end

local function copyTable(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

-- Returns a new default device record.

function deviceConfig.createDefault()
    return {
        address = "UNKNOWN",
        name = "Unconfigured Device",
        type = deviceConfig.TYPE.UNKNOWN,
        region = "UNKNOWN",
        owner = "MCNet",
        status = deviceConfig.STATUS.OFFLINE,
        computerID = os.getComputerID(),
        version = "0.4.0"
    }
end

-- Normalises fields which use fixed upper-case values.

function deviceConfig.normalise(config)
    if type(config) ~= "table" then
        return config
    end

    local result = copyTable(config)

    result.address = normalise(result.address)
    result.type = normalise(result.type)
    result.region = normalise(result.region)
    result.status = normalise(result.status)

    return result
end

-- Validates an MCNet device record.

function deviceConfig.validate(config)
    if type(config) ~= "table" then
        return false, "Device configuration must be a table"
    end

    local validAddress, addressReason =
        packet.validateAddress(config.address)

    if not validAddress then
        return false,
            "Invalid device address: "
            .. tostring(addressReason)
    end

    if not isNonEmptyString(config.name) then
        return false, "Friendly name must be a non-empty string"
    end

    if not isNonEmptyString(config.type) then
        return false, "Device type must be a non-empty string"
    end

    if config.type ~= string.upper(config.type) then
        return false, "Device type must be upper case"
    end

    if not isNonEmptyString(config.region) then
        return false, "Region must be a non-empty string"
    end

    if config.region ~= string.upper(config.region) then
        return false, "Region must be upper case"
    end

    if not isNonEmptyString(config.owner) then
        return false, "Owner must be a non-empty string"
    end

    if not isNonEmptyString(config.status) then
        return false, "Status must be a non-empty string"
    end

    if config.status ~= string.upper(config.status) then
        return false, "Status must be upper case"
    end

    if type(config.computerID) ~= "number" then
        return false, "Computer ID must be a number"
    end

    if not isNonEmptyString(config.version) then
        return false, "Software version must be a non-empty string"
    end

    return true
end

-- Returns true when a configuration file exists.

function deviceConfig.exists(path)
    path = path or deviceConfig.DEFAULT_PATH

    return fs.exists(path) and not fs.isDir(path)
end

-- Saves a device configuration.
--
-- The optional path exists mainly for automated testing.

function deviceConfig.save(config, path)
    path = path or deviceConfig.DEFAULT_PATH

    config = deviceConfig.normalise(config)

    local valid, reason = deviceConfig.validate(config)

    if not valid then
        return false, reason
    end

    local directory = fs.getDir(path)

    if directory ~= "" and not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local temporaryPath = path .. ".tmp"

    if fs.exists(temporaryPath) then
        fs.delete(temporaryPath)
    end

    local file = fs.open(temporaryPath, "w")

    if not file then
        return false, "Could not open configuration file for writing"
    end

    file.write("return ")
    file.write(textutils.serialize(config))
    file.write("\n")
    file.close()

    if fs.exists(path) then
        fs.delete(path)
    end

    fs.move(temporaryPath, path)

    return true
end

-- Loads an existing configuration.
--
-- If no configuration exists, a default record is returned with
-- a second return value of "missing".

function deviceConfig.load(path)
    path = path or deviceConfig.DEFAULT_PATH

    if not deviceConfig.exists(path) then
        return deviceConfig.createDefault(), "missing"
    end

    local success, loaded = pcall(dofile, path)

    if not success then
        return nil,
            "Could not load device configuration: "
            .. tostring(loaded)
    end

    loaded = deviceConfig.normalise(loaded)

    local valid, reason = deviceConfig.validate(loaded)

    if not valid then
        return nil,
            "Invalid device configuration: "
            .. tostring(reason)
    end

    return loaded
end

-- Creates the default configuration only when one does not already exist.

function deviceConfig.initialise(path)
    path = path or deviceConfig.DEFAULT_PATH

    if deviceConfig.exists(path) then
        return true, "existing"
    end

    local config = deviceConfig.createDefault()
    local saved, reason = deviceConfig.save(config, path)

    if not saved then
        return false, reason
    end

    return true, "created"
end

-- Returns the configured logical address.

function deviceConfig.getAddress(path)
    local config, reason = deviceConfig.load(path)

    if not config then
        return nil, reason
    end

    return config.address
end

return deviceConfig