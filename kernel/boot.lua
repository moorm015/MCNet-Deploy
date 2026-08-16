-- MCNet root boot kernel
-- Version 0.9.2
-- Routed network, core directory/mailbox, archive services,
-- monitor walls, railway configuration and role applications.

local VERSION = "0.9.2"
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
    "services/system/idle_manager.lua",
    "services/system/display_config.lua",

    "services/communications/packet.lua",
    "services/communications/frame.lua",
    "services/communications/network_config.lua",
    "services/communications/routing.lua",
    "services/communications/network.lua",
    "services/communications/core_config.lua",
    "services/communications/core_client.lua",
    "services/communications/core_server.lua",
    "services/communications/contacts.lua",
    "services/communications/messaging.lua",

    "services/archive/archive_manager.lua",

    "services/trains/station_config.lua",
    "services/trains/rail_config.lua",
    "services/trains/banner.lua",
    "services/trains/timetable.lua",
    "services/trains/platform_controller.lua",
    "services/trains/station_controller.lua",

    "drivers/modem.lua",

    "applications/system/console.lua",
    "applications/roles/generic.lua",
    "applications/roles/pda.lua",
    "applications/roles/tower.lua",
    "applications/roles/server.lua",
    "applications/roles/display.lua",
    "applications/roles/archive_reader.lua"
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
        pcall(
            dofile,
            path
        )

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

local randomSeed =
    (os.getComputerID() * 100000)
    + ((os.day and os.day() or 0) * 24000)
    + math.floor(
        (os.time and os.time() or 0)
        * 1000
    )
    + math.floor(
        os.clock() * 1000
    )

math.randomseed(randomSeed)
math.random()
math.random()
math.random()

local themeLibrary =
    load("services/ui/theme.lua")

local layoutLibrary =
    load("services/ui/layout.lua")

local logoLibrary =
    load("services/ui/logos.lua")

local uiFactory =
    load("services/ui/ui.lua")

local loadingFactory =
    load("services/ui/loading.lua")

local menu =
    load("services/ui/menu.lua")

local settingsModule =
    load("services/system/settings.lua")

local deviceModule =
    load("services/system/device_config.lua")

local diagnostics =
    load("services/system/diagnostics.lua")

local idleManagerFactory =
    load("services/system/idle_manager.lua")

local displayConfigModule =
    load("services/system/display_config.lua")

local stationConfigModule =
    load("services/trains/station_config.lua")

local railConfig =
    load("services/trains/rail_config.lua")

local railBanner =
    load("services/trains/banner.lua")

local railTimetable =
    load("services/trains/timetable.lua")

local platformControllerModule =
    load("services/trains/platform_controller.lua")

local stationControllerModule =
    load("services/trains/station_controller.lua")

local packetLibrary =
    load("services/communications/packet.lua")

local frameLibrary =
    load("services/communications/frame.lua")

local networkConfigModule =
    load("services/communications/network_config.lua")

local routingLibrary =
    load("services/communications/routing.lua")

local networkFactory =
    load("services/communications/network.lua")

local coreConfigModule =
    load("services/communications/core_config.lua")

local coreClientFactory =
    load("services/communications/core_client.lua")

local coreServerFactory =
    load("services/communications/core_server.lua")

local contactsFactory =
    load("services/communications/contacts.lua")

local messagingFactory =
    load("services/communications/messaging.lua")

local modemDriver =
    load("drivers/modem.lua")

local appManager =
    load("kernel/app_manager.lua")

local settings =
    settingsModule.load()

local networkConfig =
    networkConfigModule.load()

local coreConfig =
    coreConfigModule.load()

local ui =
    uiFactory.new(
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
        12,
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

loading.step("Routed network created")

local coreClient = nil
local coreServer = nil

if device.type == "SERVER" then
    coreServer =
        coreServerFactory.new(
            network,
            device,
            coreConfig
        )
else
    coreClient =
        coreClientFactory.new(
            network,
            device,
            coreConfig
        )
end

loading.step(
    device.type == "SERVER"
    and "Core server created"
    or "Core client created"
)

local contacts =
    contactsFactory.new()

local messaging =
    messagingFactory.new(
        network,
        device,
        {
            coreClient = coreClient,
            coreConfig = coreConfig
        }
    )

loading.step("Mailbox messaging created")

local idleManager =
    idleManagerFactory.new(
        settings,
        device
    )

loading.step("Idle manager created")

local stationController = nil

if device.type == "STATION" then
    local stationLocalConfig =
        stationConfigModule.load()

    local stationReason = nil

    stationController,
        stationReason =
        stationControllerModule.new({
            platformControllerModule =
                platformControllerModule,

            stationConfig =
                stationLocalConfig
        })

    if not stationController then
        plainFailure(
            "Could not create station controller: "
            .. tostring(stationReason)
        )
    end

    loading.step("Station controller created")
end

loading.step("Directory and contacts ready")
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

    coreConfig = coreConfig,
    coreConfigModule = coreConfigModule,
    network = network,
    coreClient = coreClient,
    coreServer = coreServer,

    contacts = contacts,
    messaging = messaging,

    displayConfigModule = displayConfigModule,

    stationConfigModule = stationConfigModule,
    railConfig = railConfig,
    railBanner = railBanner,
    railTimetable = railTimetable,
    platformControllerModule = platformControllerModule,
    stationControllerModule = stationControllerModule,
    stationController = stationController,

    idleManager = idleManager,
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
local backgroundFailure = nil

local function applicationTask()
    applicationCompleted,
        applicationReason =
        appManager.run(
            applicationPath,
            context
        )
end

local function guardedTask(
    label,
    runner
)
    return function()
        local completed, reason =
            pcall(runner)

        if completed then
            backgroundFailure =
                label
                .. " stopped unexpectedly"
        else
            backgroundFailure =
                label
                .. " failed: "
                .. tostring(reason)
        end
    end
end

local tasks = {
    applicationTask
}

if networkConfig.enabled ~= false then
    tasks[#tasks + 1] =
        guardedTask(
            "Network service",
            network.run
        )
end

if coreServer then
    tasks[#tasks + 1] =
        guardedTask(
            "Core server",
            coreServer.run
        )
end

if coreClient then
    tasks[#tasks + 1] =
        guardedTask(
            "Core client",
            coreClient.run
        )
end

if idleManager
    and idleManager.isEnabled() then

    tasks[#tasks + 1] =
        guardedTask(
            "PDA idle manager",
            idleManager.run
        )
end

if stationController then
    tasks[#tasks + 1] =
        guardedTask(
            "Station controller",
            stationController.run
        )
end

if parallel
    and parallel.waitForAny then

    parallel.waitForAny(
        unpack(tasks)
    )
else
    applicationTask()
end

network.stop()

if coreServer then
    coreServer.stop()
end

if coreClient then
    coreClient.stop()
end

if idleManager then
    idleManager.stop()
end

if stationController then
    stationController.stop()
end

ui.restoreNative()

if backgroundFailure then
    term.clear()
    term.setCursorPos(1, 1)

    print("MCNet service failure")
    print("=====================")
    print("")
    print(backgroundFailure)
    print("")
    print(
        "The startup supervisor will restart MCNet."
    )

    error(
        "MCNet background service stopped",
        0
    )
end

if not applicationCompleted then
    term.clear()
    term.setCursorPos(1, 1)

    print("MCNet application failure")
    print("=========================")
    print("")
    print(tostring(applicationReason))
    print("")
    print(
        "The startup supervisor will restart MCNet."
    )

    error(
        "MCNet application stopped",
        0
    )
end