-- MCNet one-tower end-to-end delivery test

local packetLibrary = dofile("services/communications/packet.lua")
local frameLibrary = dofile("services/communications/frame.lua")
local routingLibrary = dofile("services/communications/routing.lua")
local networkFactory = dofile("services/communications/network.lua")

local passed = 0
local failed = 0
local bus = {}
local nodes = {}
local deliveredText = nil
local deliveryStatus = nil

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

local function driverFor(name)
    local driver = {}

    function driver.detect()
        return {}, name
    end

    function driver.open()
        return true
    end

    function driver.send(channel, replyChannel, message)
        table.insert(bus, {
            sender = name,
            channel = channel,
            replyChannel = replyChannel,
            message = message
        })
        return true
    end

    return driver
end

local function makeNode(name, address, deviceType)
    local network = networkFactory.new({
        packetLibrary = packetLibrary,
        frameLibrary = frameLibrary,
        routingLibrary = routingLibrary,
        modemDriver = driverFor(name),
        config = config,
        device = {
            address = address,
            type = deviceType,
            region = "HOME",
            friendlyName = address,
            systemName = "MCNET-" .. address
        }
    })

    nodes[name] = network
    return network
end

local tower = makeNode("tower", "TWR-001", "TOWER")
local pdaA = makeNode("pdaA", "PDA-001", "PDA")
local pdaB = makeNode("pdaB", "PDA-002", "PDA")

local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

local function distance(sender, receiver)
    if sender == "tower" and receiver == "pdaA" then
        return 5
    end

    if sender == "tower" and receiver == "pdaB" then
        return 6
    end

    if receiver == "tower" and sender == "pdaA" then
        return 5
    end

    if receiver == "tower" and sender == "pdaB" then
        return 6
    end

    return 10
end

local function flushBus()
    local safety = 0

    while #bus > 0 and safety < 100 do
        safety = safety + 1
        local transmission = table.remove(bus, 1)

        for name, network in pairs(nodes) do
            if name ~= transmission.sender then
                network.handleEvent({
                    "modem_message",
                    transmission.sender,
                    transmission.channel,
                    transmission.replyChannel,
                    transmission.message,
                    distance(transmission.sender, name)
                })
            end
        end
    end

    return safety < 100
end

pdaB.on("MESSAGING", function(packet)
    deliveredText = packet.payload.text
end)

pdaA.onDelivery(function(packetId, status)
    deliveryStatus = status
end)

tower.tick()
flushBus()

pdaA.tick()
pdaB.tick()
flushBus()

check("PDA A selected tower", pdaA.getStatus().selectedTower == "TWR-001")
check("PDA B selected tower", pdaB.getStatus().selectedTower == "TWR-001")
check("tower registered endpoints", tower.getStatus().localEndpoints == 2)

local sent = pdaA.send(
    "PDA-002",
    "MESSAGING",
    "TEXT",
    {
        text = "Hello through tower"
    }
)

check("message queued", sent == true)
check("bus completed", flushBus())
check("message delivered", deliveredText == "Hello through tower")
check("acknowledgement returned", deliveryStatus == "DELIVERED")
check("sender queue cleared", pdaA.getStatus().pending == 0)

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Mesh delivery tests failed", 0)
end
