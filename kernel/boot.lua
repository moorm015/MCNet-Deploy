-- MCNet root boot kernel
-- Version 0.9.2
-- Modular-installation ready.
--
-- Shared MCNet services are loaded on every configured device. Role-specific
-- services are loaded only when that role needs them. This lets the deployment
-- manifest stop installing unrelated applications and railway/server code on
-- every computer.
--
-- IMPORTANT:
-- Persistent files under .mcnet/ are configuration/state, not program modules.
-- This kernel never deletes them. A future role-package change may remove old
-- role CODE while retaining its saved configuration for later reuse.

local VERSION = "0.9.2"
local PROTOCOL = 1
local BASE_URL = "https://raw.githubusercontent.com/moorm015/MCNet-Deploy/main/"
local INSTALLER_URL = BASE_URL .. "installer/install.lua"

local function plainFailure(message)
    term.clear()
    term.setCursorPos(1, 1)

    print("MCNet boot failure")
    print("==================")
    print("")
    print(tostring(message))
    print("")
    print("Run bootstrap to repair or sync this device.")

    error("MCNet boot stopped", 0)
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

local function verifyFiles(files, role)
    for _, path in ipairs(files) do
        if not fs.exists(path) then
            local detail =
                "Required file is missing: "
                .. path

            if role
                and role ~= ""
                and role ~= "UNKNOWN" then

                detail =
                    detail
                    .. "\nRole: "
                    .. tostring(role)
                    .. "\nRun Install or update MCNet to sync role files."
            end

            plainFailure(detail)
        end
    end
end

local function addRequired(list, seen, path)
    if type(path) ~= "string"
        or path == ""
        or seen[path] then

        return
    end

    seen[path] = true
    list[#list + 1] = path
end

-- These files are the minimum shared MCNet runtime. They remain available on
-- all roles because every role can open the System Console and inspect MCNet
-- network state.
local sharedRequiredFiles = {
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
    "services/communications/core_config.lua",
    "services/communications/contacts.lua",
    "services/communications/messaging.lua",

    "drivers/modem.lua",

    "applications/system/console.lua"
}

-- Verify enough of the shared runtime to safely discover the saved role.
verifyFiles(sharedRequiredFiles)

local appManager =
    load("kernel/app_manager.lua")

local settingsModule =
    load("services/system/settings.lua")

local deviceModule =
    load("services/system/device_config.lua")

local settings =
    settingsModule.load()

local device =
    deviceModule.load(
        nil,
        VERSION,
        PROTOCOL
    )

local deviceType =
    string.upper(
        tostring(
            device.type
            or "UNKNOWN"
        )
    )

-- Build the exact runtime this computer needs. This list is also supplied to
-- diagnostics, so "required files" now means required FOR THIS DEVICE rather
-- than every file MCNet knows about.
local requiredFiles = {}
local requiredSeen = {}

for _, path in ipairs(sharedRequiredFiles) do
    addRequired(
        requiredFiles,
        requiredSeen,
        path
    )
end

-- Core service selection.
-- SRV devices host the directory/mailbox database; every other device uses the
-- client service to discover and report to the Core Server.
if deviceType == "SERVER" then
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/communications/core_server.lua"
    )

    -- The current Server application dynamically loads this when archive
    -- management is opened, so it belongs to the SERVER package.
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/archive/archive_manager.lua"
    )
else
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/communications/core_client.lua"
    )
end

-- PDA-only background idle shutdown.
if deviceType == "PDA" then
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/system/idle_manager.lua"
    )
end

-- DISPLAY railway data and monitor configuration.
if deviceType == "DISPLAY" then
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/system/display_config.lua"
    )
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/trains/rail_config.lua"
    )
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/trains/banner.lua"
    )
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/trains/timetable.lua"
    )
end

-- STATION local safety/control stack.
if deviceType == "STATION" then
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/trains/station_config.lua"
    )
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/trains/rail_config.lua"
    )
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/trains/timetable.lua"
    )
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/trains/platform_controller.lua"
    )
    addRequired(
        requiredFiles,
        requiredSeen,
        "services/trains/station_controller.lua"
    )
end

-- A configured computer also needs its selected role application. For roles
-- without a specialised app, app_manager returns generic.lua.
if deviceModule.isConfigured(device) then
    addRequired(
        requiredFiles,
        requiredSeen,
        appManager.getRolePath(deviceType)
    )
end

verifyFiles(
    requiredFiles,
    deviceType
)

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

local diagnostics =
    load("services/system/diagnostics.lua")

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

local contactsFactory =
    load("services/communications/contacts.lua")

local messagingFactory =
    load("services/communications/messaging.lua")

local modemDriver =
    load("drivers/modem.lua")

-- Role-specific modules default to nil. Context fields are deliberately kept
-- under their existing names so no current role application loses anything.
local idleManagerFactory = nil
local displayConfigModule = nil

local stationConfigModule = nil
local railConfig = nil
local railBanner = nil
local railTimetable = nil
local platformControllerModule = nil
local stationControllerModule = nil

local coreClientFactory = nil
local coreServerFactory = nil

if deviceType == "SERVER" then
    coreServerFactory =
        load(
            "services/communications/core_server.lua"
        )
else
    coreClientFactory =
        load(
            "services/communications/core_client.lua"
        )
end

if deviceType == "PDA" then
    idleManagerFactory =
        load(
            "services/system/idle_manager.lua"
        )
end

if deviceType == "DISPLAY" then
    displayConfigModule =
        load(
            "services/system/display_config.lua"
        )

    railConfig =
        load(
            "services/trains/rail_config.lua"
        )

    railBanner =
        load(
            "services/trains/banner.lua"
        )

    railTimetable =
        load(
            "services/trains/timetable.lua"
        )
end

if deviceType == "STATION" then
    stationConfigModule =
        load(
            "services/trains/station_config.lua"
        )

    railConfig =
        load(
            "services/trains/rail_config.lua"
        )

    railTimetable =
        load(
            "services/trains/timetable.lua"
        )

    platformControllerModule =
        load(
            "services/trains/platform_controller.lua"
        )

    stationControllerModule =
        load(
            "services/trains/station_controller.lua"
        )
end

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

-- Base boot has ten visible steps. PDA and STATION each add one role-specific
-- service creation step.
local loadingStepCount = 10

if deviceType == "PDA"
    or deviceType == "STATION" then

    loadingStepCount =
        loadingStepCount + 1
end

local loading =
    loadingFactory.new(
        ui,
        VERSION,
        loadingStepCount,
        "MCNet"
    )

loading.step("Display initialised")
loading.step("Settings loaded")
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

if deviceType == "SERVER" then
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
    deviceType == "SERVER"
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

local idleManager = nil

if idleManagerFactory then
    idleManager =
        idleManagerFactory.new(
            settings,
            device
        )

    loading.step("Idle manager created")
end

local stationController = nil

if deviceType == "STATION" then
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

    -- This is now the device-specific dependency list used by diagnostics.
    requiredFiles = requiredFiles,
    deviceRole = deviceType,

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

    -- nil on roles which do not install/display these modules. Existing role
    -- applications keep the same context names.
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