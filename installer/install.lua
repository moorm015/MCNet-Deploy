--[[
    MCNet Console
    Version: 0.6.0

    Installation, device configuration and diagnostic console.
]]

local CONSOLE_VERSION = "0.6.0"
local PROTOCOL_VERSION = 1

local BASE_URL =
    "https://raw.githubusercontent.com/moorm015/MCNet-Deploy/main/"

local MANIFEST_REMOTE = "mcnet-manifest.lua"
local MANIFEST_LOCAL = ".mcnet-manifest.lua"

local DEVICE_CONFIG_MODULE =
    "services/system/device_config.lua"

local DEVICE_CONFIG_PATH =
    ".mcnet/device.lua"

local theme = dofile("services/ui/theme.lua")
local ui = dofile("services/ui/ui.lua")
local menu = dofile("services/ui/menu.lua")

local THEME = theme

local screenWidth, screenHeight = ui.getSize()
local compactMode = ui.isCompact()
local supportsColour = ui.supportsColour()

local setTextColour = ui.setTextColour
local setBackgroundColour = ui.setBackgroundColour
local resetColours = ui.resetColours
local clear = ui.clear
local centreAt = ui.centreAt
local drawProgressBar = ui.drawProgressBar
local transition = ui.transition
local pause = ui.pause
local askYesNo = ui.askYesNo
local readDefault = ui.readDefault

local function drawHeader(pageTitle, device)
    screenWidth, screenHeight = ui.getSize()
    compactMode = ui.isCompact()
    return ui.drawHeader(
        pageTitle,
        device,
        CONSOLE_VERSION
    )
end

local function chooseMenu(title, options, device)
    screenWidth, screenHeight = ui.getSize()
    compactMode = ui.isCompact()
    return menu.choose(
        title,
        options,
        device,
        CONSOLE_VERSION
    )
end

local function downloadFile(
    source,
    destination,
    index,
    total
)
    local response, reason =
        http.get(BASE_URL .. source)

    if not response then
        return false,
            "Could not download "
            .. source
            .. ": "
            .. tostring(reason)
    end

    local contents =
        response.readAll()

    response.close()

    local directory =
        fs.getDir(destination)

    if directory ~= ""
        and not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local temporaryPath =
        destination .. ".download"

    if fs.exists(temporaryPath) then
        fs.delete(temporaryPath)
    end

    local file =
        fs.open(temporaryPath, "w")

    if not file then
        return false,
            "Could not write "
            .. destination
    end

    file.write(contents)
    file.close()

    if fs.exists(destination) then
        fs.delete(destination)
    end

    fs.move(
        temporaryPath,
        destination
    )

    if index and total then
        drawProgressBar(
            math.min(screenHeight - 5, 12),
            index / total,
            "Installed "
                .. tostring(index)
                .. " of "
                .. tostring(total)
        )
    end

    return true
end

local function loadManifest()
    local downloaded, reason =
        downloadFile(
            MANIFEST_REMOTE,
            MANIFEST_LOCAL
        )

    if not downloaded then
        return nil, reason
    end

    local success, manifest =
        pcall(
            dofile,
            MANIFEST_LOCAL
        )

    if not success then
        return nil,
            "Could not load manifest: "
            .. tostring(manifest)
    end

    if type(manifest) ~= "table"
        or type(manifest.files) ~= "table" then
        return nil,
            "Manifest has an invalid format"
    end

    return manifest
end

local function loadDeviceConfigModule()
    if not fs.exists(
        DEVICE_CONFIG_MODULE
    ) then
        return nil,
            "Device configuration module is not installed"
    end

    local success, module =
        pcall(
            dofile,
            DEVICE_CONFIG_MODULE
        )

    if not success then
        return nil,
            "Could not load device configuration module: "
            .. tostring(module)
    end

    return module
end

