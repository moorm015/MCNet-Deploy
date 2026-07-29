--[[
    MCNet Modem Driver
    Version: 0.1.0

    Implements MCNet Modem Driver Specification Version 1.
]]

local packet = dofile("services/communications/packet.lua")

local modemDriver = {}

-- MCNet channel allocation

modemDriver.CHANNEL = {
    DATA = 43000,
    DISCOVERY = 43001,
    CONTROL = 43002,
    UPDATE = 43003,
    EMERGENCY = 43004
}

modemDriver.DEFAULT_CHANNEL = modemDriver.CHANNEL.DATA
modemDriver.MIN_CHANNEL = 0
modemDriver.MAX_CHANNEL = 65535

local modem = nil
local modemSide = nil

local mcnetChannels = {
    modemDriver.CHANNEL.DATA,
    modemDriver.CHANNEL.DISCOVERY,
    modemDriver.CHANNEL.CONTROL,
    modemDriver.CHANNEL.UPDATE,
    modemDriver.CHANNEL.EMERGENCY
}

local peripheralSides = {
    "top",
    "bottom",
    "left",
    "right",
    "front",
    "back"
}

local function isInteger(value)
    return type(value) == "number"
        and value == math.floor(value)
end

local function validateChannel(channel)
    if not isInteger(channel) then
        return false, "Invalid modem channel: channel must be an integer"
    end

    if channel < modemDriver.MIN_CHANNEL
        or channel > modemDriver.MAX_CHANNEL then
        return false,
            "Invalid modem channel: channel must be between "
            .. tostring(modemDriver.MIN_CHANNEL)
            .. " and "
            .. tostring(modemDriver.MAX_CHANNEL)
    end

    return true
end

local function findModem()
    for _, side in ipairs(peripheralSides) do
        if peripheral.isPresent(side)
            and peripheral.getType(side) == "modem" then

            local wrapped = peripheral.wrap(side)

            if wrapped then
                return wrapped, side
            end
        end
    end

    return nil, nil
end

local function ensureModem()
    if modem and modemSide then
        if peripheral.isPresent(modemSide)
            and peripheral.getType(modemSide) == "modem" then
            return true
        end

        modem = nil
        modemSide = nil
    end

    modem, modemSide = findModem()

    if not modem then
        return false, "No modem found"
    end

    return true
end

local function transmit(value, channel)
    local available, modemReason = ensureModem()

    if not available then
        return false, modemReason
    end

    local validChannel, channelReason = validateChannel(channel)

    if not validChannel then
        return false, channelReason
    end

    local validPacket, packetReason = packet.validate(value)

    if not validPacket then
        return false, "Invalid MCNet packet: " .. tostring(packetReason)
    end

    if not modem.isOpen(channel) then
        return false,
            "Modem channel "
            .. tostring(channel)
            .. " is not open"
    end

    modem.transmit(channel, channel, value)

    return true
end

-- Opens all standard MCNet modem channels.

function modemDriver.open()
    local available, reason = ensureModem()

    if not available then
        return false, reason
    end

    for _, channel in ipairs(mcnetChannels) do
        if not modem.isOpen(channel) then
            modem.open(channel)
        end
    end

    return true
end

-- Closes only the channels owned by MCNet.

function modemDriver.close()
    local available, reason = ensureModem()

    if not available then
        return false, reason
    end

    for _, channel in ipairs(mcnetChannels) do
        if modem.isOpen(channel) then
            modem.close(channel)
        end
    end

    return true
end

-- Returns true when the default MCNet channel is open.

function modemDriver.isOpen()
    local available = ensureModem()

    if not available then
        return false
    end

    return modem.isOpen(modemDriver.DEFAULT_CHANNEL)
end

-- Returns the side containing the active modem.

function modemDriver.getSide()
    local available = ensureModem()

    if not available then
        return nil
    end

    return modemSide
end

-- Returns true when a specific channel is open.

function modemDriver.isChannelOpen(channel)
    local validChannel = validateChannel(channel)

    if not validChannel then
        return false
    end

    local available = ensureModem()

    if not available then
        return false
    end

    return modem.isOpen(channel)
end

-- Sends a validated MCNet packet.
--
-- If no channel is supplied, the normal MCNet data channel is used.

function modemDriver.send(value, channel)
    if channel == nil then
        channel = modemDriver.DEFAULT_CHANNEL
    end

    return transmit(value, channel)
end

-- Sends a packet whose destination is BROADCAST.

function modemDriver.broadcast(value, channel)
    local validPacket, packetReason = packet.validate(value)

    if not validPacket then
        return false, "Invalid MCNet packet: " .. tostring(packetReason)
    end

    if value.destination ~= packet.DESTINATION.BROADCAST then
        return false, "Packet destination is not BROADCAST"
    end

    if channel == nil then
        channel = modemDriver.DEFAULT_CHANNEL
    end

    return transmit(value, channel)
end

-- Waits for a valid MCNet packet.
--
-- Returns:
--   receivedPacket, metadata
--
-- On timeout:
--   nil, "timeout"

function modemDriver.receive(timeout)
    local available, modemReason = ensureModem()

    if not available then
        return nil, modemReason
    end

    if not modemDriver.isOpen() then
        return nil, "Modem is not open"
    end

    if timeout ~= nil then
        if type(timeout) ~= "number" or timeout < 0 then
            return nil,
                "Receive timeout must be a non-negative number"
        end
    end

    local timerID = nil

    if timeout ~= nil then
        timerID = os.startTimer(timeout)
    end

    while true do
        local event = {
            os.pullEvent()
        }

        local eventName = event[1]

        if eventName == "timer"
            and timerID ~= nil
            and event[2] == timerID then
            return nil, "timeout"
        end

        if eventName == "modem_message" then
            local side = event[2]
            local channel = event[3]
            local replyChannel = event[4]
            local message = event[5]
            local distance = event[6]

            local isOpenChannel =
                modem.isOpen(channel)

            if side == modemSide and isOpenChannel then
                local validPacket = packet.validate(message)

                if validPacket then
                    return message, {
                        side = side,
                        channel = channel,
                        replyChannel = replyChannel,
                        distance = distance
                    }
                end
            end
        end
    end
end

return modemDriver