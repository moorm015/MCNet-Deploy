--[[
    MCNet Console
    Version: 0.5.0

    Installation, device configuration and diagnostic console.
]]

local CONSOLE_VERSION = "0.5.0"
local PROTOCOL_VERSION = 1

local BASE_URL =
    "https://raw.githubusercontent.com/moorm015/MCNet-Deploy/main/"

local MANIFEST_REMOTE = "mcnet-manifest.lua"
local MANIFEST_LOCAL = ".mcnet-manifest.lua"

local DEVICE_CONFIG_MODULE =
    "services/system/device_config.lua"

local DEVICE_CONFIG_PATH =
    ".mcnet/device.lua"

local screenWidth, screenHeight = term.getSize()

local supportsColour = false

if term.isColor then
    supportsColour = term.isColor()
elseif term.isColour then
    supportsColour = term.isColour()
end

local THEME = {
    background = colors.black,
    foreground = colors.white,
    muted = colors.lightGray,
    title = colors.lime,
    accent = colors.green,
    highlight = colors.yellow,
    error = colors.red,
    success = colors.lime
}

local function setTextColour(colour)
    if supportsColour then
        term.setTextColor(colour)
    end
end

local function setBackgroundColour(colour)
    if supportsColour then
        term.setBackgroundColor(colour)
    end
end

local function resetColours()
    setBackgroundColour(colors.black)
    setTextColour(colors.white)
end

local function clear()
    resetColours()
    term.clear()
    term.setCursorPos(1, 1)
end

local function centreX(text)
    return math.max(
        1,
        math.floor((screenWidth - #text) / 2) + 1
    )
end

local function writeAt(x, y, text, colour)
    term.setCursorPos(x, y)

    if colour then
        setTextColour(colour)
    end

    write(text)
end

local function centreAt(y, text, colour)
    writeAt(centreX(text), y, text, colour)
end

local creeperLogo = {
    "  ########  ",
    " ########## ",
    " ########## ",
    " ##  ##  ## ",
    " ##  ##  ## ",
    " ########## ",
    " ####  #### ",
    " ###    ### ",
    " ### ## ### "
}

local function drawCreeper(startY)
    for index, line in ipairs(creeperLogo) do
        centreAt(
            startY + index - 1,
            line,
            THEME.accent
        )
    end
end

local function drawProgressBar(y, progress, label)
    local maximumBarWidth = 34
    local barWidth = math.min(
        maximumBarWidth,
        screenWidth - 8
    )

    if barWidth < 10 then
        barWidth = 10
    end

    progress = math.max(0, math.min(1, progress))

    local filled =
        math.floor(barWidth * progress)

    local empty =
        barWidth - filled

    local bar =
        "["
        .. string.rep("=", filled)
        .. string.rep(" ", empty)
        .. "]"

    local percentage =
        tostring(math.floor(progress * 100)) .. "%"

    centreAt(y, bar, THEME.accent)
    centreAt(y + 1, percentage, THEME.foreground)

    if label then
        centreAt(y + 3, label, THEME.muted)
    end
end

local function transition(label, duration)
    duration = duration or 0.45

    clear()

    centreAt(1, "MCNet", THEME.title)
    centreAt(2, "Network Systems Console", THEME.muted)

    drawCreeper(4)

    local barY = math.min(screenHeight - 4, 14)
    local steps = 24

    for step = 0, steps do
        local progress = step / steps

        drawProgressBar(
            barY,
            progress,
            label or "Loading..."
        )

        local delay = duration / steps

        -- Small pauses make the bar feel as though it is buffering.
        if step == 7 or step == 16 then
            delay = delay * 2.8
        elseif step == 12 then
            delay = delay * 1.8
        end

        sleep(delay)
    end
end

local function drawHeader(pageTitle, device)
    clear()

    setTextColour(THEME.title)
    centreAt(1, "MCNet Console", THEME.title)

    centreAt(
        2,
        string.rep("=", 13),
        THEME.accent
    )

    writeAt(
        2,
        4,
        pageTitle,
        THEME.foreground
    )

    local versionText =
        "v" .. CONSOLE_VERSION

    writeAt(
        screenWidth - #versionText,
        1,
        versionText,
        THEME.muted
    )

    if device then
        local address =
            device.address or "UNKNOWN"

        local name =
            device.name or "Unconfigured Device"

        writeAt(
            2,
            6,
            "Device : " .. name,
            THEME.muted
        )

        writeAt(
            2,
            7,
            "Address: " .. address,
            address == "UNKNOWN"
                and THEME.highlight
                or THEME.success
        )

        return 9
    end

    return 6
end

local function pause(message)
    resetColours()
    print("")
    write(message or "Press Enter to continue...")
    read()
end

local function askYesNo(question)
    while true do
        write(question .. " (Y/N): ")

        local answer =
            string.lower(read())

        if answer == "y"
            or answer == "yes" then
            return true
        end

        if answer == "n"
            or answer == "no" then
            return false
        end

        setTextColour(THEME.error)
        print("Please enter Y or N.")
        setTextColour(THEME.foreground)
    end
end

local function readDefault(prompt, default)
    write(prompt)

    if default and default ~= "" then
        setTextColour(THEME.muted)
        write(" [" .. tostring(default) .. "]")
        setTextColour(THEME.foreground)
    end

    write(": ")

    local value = read()

    if value == "" then
        return default
    end

    return value
end

local function chooseMenu(title, options, device)
    local selected = 1

    while true do
        local startY =
            drawHeader(title, device)

        for index, option in ipairs(options) do
            local y =
                startY + index - 1

            if index == selected then
                setBackgroundColour(THEME.accent)
                setTextColour(colors.black)

                writeAt(
                    3,
                    y,
                    " " .. option.label .. " "
                )

                resetColours()
            else
                writeAt(
                    3,
                    y,
                    "  " .. option.label,
                    THEME.foreground
                )
            end
        end

        local instructionY =
            math.min(
                screenHeight,
                startY + #options + 2
            )

        writeAt(
            3,
            instructionY,
            "Up/Down: select   Enter: open",
            THEME.muted
        )

        local event = {
            os.pullEvent()
        }

        if event[1] == "key" then
            local key = event[2]

            if key == keys.up then
                selected = selected - 1

                if selected < 1 then
                    selected = #options
                end
            elseif key == keys.down then
                selected = selected + 1

                if selected > #options then
                    selected = 1
                end
            elseif key == keys.enter then
                return options[selected]
            end
        elseif event[1] == "char" then
            local number =
                tonumber(event[2])

            if number
                and number >= 1
                and number <= #options then
                return options[number]
            end
        end
    end
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
                    "Install or update MCNet",
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
                    "Configure this device",
                action =
                    configureDevice
            },
            {
                label =
                    "View device information",
                action =
                    showDeviceInformation
            },
            {
                label =
                    "Diagnostics and tests",
                action =
                    testMenu
            },
            {
                label =
                    "System information",
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