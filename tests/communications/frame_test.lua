-- MCNet network frame protocol tests

local frame = dofile("services/communications/frame.lua")
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

local value = frame.new("DATA", {
    origin = "PDA-001",
    destination = "PDA-002",
    previousHop = "PDA-001",
    nextHop = "TWR-001",
    ttl = 5,
    payload = {
        hello = "world"
    }
})

local valid = frame.validate(value)
check("new frame validates", valid == true)
check("kind retained", value.kind == "DATA")
check("destination retained", value.destination == "PDA-002")
check("payload retained", value.payload.hello == "world")
check("endpoint hop matches", frame.isForHop(value, "TWR-001", true))

local towers = frame.new("LSA", {
    origin = "TWR-001",
    destination = "TOWERS",
    previousHop = "TWR-001",
    nextHop = "TOWERS"
})

check("tower broadcast matches router", frame.isForHop(towers, "TWR-002", true))
check("tower broadcast excludes endpoint", not frame.isForHop(towers, "PDA-001", false))

local copied = frame.copy(value)
local decremented, ttl = frame.decrementTTL(copied)
check("TTL decrements", decremented == true and ttl == 4)
check("original TTL unchanged", value.ttl == 5)

local invalid = frame.copy(value)
invalid.magic = "OTHER"
local invalidResult = frame.validate(invalid)
check("bad magic rejected", invalidResult == false)

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Frame tests failed", 0)
end
