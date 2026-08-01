-- MCNet packet protocol

local module = {}
local PROTOCOL_VERSION = 1
local DEFAULT_TTL = 16

local function generateID(source)
    local randomPart = math.random(100000, 999999)
    local clockPart = math.floor(os.clock() * 1000)
    return tostring(source or os.getComputerID()) .. "-" .. tostring(clockPart) .. "-" .. tostring(randomPart)
end

function module.new(values)
    values = values or {}

    return {
        protocol = tonumber(values.protocol) or PROTOCOL_VERSION,
        id = values.id or generateID(values.source),
        source = tostring(values.source or "UNKNOWN"),
        destination = tostring(values.destination or "BROADCAST"),
        service = tostring(values.service or "SYSTEM"),
        type = tostring(values.type or "MESSAGE"),
        priority = tonumber(values.priority) or 0,
        ttl = tonumber(values.ttl) or DEFAULT_TTL,
        payload = values.payload,
        created = tonumber(values.created) or os.clock()
    }
end

function module.validate(packet)
    if type(packet) ~= "table" then
        return false, "Packet must be a table"
    end

    if packet.protocol ~= PROTOCOL_VERSION then
        return false, "Unsupported protocol version"
    end

    if type(packet.id) ~= "string" or packet.id == "" then
        return false, "Packet ID is missing"
    end

    if type(packet.source) ~= "string" or packet.source == "" then
        return false, "Packet source is missing"
    end

    if type(packet.destination) ~= "string" or packet.destination == "" then
        return false, "Packet destination is missing"
    end

    if type(packet.service) ~= "string" or packet.service == "" then
        return false, "Packet service is missing"
    end

    if type(packet.type) ~= "string" or packet.type == "" then
        return false, "Packet type is missing"
    end

    if type(packet.ttl) ~= "number" or packet.ttl < 0 then
        return false, "Packet TTL is invalid"
    end

    return true
end

function module.decrementTTL(packet)
    local valid, reason = module.validate(packet)
    if not valid then
        return false, reason
    end

    if packet.ttl <= 0 then
        return false, "Packet TTL has expired"
    end

    packet.ttl = packet.ttl - 1
    return true, packet.ttl
end

function module.isFor(packet, address)
    if not packet or not address then
        return false
    end

    return packet.destination == address
        or packet.destination == "BROADCAST"
        or packet.destination == "*"
end

function module.copy(packet)
    local result = {}
    for key, value in pairs(packet or {}) do
        result[key] = value
    end
    return result
end

function module.getProtocolVersion()
    return PROTOCOL_VERSION
end

return module
