--[[
    MCNet Device Configuration Test
    Version: 0.1.0

    Uses a temporary test file and does not alter the real device identity.
]]

local deviceConfig =
    dofile("services/system/device_config.lua")

local passed = 0
local failed = 0

local testPath = ".mcnet/device-test.lua"

local function pass(message)
    passed = passed + 1
    print("[PASS] " .. message)
end

local function fail(message, reason)
    failed = failed + 1

    if reason ~= nil then
        print("[FAIL] " .. message .. ": " .. tostring(reason))
    else
        print("[FAIL] " .. message)
    end
end

local function expect(condition, message, reason)
    if condition then
        pass(message)
    else
        fail(message, reason)
    end
end

local function cleanUp()
    if fs.exists(testPath) then
        fs.delete(testPath)
    end

    if fs.exists(testPath .. ".tmp") then
        fs.delete(testPath .. ".tmp")
    end
end

print("MCNet Device Configuration Test")
print("===============================")
print("")

cleanUp()

local defaultConfig = deviceConfig.createDefault()

expect(
    type(defaultConfig) == "table",
    "Default configuration was created"
)

expect(
    defaultConfig.address == "UNKNOWN",
    "Default address is UNKNOWN"
)

expect(
    defaultConfig.name == "Unconfigured Device",
    "Default friendly name is correct"
)

expect(
    defaultConfig.type == deviceConfig.TYPE.UNKNOWN,
    "Default device type is UNKNOWN"
)

expect(
    defaultConfig.computerID == os.getComputerID(),
    "Computer ID was detected correctly"
)

local defaultValid, defaultReason =
    deviceConfig.validate(defaultConfig)

expect(
    defaultValid == true,
    "Default configuration is valid",
    defaultReason
)

expect(
    deviceConfig.exists(testPath) == false,
    "Test configuration does not initially exist"
)

local initialised, initialiseReason =
    deviceConfig.initialise(testPath)

expect(
    initialised == true,
    "Default configuration was initialised",
    initialiseReason
)

expect(
    deviceConfig.exists(testPath) == true,
    "Initialised configuration file exists"
)

local loadedDefault, loadReason =
    deviceConfig.load(testPath)

expect(
    loadedDefault ~= nil,
    "Initialised configuration was loaded",
    loadReason
)

if loadedDefault then
    expect(
        loadedDefault.address == "UNKNOWN",
        "Loaded default address is correct"
    )
end

local configuredDevice = {
    address = "tower-001",
    name = "Home Base Tower",
    type = "tower",
    region = "home",
    owner = "MCNet",
    status = "online",
    computerID = os.getComputerID(),
    version = "0.4.0"
}

local saved, saveReason =
    deviceConfig.save(configuredDevice, testPath)

expect(
    saved == true,
    "Configured device was saved",
    saveReason
)

local loadedDevice, configuredLoadReason =
    deviceConfig.load(testPath)

expect(
    loadedDevice ~= nil,
    "Configured device was loaded",
    configuredLoadReason
)

if loadedDevice then
    expect(
        loadedDevice.address == "TOWER-001",
        "Address was normalised to upper case"
    )

    expect(
        loadedDevice.type == "TOWER",
        "Device type was normalised to upper case"
    )

    expect(
        loadedDevice.region == "HOME",
        "Region was normalised to upper case"
    )

    expect(
        loadedDevice.status == "ONLINE",
        "Status was normalised to upper case"
    )

    expect(
        loadedDevice.name == "Home Base Tower",
        "Friendly name was preserved"
    )
end

local address, addressReason =
    deviceConfig.getAddress(testPath)

expect(
    address == "TOWER-001",
    "Configured address was returned",
    addressReason
)

local invalidConfig = {
    address = "invalid address",
    name = "Invalid Device",
    type = "TEST",
    region = "TEST",
    owner = "MCNet",
    status = "ONLINE",
    computerID = os.getComputerID(),
    version = "0.4.0"
}

local invalidSaved =
    deviceConfig.save(invalidConfig, testPath)

expect(
    invalidSaved == false,
    "Invalid configuration was rejected"
)

local initialisedAgain, existingReason =
    deviceConfig.initialise(testPath)

expect(
    initialisedAgain == true
        and existingReason == "existing",
    "Existing configuration was not overwritten",
    existingReason
)

cleanUp()

expect(
    deviceConfig.exists(testPath) == false,
    "Temporary test configuration was removed"
)

print("")
print("Test summary")
print("============")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed == 0 then
    print("")
    print("All device configuration tests passed.")
else
    print("")
    print("Device configuration tests failed.")
end