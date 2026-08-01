-- MCNet packet protocol tests

local packet = dofile("services/communications/packet.lua")
local passed = 0
local failed = 0

local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

local value = packet.new({
    source = "PDA-001",
    destination = "TWR-001",
    service = "TEST",
    type = "PING",
    ttl = 4,
    payload = { message = "hello" }
})

local valid = packet.validate(value)
check("new packet validates", valid == true)
check("source retained", value.source == "PDA-001")
check("destination retained", value.destination == "TWR-001")
check("payload retained", value.payload.message == "hello")

local decremented, ttl = packet.decrementTTL(value)
check("TTL decrements", decremented == true and ttl == 3 and value.ttl == 3)
check("direct destination matches", packet.isFor(value, "TWR-001"))

local broadcast = packet.new({ source = "A", destination = "BROADCAST" })
check("broadcast matches", packet.isFor(broadcast, "ANYTHING"))

local invalid = packet.new({ source = "A" })
invalid.protocol = 999
local invalidResult = packet.validate(invalid)
check("bad protocol rejected", invalidResult == false)

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Packet tests failed", 0)
end
