-- MCNet modem driver tests using a simulated peripheral

local originalPeripheral = peripheral
local originalStartTimer = os.startTimer
local originalPullEvent = os.pullEvent
local passed = 0
local failed = 0
local opened = {}
local transmissions = {}

local fakeModem = {
    open = function(channel)
        opened[channel] = true
    end,
    close = function(channel)
        opened[channel] = nil
    end,
    closeAll = function()
        opened = {}
    end,
    isOpen = function(channel)
        return opened[channel] == true
    end,
    transmit = function(channel, replyChannel, message)
        table.insert(transmissions, {
            channel = channel,
            replyChannel = replyChannel,
            message = message
        })
    end,
    isWireless = function()
        return true
    end
}

peripheral = {
    getNames = function()
        return { "back" }
    end,
    getType = function(name)
        if name == "back" then
            return "modem"
        end
        return nil
    end,
    wrap = function(name)
        if name == "back" then
            return fakeModem
        end
        return nil
    end
}

local modem = dofile("drivers/modem.lua")

local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

local detected, name = modem.detect(true)
check("modem detected", detected == fakeModem and name == "back")

local openedResult = modem.open(1234)
check("channel opens", openedResult == true and modem.isOpen(1234))

local sent = modem.send(1234, 1235, "hello")
check("message transmits", sent == true and #transmissions == 1)
check("transmit values", transmissions[1].channel == 1234 and transmissions[1].replyChannel == 1235 and transmissions[1].message == "hello")
check("wireless detected", modem.isWireless() == true)

local closed = modem.close(1234)
check("channel closes", closed == true and not modem.isOpen(1234))

os.startTimer = function()
    return 99
end

local events = {
    { "modem_message", "back", 4242, 4243, "packet", 12 }
}

os.pullEvent = function()
    local event = table.remove(events, 1)
    return unpack(event)
end

local received = modem.receive(4242, 2)
check("message receives", received and received.message == "packet")
check("distance receives", received and received.distance == 12)

peripheral = originalPeripheral
os.startTimer = originalStartTimer
os.pullEvent = originalPullEvent

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Modem tests failed", 0)
end
