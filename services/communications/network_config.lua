-- MCNet persistent network settings
-- Version 0.8.0

local module = {}
local PATH = ".mcnet/network.lua"

local defaults = {
    enabled = true,
    channel = 4242,
    preferredTower = "",

    tickInterval = 1,
    beaconInterval = 4,
    registrationInterval = 5,
    lsaInterval = 8,

    towerTimeout = 14,
    neighbourTimeout = 16,
    endpointTimeout = 22,
    topologyTimeout = 36,

    ackTimeout = 4,
    maxRetries = 4,
    frameTTL = 16,
    seenTimeout = 60
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

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

function module.default()
    return copyTable(defaults)
end

function module.normalise(config)
    local result = module.default()
    config = config or {}

    for key, value in pairs(config) do
        result[key] = value
    end

    result.enabled = result.enabled ~= false
    result.channel = math.floor(numberInRange(result.channel, defaults.channel, 1, 65535))
    result.preferredTower = string.upper(tostring(result.preferredTower or ""))
    result.preferredTower = string.gsub(result.preferredTower, "%s+", "-")

    result.tickInterval = numberInRange(result.tickInterval, defaults.tickInterval, 0.2, 10)
    result.beaconInterval = numberInRange(result.beaconInterval, defaults.beaconInterval, 1, 60)
    result.registrationInterval = numberInRange(result.registrationInterval, defaults.registrationInterval, 1, 60)
    result.lsaInterval = numberInRange(result.lsaInterval, defaults.lsaInterval, 2, 120)

    result.towerTimeout = numberInRange(result.towerTimeout, defaults.towerTimeout, 4, 180)
    result.neighbourTimeout = numberInRange(result.neighbourTimeout, defaults.neighbourTimeout, 4, 180)
    result.endpointTimeout = numberInRange(result.endpointTimeout, defaults.endpointTimeout, 4, 300)
    result.topologyTimeout = numberInRange(result.topologyTimeout, defaults.topologyTimeout, 8, 300)

    result.ackTimeout = numberInRange(result.ackTimeout, defaults.ackTimeout, 1, 60)
    result.maxRetries = math.floor(numberInRange(result.maxRetries, defaults.maxRetries, 1, 20))
    result.frameTTL = math.floor(numberInRange(result.frameTTL, defaults.frameTTL, 2, 64))
    result.seenTimeout = numberInRange(result.seenTimeout, defaults.seenTimeout, 10, 600)

    return result
end

function module.load(path)
    path = path or PATH

    if not fs.exists(path) then
        return module.default()
    end

    local loaded, config = pcall(dofile, path)

    if not loaded or type(config) ~= "table" then
        return module.default()
    end

    return module.normalise(config)
end

function module.save(config, path)
    path = path or PATH
    config = module.normalise(config)

    local directory = fs.getDir(path)

    if directory ~= "" and not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local temporary = path .. ".tmp"

    if fs.exists(temporary) then
        fs.delete(temporary)
    end

    local file = fs.open(temporary, "w")

    if not file then
        return false, "Could not open network settings file"
    end

    file.write("return ")
    file.write(textutils.serialize(config))
    file.write("\n")
    file.close()

    if fs.exists(path) then
        fs.delete(path)
    end

    fs.move(temporary, path)
    return true
end

function module.getPath()
    return PATH
end

return module
