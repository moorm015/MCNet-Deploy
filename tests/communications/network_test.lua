-- MCNet endpoint tower-routing tests

local packetLibrary = dofile("services/communications/packet.lua")
local frameLibrary = dofile("services/communications/frame.lua")
local routingLibrary = dofile("services/communications/routing.lua")
local networkFactory = dofile("services/communications/network.lua")

local passed = 0
local failed = 0
local transmissions = {}
local opened = false

local fakeModemDriver = {}

function fakeModemDriver.detect()
    return {}, "left"
end

function fakeModemDriver.open(channel)
    opened = channel == 4242
    return true
end

function fakeModemDriver.send(channel, replyChannel, message)
    table.insert(transmissions, {
        channel = channel,
        replyChannel = replyChannel,
        message = message
    })
    return true
end

local config = {
    enabled = true,
    channel = 4242,
    preferredTower = "",
    tickInterval = 1,
    beaconInterval = 4,
    registrationInterval = 5,
    lsaInterval = 8,
    towerTimeout = 20,
    neighbourTimeout = 20,
    endpointTimeout = 20,
    topologyTimeout = 40,
    ackTimeout = 4,
    maxRetries = 4,
    frameTTL = 16,
    seenTimeout = 60
}

local network = networkFactory.new({
    packetLibrary = packetLibrary,
    frameLibrary = frameLibrary,
    routingLibrary = routingLibrary,
    modemDriver = fakeModemDriver,
    config = config,
    device = {
        address = "PDA-001",
        type = "PDA",
        region = "HOME",
        friendlyName = "Test PDA",
        systemName = "MCNET-PDA-001"
    }
})

local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

network.handleEvent({
    "modem_message",
    "left",
    4242,
    4242,
    frameLibrary.new("BEACON", {
        origin = "TWR-001",
        destination = "*",
        previousHop = "TWR-001",
        nextHop = "*",
        ttl = 1,
        payload = {
            region = "HOME"
        }
    }),
    7
})

local status = network.getStatus()
check("tower selected", status.selectedTower == "TWR-001")

local sent, packetId = network.send(
    "PDA-002",
    "MESSAGING",
    "TEXT",
    {
        text = "Hello"
    }
)

check("packet queued", sent == true and packetId ~= nil)
check("modem opened", opened == true)
check("frame transmitted", #transmissions >= 1)

local last = transmissions[#transmissions].message
check("data sent to tower", last.kind == "DATA" and last.nextHop == "TWR-001")
check("final destination retained", last.destination == "PDA-002")
check("endpoint does not send direct", last.nextHop ~= "PDA-002")

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Network tests failed", 0)
end
