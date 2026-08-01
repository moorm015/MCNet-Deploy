-- MCNet root boot kernel
-- Version 0.8.0
--
-- The kernel verifies the installation, loads services, configures the
-- display, starts the routed wireless network, and launches the selected app.

local VERSION = "0.8.0"
local PROTOCOL = 1
local BASE_URL = "https://raw.githubusercontent.com/moorm015/MCNet-Deploy/main/"
local INSTALLER_URL = BASE_URL .. "installer/install.lua"

local requiredFiles = {
    "kernel/app_manager.lua",

    "services/ui/theme.lua",
    "services/ui/layout.lua",
    "services/ui/logos.lua",
    "services/ui/ui.lua",
    "services/ui/loading.lua",
    "services/ui/menu.lua",

    "services/system/settings.lua",
    "services/system/device_config.lua",
    "services/system/diagnostics.lua",

    "services/communications/packet.lua",
    "services/communications/frame.lua",
    "services/communications/network_config.lua",
    "services/communications/routing.lua",
    "services/communications/network.lua",
    "services/communications/messaging.lua",

    "drivers/modem.lua",

    "applications/system/console.lua",
    "applications/roles/generic.lua"
}

local function plainFailure(message)
    term.clear()
    term.setCursorPos(1, 1)
    print("MCNet boot failure")
    print("==================")
    print("")
    print(tostring(message))
    print("")
    print("Run bootstrap to repair MCNet.")
    error("MCNet boot stopped", 0)
end

for _, path in ipairs(requiredFiles) do
    if not fs.exists(path) then
        plainFailure(
            "Required file is missing: "
            .. path
        )
    end
end

local function load(path)
    local completed, result =
        pcall(dofile, path)

    if not completed then
        plainFailure(
            "Could not load "
            .. path
            .. ": "
            .. tostring(result)
        )
    end

    return result
end

-- Seed randomness using the computer, Minecraft day/time and runtime.
local randomSeed =
    (os.getComputerID() * 100000)
    + ((os.day and os.day() or 0) * 24000)
    + math.floor((os.time and os.time() or 0) * 1000)
    + math.floor(os.clock() * 1000)

math.randomseed(randomSeed)
math.random()
math.random()
math.random()

local themeLibrary = load("services/ui/theme.lua")
local layoutLibrary = load("services/ui/layout.lua")
local logoLibrary = load("services/ui/logos.lua")
local uiFactory = load("services/ui/ui.lua")
local loadingFactory = load("services/ui/loading.lua")
local menu = load("services/ui/menu.lua")

local settingsModule = load("services/system/settings.lua")
local deviceModule = load("services/system/device_config.lua")
local diagnostics = load("services/system/diagnostics.lua")

local packetLibrary = load("services/communications/packet.lua")
local frameLibrary = load("services/communications/frame.lua")
local networkConfigModule = load("services/communications/network_config.lua")
local routingLibrary = load("services/communications/routing.lua")
local networkFactory = load("services/communications/network.lua")
local messagingFactory = load("services/communications/messaging.lua")
local modemDriver = load("drivers/modem.lua")

local appManager = load("kernel/app_manager.lua")

local settings = settingsModule.load()
local networkConfig = networkConfigModule.load()
local ui = uiFactory.new(
    themeLibrary,
    layoutLibrary,
    logoLibrary
)

local configured, displayReason =
    ui.configure(settings)

if not configured then
    settings.display = "native"
    settingsModule.save(settings)
    ui.configure(settings)
end

local loading =
    loadingFactory.new(
        ui,
        VERSION,
        8,
        "MCNet"
    )

loading.step("Display initialised")
loading.step("Settings loaded")

local device =
    deviceModule.load(
        nil,
        VERSION,
        PROTOCOL
    )

loading.step("Device identity loaded")

local network =
    networkFactory.new({
        packetLibrary = packetLibrary,
        frameLibrary = frameLibrary,
        routingLibrary = routingLibrary,
        modemDriver = modemDriver,
        config = networkConfig,
        device = device
    })

loading.step("Network service created")

local messaging =
    messagingFactory.new(
        network,
        device
    )

loading.step("Messaging service created")
loading.step("System services loaded")

local context = {
    version = VERSION,
    protocol = PROTOCOL,
    baseUrl = BASE_URL,
    installerUrl = INSTALLER_URL,
    requiredFiles = requiredFiles,

    settings = settings,
    settingsModule = settingsModule,
    deviceModule = deviceModule,
    diagnostics = diagnostics,

    themeLibrary = themeLibrary,
    layoutLibrary = layoutLibrary,
    logoLibrary = logoLibrary,
    ui = ui,
    menu = menu,

    packetLibrary = packetLibrary,
    frameLibrary = frameLibrary,
    networkConfig = networkConfig,
    networkConfigModule = networkConfigModule,
    routingLibrary = routingLibrary,
    modemDriver = modemDriver,
    network = network,
    messaging = messaging,

    appManager = appManager,
    displayReason = displayReason
}

local applicationPath =
    appManager.choose(
        settings,
        device,
        deviceModule
    )

loading.step("Application selected")
loading.step("Background services ready")
loading.finish(
    "Starting "
    .. applicationPath
)

local applicationCompleted = nil
local applicationReason = nil
local networkFailure = nil

local function applicationTask()
    applicationCompleted, applicationReason =
        appManager.run(
            applicationPath,
            context
        )
end

local function networkTask()
    local completed, reason =
        pcall(network.run)

    if not completed then
        networkFailure = reason
    end
end

if networkConfig.enabled ~= false
    and parallel
    and parallel.waitForAny then
    parallel.waitForAny(
        applicationTask,
        networkTask
    )
else
    applicationTask()
end

network.stop()
ui.restoreNative()

if applicationCompleted == nil
    and networkFailure then
    term.clear()
    term.setCursorPos(1, 1)
    print("MCNet network failure")
    print("=====================")
    print("")
    print(tostring(networkFailure))
    print("")
    print("Run bootstrap to repair or update MCNet.")
    error("MCNet network stopped", 0)
end

if not applicationCompleted then
    term.clear()
    term.setCursorPos(1, 1)
    print("MCNet application failure")
    print("=========================")
    print("")
    print(tostring(applicationReason))
    print("")
    print("Run bootstrap to repair or update MCNet.")
    error("MCNet application stopped", 0)
end
