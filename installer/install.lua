--[[
    MCNet Installer
    Version: 0.3.0
]]

local baseURL =
    "https://raw.githubusercontent.com/moorm015/MCNet-Deploy/main/"

local manifestRemotePath = "mcnet-manifest.lua"
local manifestLocalPath = ".mcnet-manifest.lua"

local function centre(text)
    local width = term.getSize()
    local x = math.floor((width - #text) / 2) + 1

    if x < 1 then
        x = 1
    end

    term.setCursorPos(x, select(2, term.getCursorPos()))
    print(text)
end

local function heading(title)
    term.clear()
    term.setCursorPos(1, 1)

    centre("MCNet Installer")
    centre("===============")

    print("")
    print(title)
    print("")
end

local function pause()
    print("")
    write("Press Enter to continue...")
    read()
end

local function askYesNo(question)
    while true do
        write(question .. " (Y/N): ")

        local answer = string.lower(read())

        if answer == "y" or answer == "yes" then
            return true
        end

        if answer == "n" or answer == "no" then
            return false
        end

        print("Please enter Y or N.")
    end
end

local function chooseOption(title, options)
    while true do
        heading(title)

        for index, option in ipairs(options) do
            print(
                tostring(index)
                .. ". "
                .. option.label
            )
        end

        print("")
        write("Select an option: ")

        local selected = tonumber(read())

        if selected
            and selected >= 1
            and selected <= #options then
            return options[selected]
        end

        print("")
        print("Invalid selection.")
        sleep(1)
    end
end

local function downloadFile(source, destination)
    print("Downloading " .. source)

    local response, reason = http.get(baseURL .. source)

    if not response then
        print("Failed: " .. tostring(reason))
        return false
    end

    local contents = response.readAll()
    response.close()

    local directory = fs.getDir(destination)

    if directory ~= ""
        and not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local file = fs.open(destination, "w")

    if not file then
        print("Could not write " .. destination)
        return false
    end

    file.write(contents)
    file.close()

    print("Installed " .. destination)
    return true
end

local function loadManifest()
    if not downloadFile(
        manifestRemotePath,
        manifestLocalPath
    ) then
        return nil, "Could not download MCNet manifest"
    end

    local success, manifest =
        pcall(dofile, manifestLocalPath)

    if not success then
        return nil,
            "Could not load manifest: "
            .. tostring(manifest)
    end

    if type(manifest) ~= "table"
        or type(manifest.files) ~= "table" then
        return nil, "Invalid MCNet manifest"
    end

    return manifest
end

local function installMCNet()
    heading("Install or update MCNet")

    local manifest, reason = loadManifest()

    if not manifest then
        print(reason)
        pause()
        return false
    end

    print("")
    print(
        "Installing "
        .. tostring(manifest.name or "MCNet")
        .. " "
        .. tostring(manifest.version)
    )
    print("")

    local installed = 0
    local failed = 0

    for _, entry in ipairs(manifest.files) do
        if downloadFile(
            entry.source,
            entry.destination
        ) then
            installed = installed + 1
        else
            failed = failed + 1
        end
    end

    print("")
    print("Installation complete")
    print("Installed: " .. tostring(installed))
    print("Failed: " .. tostring(failed))

    pause()

    return failed == 0
end

local tests = {
    {
        label = "Packet tests",
        path = "tests/communications/packet_test.lua"
    },
    {
        label = "Modem driver tests",
        path = "tests/drivers/modem_test.lua"
    }
}

local function runTest(test)
    heading(test.label)

    if not fs.exists(test.path) then
        print("Test file is not installed:")
        print(test.path)
        pause()
        return
    end

    print("Running " .. test.label .. "...")
    print("")

    local success = shell.run(test.path)

    print("")

    if success then
        print("Test program completed.")
    else
        print("Test program returned an error.")
    end

    pause()
end

local function runAllTests()
    heading("Run all tests")

    for _, test in ipairs(tests) do
        print("Running " .. test.label .. "...")
        print("")

        if fs.exists(test.path) then
            shell.run(test.path)
        else
            print("Missing test file:")
            print(test.path)
        end

        print("")
        print("------------------------------")
        print("")
    end

    pause()
end

local function testMenu()
    while true do
        local options = {
            {
                label = "Run packet tests",
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
                label = "Run all tests",
                action = runAllTests
            },
            {
                label = "Return to main menu",
                exit = true
            }
        }

        local selected =
            chooseOption("Test menu", options)

        if selected.exit then
            return
        end

        selected.action()
    end
end

local function main()
    while true do
        local options = {
            {
                label = "Install or update MCNet",
                action = function()
                    local installed = installMCNet()

                    if installed
                        and askYesNo(
                            "Would you like to run tests now?"
                        ) then
                        testMenu()
                    end
                end
            },
            {
                label = "Run tests",
                action = testMenu
            },
            {
                label = "Exit",
                exit = true
            }
        }

        local selected =
            chooseOption("Main menu", options)

        if selected.exit then
            heading("Exit")
            print("MCNet installer closed.")
            return
        end

        selected.action()
    end
end

main()