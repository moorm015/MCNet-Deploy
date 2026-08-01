-- MCNet modem driver

local module = {}
local DEFAULT_CHANNEL = 4242
local modem = nil
local modemName = nil

local function peripheralNames()
    if peripheral.getNames then
        return peripheral.getNames()
    end

    if rs and rs.getSides then
        return rs.getSides()
    end

    return {}
end

function module.detect(force)
    if modem and not force then
        return modem, modemName
    end

    modem = nil
    modemName = nil

    for _, name in ipairs(peripheralNames()) do
        local peripheralType = peripheral.getType and peripheral.getType(name) or nil

        if peripheralType == "modem" and peripheral.wrap then
            local wrapped = peripheral.wrap(name)
            if wrapped then
                modem = wrapped
                modemName = name
                return modem, modemName
            end
        end
    end

    return nil, "No modem detected"
end

function module.getName()
    if not modem then
        module.detect()
    end
    return modemName
end

function module.getModem()
    if not modem then
        module.detect()
    end
    return modem
end

function module.isWireless()
    local found = module.getModem()
    if found and found.isWireless then
        return found.isWireless()
    end
    return false
end

function module.open(channel)
    channel = tonumber(channel) or DEFAULT_CHANNEL
    local found, reason = module.detect()

    if not found then
        return false, reason
    end

    found.open(channel)
    return true, modemName
end

function module.close(channel)
    channel = tonumber(channel) or DEFAULT_CHANNEL
    local found, reason = module.detect()

    if not found then
        return false, reason
    end

    found.close(channel)
    return true
end

function module.closeAll()
    local found, reason = module.detect()

    if not found then
        return false, reason
    end

    if found.closeAll then
        found.closeAll()
    else
        found.close(DEFAULT_CHANNEL)
    end

    return true
end

function module.isOpen(channel)
    channel = tonumber(channel) or DEFAULT_CHANNEL
    local found = module.getModem()

    if not found or not found.isOpen then
        return false
    end

    return found.isOpen(channel)
end

function module.send(channel, replyChannel, message)
    channel = tonumber(channel) or DEFAULT_CHANNEL
    replyChannel = tonumber(replyChannel) or channel
    local found, reason = module.detect()

    if not found then
        return false, reason
    end

    found.transmit(channel, replyChannel, message)
    return true
end

function module.receive(channel, timeout)
    channel = tonumber(channel) or DEFAULT_CHANNEL
    timeout = tonumber(timeout)

    local opened, reason = module.open(channel)
    if not opened then
        return nil, reason
    end

    local timer = nil
    if timeout and timeout > 0 and os.startTimer then
        timer = os.startTimer(timeout)
    end

    while true do
        local event = { os.pullEvent() }

        if event[1] == "modem_message" and event[3] == channel then
            return {
                side = event[2],
                channel = event[3],
                replyChannel = event[4],
                message = event[5],
                distance = event[6]
            }
        end

        if event[1] == "timer" and timer and event[2] == timer then
            return nil, "timeout"
        end
    end
end

function module.getDefaultChannel()
    return DEFAULT_CHANNEL
end

return module
