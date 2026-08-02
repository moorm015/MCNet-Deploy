-- MCNet core-service configuration
-- Version 0.9.0

local module = {}
local PATH = ".mcnet/core.lua"

local defaults = {
    coreAddress = "SRV-001",
    heartbeatInterval = 8,
    snapshotInterval = 12,
    onlineTimeout = 28,
    mailboxRetryInterval = 6,
    mailboxRetention = 120,
    maxMailbox = 500,
    maxEvents = 300
}

local function copyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

local function numberInRange(value, fallback, minimum, maximum)
    value = tonumber(value) or fallback
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function cleanAddress(value)
    value = string.upper(tostring(value or ""))
    value = string.gsub(value, "%s+", "-")
    value = string.gsub(value, "[^A-Z0-9%-_]", "")
    if value == "" then value = defaults.coreAddress end
    return value
end

function module.default()
    return copyTable(defaults)
end

function module.normalise(config)
    local result = module.default()
    for key, value in pairs(config or {}) do
        result[key] = value
    end

    result.coreAddress = cleanAddress(result.coreAddress)
    result.heartbeatInterval = numberInRange(result.heartbeatInterval, defaults.heartbeatInterval, 3, 120)
    result.snapshotInterval = numberInRange(result.snapshotInterval, defaults.snapshotInterval, 5, 180)
    result.onlineTimeout = numberInRange(result.onlineTimeout, defaults.onlineTimeout, 10, 600)
    result.mailboxRetryInterval = numberInRange(result.mailboxRetryInterval, defaults.mailboxRetryInterval, 2, 120)
    result.mailboxRetention = numberInRange(result.mailboxRetention, defaults.mailboxRetention, 30, 3600)
    result.maxMailbox = math.floor(numberInRange(result.maxMailbox, defaults.maxMailbox, 10, 5000))
    result.maxEvents = math.floor(numberInRange(result.maxEvents, defaults.maxEvents, 20, 2000))
    return result
end

function module.load(path)
    path = path or PATH
    if not fs.exists(path) then return module.default() end
    local loaded, value = pcall(dofile, path)
    if not loaded or type(value) ~= "table" then return module.default() end
    return module.normalise(value)
end

function module.save(config, path)
    path = path or PATH
    config = module.normalise(config)
    local directory = fs.getDir(path)
    if directory ~= "" and not fs.exists(directory) then fs.makeDir(directory) end
    local temporary = path .. ".tmp"
    if fs.exists(temporary) then fs.delete(temporary) end
    local file = fs.open(temporary, "w")
    if not file then return false, "Could not write core configuration" end
    file.write("return ")
    file.write(textutils.serialize(config))
    file.write("\n")
    file.close()
    if fs.exists(path) then fs.delete(path) end
    fs.move(temporary, path)
    return true
end

function module.getPath()
    return PATH
end

return module