local function getDevice()
    local module =
        loadDeviceConfigModule()

    if not module then
        return {
            address = "UNKNOWN",
            name = "Unconfigured Device",
            type = "UNKNOWN",
            region = "UNKNOWN",
            owner = "MCNet",
            status = "OFFLINE",
            computerID = os.getComputerID(),
            version = CONSOLE_VERSION
        }
    end

    local config =
        module.load(
            DEVICE_CONFIG_PATH
        )

    if not config then
        return module.createDefault()
    end

    return config
end

local function installMCNet()
    transition(
        "Contacting deployment server..."
    )

    drawHeader(
        "Install or update MCNet"
    )

    print("Downloading deployment manifest...")
    print("")

    local manifest, reason =
        loadManifest()

    if not manifest then
        setTextColour(THEME.error)
        print(reason)
        resetColours()
        pause()
        return false
    end

    local name =
        manifest.name or "MCNet"

    local version =
        manifest.version or "UNKNOWN"

    print(
        "Package : "
        .. tostring(name)
    )

    print(
        "Version : "
        .. tostring(version)
    )

    print(
        "Files   : "
        .. tostring(#manifest.files)
    )

    print("")

    local installed = 0
    local failures = {}

    local progressY =
        math.min(screenHeight - 5, 12)

    drawProgressBar(
        progressY,
        0,
        "Preparing installation..."
    )

    for index, entry in ipairs(
        manifest.files
    ) do
        local success, fileReason =
            downloadFile(
                entry.source,
                entry.destination,
                index,
                #manifest.files
            )

        if success then
            installed =
                installed + 1
        else
            table.insert(
                failures,
                fileReason
            )
        end

        sleep(0.08)
    end

    clear()

    drawHeader(
        "Installation complete"
    )

    print(
        "Installed: "
        .. tostring(installed)
    )

    print(
        "Failed   : "
        .. tostring(#failures)
    )

    print("")

    if #failures == 0 then
        setTextColour(THEME.success)
        print(
            "MCNet "
            .. tostring(version)
            .. " installed successfully."
        )

        resetColours()

        print("")
        print(
            "The console may have updated itself."
        )

        print(
            "Restart MCNet after leaving this screen."
        )
    else
        setTextColour(THEME.error)
        print("Some files could not be installed.")
        resetColours()
        print("")

        for _, failure in ipairs(
            failures
        ) do
            print("- " .. tostring(failure))
        end
    end

    print("")

    if #failures == 0
        and askYesNo(
            "Would you like to run tests now?"
        ) then
        return true, "tests"
    end

    pause()

    return #failures == 0
end

local deviceTypes = {
    "SERVER",
    "TOWER",
    "PDA",
    "TRAIN",
    "STATION",
    "POWER",
    "STORAGE",
    "DISPLAY",
    "SECURITY",
    "BUILDING",
    "TEST",
    "UNKNOWN"
}

local function selectDeviceType(currentType)
    local options = {}

    for _, deviceType in ipairs(
        deviceTypes
    ) do
        table.insert(
            options,
            {
                label =
                    deviceType
                    .. (
                        deviceType == currentType
                        and "  [current]"
                        or ""
                    ),
                value = deviceType
            }
        )
    end

    table.insert(
        options,
        {
            label = "Cancel",
            cancel = true
        }
    )

    local selected =
        chooseMenu(
            "Select device type",
            options,
            getDevice()
        )

    if selected.cancel then
        return nil
    end

    return selected.value
end

local function configureDevice()
    transition(
        "Opening device configuration..."
    )

    local module, moduleReason =
        loadDeviceConfigModule()

    if not module then
        drawHeader(
            "Configure this device"
        )

        setTextColour(THEME.error)
        print(moduleReason)
        resetColours()

        print("")
        print(
            "Install or update MCNet first."
        )

        pause()
        return
    end

    local current =
        module.load(
            DEVICE_CONFIG_PATH
        )

    if not current then
        current =
            module.createDefault()
    end

    local selectedType =
        selectDeviceType(
            current.type
        )

    if not selectedType then
        return
    end

    drawHeader(
        "Configure this device",
        current
    )

    print(
        "Enter the identity for this computer."
    )

    print(
        "Press Enter to retain the current value."
    )

    print("")

    local suggestedAddress =
        current.address

    if suggestedAddress == "UNKNOWN"
        and selectedType ~= "UNKNOWN" then
        suggestedAddress =
            selectedType .. "-001"
    end

    local address =
        readDefault(
            "Address",
            suggestedAddress
        )

    local name =
        readDefault(
            "Friendly name",
            current.name
        )

    local region =
        readDefault(
            "Region",
            current.region ~= "UNKNOWN"
                and current.region
                or "HOME"
        )

    local owner =
        readDefault(
            "Owner",
            current.owner or "MCNet"
        )

    local status =
        current.status

    if status == "OFFLINE"
        or status == "UNKNOWN" then
        status = "ONLINE"
    end

    local proposed = {
        address = address,
        name = name,
        type = selectedType,
        region = region,
        owner = owner,
        status = status,
        computerID =
            os.getComputerID(),
        version =
            CONSOLE_VERSION
    }

    proposed =
        module.normalise(
            proposed
        )

    local valid, validReason =
        module.validate(
            proposed
        )

    if not valid then
        print("")
        setTextColour(THEME.error)
        print(
            "Configuration is invalid:"
        )

        print(tostring(validReason))
        resetColours()

        pause()
        return
    end

    drawHeader(
        "Confirm device configuration"
    )

    print(
        "Address    : "
        .. proposed.address
    )

    print(
        "Name       : "
        .. proposed.name
    )

    print(
        "Type       : "
        .. proposed.type
    )

    print(
        "Region     : "
        .. proposed.region
    )

    print(
        "Owner      : "
        .. proposed.owner
    )

    print(
        "Status     : "
        .. proposed.status
    )

    print(
        "Computer ID: "
        .. tostring(
            proposed.computerID
        )
    )

    print("")

    if not askYesNo(
        "Save this configuration?"
    ) then
        print("")
        print(
            "Configuration cancelled."
        )

        pause()
        return
    end

    local saved, saveReason =
        module.save(
            proposed,
            DEVICE_CONFIG_PATH
        )

    print("")

    if saved then
        setTextColour(THEME.success)
        print(
            "Device configured successfully."
        )

        resetColours()

        print("")
        print(
            proposed.address
            .. " is now online."
        )
    else
        setTextColour(THEME.error)
        print(
            "Could not save configuration:"
        )

        print(tostring(saveReason))
        resetColours()
    end

    pause()
end

local function showDeviceInformation()
    transition(
        "Reading device identity...",
        0.3
    )

    local device =
        getDevice()

    drawHeader(
        "Device information",
        device
    )

    print(
        "Friendly name : "
        .. tostring(device.name)
    )

    print(
        "MCNet address : "
        .. tostring(device.address)
    )

    print(
        "Device type   : "
        .. tostring(device.type)
    )

    print(
        "Region        : "
        .. tostring(device.region)
    )

    print(
        "Owner         : "
        .. tostring(device.owner)
    )

    print(
        "Status        : "
        .. tostring(device.status)
    )

    print(
        "Computer ID   : "
        .. tostring(device.computerID)
    )

    print(
        "MCNet version : "
        .. tostring(device.version)
    )

    print(
        "Protocol      : "
        .. tostring(PROTOCOL_VERSION)
    )

    print("")

    if device.address == "UNKNOWN" then
        setTextColour(THEME.highlight)
        print(
            "This computer has not been configured."
        )

        resetColours()
    else
        setTextColour(THEME.success)
        print(
            "Device identity is configured."
        )

        resetColours()
    end

    pause()
end

local tests = {
    {
        label = "Packet protocol tests",
        path =
            "tests/communications/packet_test.lua"
    },
    {
        label = "Modem driver tests",
        path =
            "tests/drivers/modem_test.lua"
    },
    {
        label = "Device configuration tests",
        path =
            "tests/system/device_config_test.lua"
    }
}

local function runTest(test)
    transition(
        "Loading " .. test.label .. "...",
        0.3
    )

    clear()

    centreAt(
        1,
        test.label,
        THEME.title
    )

    centreAt(
        2,
        string.rep("=", #test.label),
        THEME.accent
    )

    print("")
    resetColours()

    if not fs.exists(test.path) then
        setTextColour(THEME.error)
        print(
            "Test file is not installed:"
        )

        print(test.path)
        resetColours()
        pause()
        return
    end

    local completed =
        shell.run(test.path)

    print("")

    if completed then
        setTextColour(THEME.success)
        print(
            "Test program completed."
        )
    else
        setTextColour(THEME.error)
        print(
            "Test program returned an error."
        )
    end

    resetColours()
    pause()
end

local function runAllTests()
    for _, test in ipairs(tests) do
        runTest(test)
    end
end

local function testMenu()
    while true do
        local device =
            getDevice()

        local options = {
            {
                label = "Run packet protocol tests",
                action = function()
                    runTest(tests[1])
                end
            },
            {
                label = "Run modem driver tests",
                action = function()
                    runTest(tests[2])
                end
            },
            {
                label = "Run device configuration tests",
                action = function()
                    runTest(tests[3])
                end
            },
            {
                label = "Run all tests",
                action = runAllTests
            },
            {
                label = "Return to main menu",
                back = true
            }
        }

        local selected =
            chooseMenu(
                "Diagnostics",
                options,
                device
            )

        if selected.back then
            return
        end

        selected.action()
    end
end

local function systemInformation()
    transition(
        "Reading system information...",
        0.3
    )

    local device =
        getDevice()

    drawHeader(
        "System information",
        device
    )

    local freeSpace =
        fs.getFreeSpace("/")

    print(
        "Computer ID    : "
        .. tostring(
            os.getComputerID()
        )
    )

    print(
        "Computer label : "
        .. tostring(
            os.getComputerLabel()
                or "None"
        )
    )

    print(
        "Console version: "
        .. CONSOLE_VERSION
    )

    print(
        "Packet protocol: "
        .. tostring(
            PROTOCOL_VERSION
        )
    )

    print(
        "Free space     : "
        .. tostring(freeSpace)
        .. " bytes"
    )

    print(
        "Colour display : "
        .. (
            supportsColour
            and "Yes"
            or "No"
        )
    )

    print(
        "Device config  : "
        .. (
            fs.exists(
                DEVICE_CONFIG_PATH
            )
            and "Present"
            or "Missing"
        )
    )

    pause()
end

local function main()
    transition(
        "Starting MCNet Console...",
        0.65
    )

    while true do
        local device =
            getDevice()

        local options = {
            {
                label =
                    compactMode
                    and "Install / update"
                    or "Install or update MCNet",
                action = function()
                    local success, result =
                        installMCNet()

                    if success
                        and result == "tests" then
                        testMenu()
                    end
                end
            },
            {
                label =
                    compactMode
                    and "Configure device"
                    or "Configure this device",
                action =
                    configureDevice
            },
            {
                label =
                    compactMode
                    and "View device"
                    or "View device information",
                action =
                    showDeviceInformation
            },
            {
                label =
                    compactMode
                    and "Diagnostics"
                    or "Diagnostics and tests",
                action =
                    testMenu
            },
            {
                label =
                    compactMode
                    and "System info"
                    or "System information",
                action =
                    systemInformation
            },
            {
                label = "Exit",
                exit = true
            }
        }

        local selected =
            chooseMenu(
                "Main menu",
                options,
                device
            )

        if selected.exit then
            transition(
                "Closing MCNet Console...",
                0.3
            )

            clear()

            centreAt(
                3,
                "MCNet Console",
                THEME.title
            )

            centreAt(
                5,
                "Connection closed.",
                THEME.muted
            )

            resetColours()
            term.setCursorPos(
                1,
                screenHeight
            )

            print("")
            return
        end

        selected.action()
    end
end

local success, reason =
    pcall(main)

resetColours()

if not success then
    clear()

    setTextColour(THEME.error)
    print("MCNet Console encountered an error:")
    resetColours()
    print("")
    print(tostring(reason))
    print("")
end