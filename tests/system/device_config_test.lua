-- MCNet device configuration tests

local device = dofile("services/system/device_config.lua")
local TEST_PATH = ".mcnet/device_test.lua"
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

if fs.exists(TEST_PATH) then
    fs.delete(TEST_PATH)
end

local defaults = device.createDefault("TEST", 1)
check("default address unknown", defaults.address == "UNKNOWN")
check("default type unknown", defaults.type == "UNKNOWN")

local proposed = device.normalise({
    address = "tower 12",
    systemName = "tower control 12",
    friendlyName = "North Relay",
    type = "tower",
    region = "home",
    owner = "MCNet",
    status = "online"
}, "TEST", 1)

check("address normalised", proposed.address == "TOWER-12")
check("type normalised", proposed.type == "TOWER")
check("region normalised", proposed.region == "HOME")
check("friendly name retained", proposed.friendlyName == "North Relay")

local valid = device.validate(proposed)
check("valid configuration accepted", valid == true)

local saved = device.save(proposed, TEST_PATH, "TEST", 1)
check("configuration saves", saved == true and fs.exists(TEST_PATH))

local loaded = device.load(TEST_PATH, "TEST", 1)
check("configuration loads", loaded.address == "TOWER-12")
check("display name works", device.getDisplayName(loaded) == "North Relay")

if fs.exists(TEST_PATH) then
    fs.delete(TEST_PATH)
end

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Device configuration tests failed", 0)
end
