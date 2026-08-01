-- MCNet root boot kernel
-- Version 0.7.0
--
-- The kernel verifies the installation, loads services, configures the
-- display, shows the loading sequence, and launches the selected app.

local VERSION = "0.7.0"
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
        plainFailure("Required file is missing: " .. path)
    end
end

local function load(path)
    local completed, result = pcall(dofile, path)
    if not completed then
        plainFailure("Could not load " .. path .. ": " .. tostring(result))
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

-- Discard the first few predictable values from Lua 5.1's generator.
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
local appManager = load("kernel/app_manager.lua")

local settings = settingsModule.load()
local ui = uiFactory.new(themeLibrary, layoutLibrary, logoLibrary)
local configured, displayReason = ui.configure(settings)

if not configured then
    settings.display = "native"
    settingsModule.save(settings)
    ui.configure(settings)
end

local loading = loadingFactory.new(ui, VERSION, 5, "MCNet")
loading.step("Display initialised")
loading.step("Settings loaded")

local device = deviceModule.load(nil, VERSION, PROTOCOL)
loading.step("Device identity loaded")
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
    appManager = appManager,
    displayReason = displayReason
}

local applicationPath = appManager.choose(settings, device, deviceModule)
loading.step("Application selected")
loading.finish("Starting " .. applicationPath)

local completed, reason = appManager.run(applicationPath, context)

ui.restoreNative()

if not completed then
    term.clear()
    term.setCursorPos(1, 1)
    print("MCNet application failure")
    print("=========================")
    print("")
    print(tostring(reason))
    print("")
    print("Run bootstrap to repair or update MCNet.")
    error("MCNet application stopped", 0)
end
