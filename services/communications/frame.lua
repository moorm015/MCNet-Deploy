-- MCNet network frame protocol
-- Version 0.8.0

local module = {}

local MAGIC = "MCNET"
local VERSION = 1
local DEFAULT_TTL = 16

local validKinds = {
    BEACON = true,
    REGISTER = true,
    LSA = true,
    DATA = true,
    ACK = true
}

local function generateID(origin, kind)
    return tostring(origin or "UNKNOWN")
        .. "-"
        .. tostring(kind or "FRAME")
        .. "-"
        .. tostring(math.floor(os.clock() * 1000))
        .. "-"
        .. tostring(math.random(100000, 999999))
end

function module.new(kind, values)
    values = values or {}
    kind = string.upper(tostring(kind or values.kind or ""))

    return {
        magic = MAGIC,
        version = tonumber(values.version) or VERSION,
        kind = kind,
        id = values.id or generateID(values.origin, kind),
        origin = tostring(values.origin or "UNKNOWN"),
        destination = tostring(values.destination or "*"),
        previousHop = tostring(values.previousHop or values.origin or "UNKNOWN"),
        nextHop = tostring(values.nextHop or "*"),
        ttl = tonumber(values.ttl) or DEFAULT_TTL,
        created = tonumber(values.created) or os.clock(),
        payload = values.payload
    }
end

function module.validate(frame)
    if type(frame) ~= "table" then
        return false, "Frame must be a table"
    end

    if frame.magic ~= MAGIC then
        return false, "Frame magic is invalid"
    end

    if frame.version ~= VERSION then
        return false, "Frame version is unsupported"
    end

    if not validKinds[frame.kind] then
        return false, "Frame kind is invalid"
    end

    if type(frame.id) ~= "string" or frame.id == "" then
        return false, "Frame ID is missing"
    end

    if type(frame.origin) ~= "string" or frame.origin == "" then
        return false, "Frame origin is missing"
    end

    if type(frame.destination) ~= "string" or frame.destination == "" then
        return false, "Frame destination is missing"
    end

    if type(frame.previousHop) ~= "string" or frame.previousHop == "" then
        return false, "Previous hop is missing"
    end

    if type(frame.nextHop) ~= "string" or frame.nextHop == "" then
        return false, "Next hop is missing"
    end

    if type(frame.ttl) ~= "number" or frame.ttl < 0 then
        return false, "Frame TTL is invalid"
    end

    return true
end

function module.copy(frame)
    local result = {}

    for key, value in pairs(frame or {}) do
        result[key] = value
    end

    return result
end

function module.decrementTTL(frame)
    local valid, reason = module.validate(frame)

    if not valid then
        return false, reason
    end

    if frame.ttl <= 0 then
        return false, "Frame TTL has expired"
    end

    frame.ttl = frame.ttl - 1
    return true, frame.ttl
end

function module.isForHop(frame, address, isTower)
    if not frame or not address then
        return false
    end

    if frame.nextHop == address or frame.nextHop == "*" then
        return true
    end

    if isTower and frame.nextHop == "TOWERS" then
        return true
    end

    if not isTower and frame.nextHop == "ENDPOINTS" then
        return true
    end

    return false
end

function module.getVersion()
    return VERSION
end

return module
