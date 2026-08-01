-- MCNet link-state routing tests

local routingLibrary = dofile("services/communications/routing.lua")
local passed = 0
local failed = 0

local config = {
    neighbourTimeout = 30,
    endpointTimeout = 30,
    topologyTimeout = 60
}

local routing = routingLibrary.new("TWR-001", config)

local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

routing.updateNeighbour("TWR-002", 12, {
    region = "HOME"
})

routing.registerEndpoint("PDA-001", 4, {
    type = "PDA",
    region = "HOME"
})

local accepted = routing.acceptLSA({
    origin = "TWR-002",
    bootId = "B-1",
    sequence = 1,
    neighbours = {
        "TWR-001",
        "TWR-003"
    },
    endpoints = {}
})

check("remote LSA accepted", accepted == true)

accepted = routing.acceptLSA({
    origin = "TWR-003",
    bootId = "C-1",
    sequence = 1,
    neighbours = {
        "TWR-002"
    },
    endpoints = {
        {
            address = "PDA-009",
            type = "PDA",
            region = "REMOTE"
        }
    }
})

check("endpoint LSA accepted", accepted == true)

local directHop, directKind = routing.getNextHop("PDA-001")
check("local endpoint routes directly", directHop == "PDA-001" and directKind == "endpoint")

local remoteHop, remoteKind = routing.getNextHop("PDA-009")
check("remote endpoint routes through neighbour", remoteHop == "TWR-002" and remoteKind == "tower")

local towerHop = routing.getNextHop("TWR-003")
check("remote tower routes through neighbour", towerHop == "TWR-002")

local older = routing.acceptLSA({
    origin = "TWR-003",
    bootId = "C-1",
    sequence = 1,
    neighbours = {},
    endpoints = {}
})

check("older LSA rejected", older == false)

local summary = routing.getSummary()
check("summary counts neighbour", summary.neighbours == 1)
check("summary counts endpoint", summary.localEndpoints == 1)
check("known destinations populated", summary.knownDestinations >= 4)

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Routing tests failed", 0)
end
