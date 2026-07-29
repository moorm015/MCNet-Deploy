--[[
    MCNet Packet Library
    Version: 0.1.0

    Implements MCNet Packet Protocol Version 1.
]]

local packet = {}

-- Protocol settings

packet.PROTOCOL_VERSION = 1
packet.DEFAULT_TTL = 8
packet.MAX_TTL = 32

-- Priority constants

packet.PRIORITY = {
    EMERGENCY = 1,
    HIGH = 2,
    NORMAL = 3,
    LOW = 4,
    BACKGROUND = 5
}

-- Reserved MCNet services

packet.SERVICE = {
    COMMUNICATIONS = "COMMUNICATIONS",
    ROUTING = "ROUTING",
    DISCOVERY = "DISCOVERY",
    LOGGING = "LOGGING",
    SECURITY = "SECURITY",
    UPDATE = "UPDATE",
    RAIL = "RAIL",
    POWER = "POWER",
    LOGISTICS = "LOGISTICS",
    DISPLAY = "DISPLAY",
    BUILDING = "BUILDING",
    SYSTEM = "SYSTEM"
}

-- Reserved packet types

packet.TYPE = {
    HELLO = "HELLO",
    MESSAGE = "MESSAGE",
    PING = "PING",
    PONG = "PONG",
    DISCOVER = "DISCOVER",
    ANNOUNCE = "ANNOUNCE",
    ACK = "ACK",
    ERROR = "ERROR",
    STATUS = "STATUS",
    UPDATE = "UPDATE",
    LOG = "LOG",
    COMMAND = "COMMAND",
    RESPONSE = "RESPONSE",
    HEARTBEAT = "HEARTBEAT"
}

-- Reserved destinations

packet.DESTINATION = {
    BROADCAST = "BROADCAST",
    SELF = "SELF",
    LOCAL = "LOCAL",
    UNKNOWN = "UNKNOWN"
}

local sequence = 0

local function isNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function isInteger(value)
    return type(value) == "number"
        and value == math.floor(value)
end

local function normaliseAddress(address)
    if type(address) ~= "string" then
        return address
    end

    return string.upper(address)
end

local function createPacketID()
    sequence = sequence + 1

    local computerID = os.getComputerID()
    local timeValue = math.floor(os.clock() * 1000)

    return tostring(computerID)
        .. "-"
        .. tostring(timeValue)
        .. "-"
        .. tostring(sequence)
end

-- Creates a new MCNet packet.
--
-- Required options:
--   source
--   destination
--   service
--   type
--
-- Optional options:
--   ttl
--   priority
--   payload

function packet.create(options)
    if type(options) ~= "table" then
        error("packet.create expected an options table", 2)
    end

    local newPacket = {
        version = packet.PROTOCOL_VERSION,
        id = createPacketID(),

        source = normaliseAddress(options.source),
        destination = normaliseAddress(options.destination),

        service = type(options.service) == "string"
            and string.upper(options.service)
            or options.service,

        type = type(options.type) == "string"
            and string.upper(options.type)
            or options.type,

        ttl = options.ttl,
        priority = options.priority,
        payload = options.payload
    }

    if newPacket.ttl == nil then
        newPacket.ttl = packet.DEFAULT_TTL
    end

    if newPacket.priority == nil then
        newPacket.priority = packet.PRIORITY.NORMAL
    end

    local valid, reason = packet.validate(newPacket)

    if not valid then
        error("Cannot create packet: " .. reason, 2)
    end

    return newPacket
end

-- Validates an MCNet logical address.

function packet.validateAddress(address)
    if not isNonEmptyString(address) then
        return false, "Address must be a non-empty string"
    end

    if address ~= string.upper(address) then
        return false, "Address must be upper case"
    end

    if string.find(address, "[^A-Z0-9%-]") then
        return false, "Address contains invalid characters"
    end

    if string.sub(address, 1, 1) == "-"
        or string.sub(address, -1) == "-" then
        return false, "Address cannot begin or end with a hyphen"
    end

    if string.find(address, "%-%-") then
        return false, "Address cannot contain consecutive hyphens"
    end

    return true
end

-- Validates a complete MCNet packet.
--
-- Returns:
--   true
--
-- or:
--   false, reason

function packet.validate(value)
    if type(value) ~= "table" then
        return false, "Packet is not a table"
    end

    if value.version ~= packet.PROTOCOL_VERSION then
        return false, "Unsupported packet protocol version"
    end

    if not isNonEmptyString(value.id) then
        return false, "Packet ID is missing"
    end

    local validSource, sourceReason =
        packet.validateAddress(value.source)

    if not validSource then
        return false, "Invalid source: " .. sourceReason
    end

    local validDestination, destinationReason =
        packet.validateAddress(value.destination)

    if not validDestination then
        return false, "Invalid destination: " .. destinationReason
    end

    if not isNonEmptyString(value.service) then
        return false, "Packet service is missing"
    end

    if value.service ~= string.upper(value.service) then
        return false, "Packet service must be upper case"
    end

    if not isNonEmptyString(value.type) then
        return false, "Packet type is missing"
    end

    if value.type ~= string.upper(value.type) then
        return false, "Packet type must be upper case"
    end

    if not isInteger(value.ttl) then
        return false, "Packet TTL must be an integer"
    end

    if value.ttl < 0 or value.ttl > packet.MAX_TTL then
        return false,
            "Packet TTL must be between 0 and "
            .. tostring(packet.MAX_TTL)
    end

    if not isInteger(value.priority) then
        return false, "Packet priority must be an integer"
    end

    if value.priority < packet.PRIORITY.EMERGENCY
        or value.priority > packet.PRIORITY.BACKGROUND then
        return false, "Packet priority must be between 1 and 5"
    end

    return true
end

-- Reduces a packet's TTL before forwarding.
--
-- Returns true if it may still be forwarded.
-- Returns false and a reason if it must be dropped.

function packet.decrementTTL(value)
    local valid, reason = packet.validate(value)

    if not valid then
        return false, reason
    end

    if value.ttl <= 0 then
        return false, "Packet TTL has expired"
    end

    value.ttl = value.ttl - 1

    if value.ttl <= 0 then
        return false, "Packet TTL has expired"
    end

    return true
end

-- Returns true when the packet is addressed to the local device.

function packet.isForDevice(value, localAddress)
    local valid, reason = packet.validate(value)

    if not valid then
        return false, reason
    end

    localAddress = normaliseAddress(localAddress)

    if value.destination == packet.DESTINATION.BROADCAST then
        return true
    end

    if value.destination == packet.DESTINATION.SELF then
        return true
    end

    return value.destination == localAddress
end

-- Creates a response packet addressed back to the original sender.

function packet.createResponse(original, source, responseType, payload)
    local valid, reason = packet.validate(original)

    if not valid then
        error("Cannot respond to invalid packet: " .. reason, 2)
    end

    return packet.create({
        source = source,
        destination = original.source,
        service = original.service,
        type = responseType,
        priority = original.priority,
        payload = payload
    })
end

return packet