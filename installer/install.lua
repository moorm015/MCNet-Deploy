-- MCNet standalone installer
-- Version 1.1.0
--
-- Standalone: depends on no installed MCNet files.
--
-- v1.1 changes:
--   * Downloads and commits ONE file at a time, so updates no longer need
--     enough free space for a second complete MCNet installation.
--   * Remains compatible with the current v0.9.2 full manifest.
--   * Adds support for a future modular manifest using package tags.
--   * Reads .mcnet/device.lua so a modular manifest can install only the
--     packages needed by the configured device role.
--   * Removes only manifest-managed files that are no longer selected.
--   * Leaves persistent .mcnet configuration alone unless manifest.remove
--     explicitly names a path.

local BASE_URL = "https://raw.githubusercontent.com/moorm015/MCNet-Deploy/main/"
local MANIFEST_REMOTE = "mcnet-manifest.lua"
local MANIFEST_LOCAL = ".mcnet-manifest.lua"

local TEMP_ROOT = ".mcnet-stage"
local TEMP_FILE = TEMP_ROOT .. "/download.file"
local BACKUP_FILE = TEMP_ROOT .. "/previous.file"

local INSTALL_STATE = ".mcnet/install_state.lua"
local DEVICE_CONFIG = ".mcnet/device.lua"

local width, height = term.getSize()
local hasColour = false

if term.isColor then
    hasColour = term.isColor()
elseif term.isColour then
    hasColour = term.isColour()
end

local function setText(colour)
    if hasColour then
        term.setTextColor(colour)
    end
end

local function setBackground(colour)
    if hasColour then
        term.setBackgroundColor(colour)
    end
end

local function resetColours()
    setBackground(colors.black)
    setText(colors.white)
end

local function refreshSize()
    width, height = term.getSize()
end

local function clear()
    refreshSize()
    resetColours()
    term.clear()
    term.setCursorPos(1, 1)
end

local function clip(value, maximum)
    local text = tostring(value or "")
    maximum = math.max(0, maximum or width)

    if #text <= maximum then
        return text
    end

    if maximum <= 3 then
        return string.sub(text, 1, maximum)
    end

    return string.sub(text, 1, maximum - 3) .. "..."
end

local function centre(y, text, colour)
    refreshSize()
    text = clip(text, width)

    local x = math.max(
        1,
        math.floor((width - #text) / 2) + 1
    )

    term.setCursorPos(x, y)

    if colour then
        setText(colour)
    end

    write(text)
end

local function header(subtitle)
    clear()
    centre(1, "MCNet Installer", colors.lime)
    centre(
        2,
        string.rep("=", math.min(15, width)),
        colors.green
    )

    if subtitle then
        centre(4, subtitle, colors.lightGray)
    end

    resetColours()
end

local function progress(current, total, label)
    refreshSize()

    local y = math.max(
        6,
        math.min(height - 3, 11)
    )

    local barWidth = math.max(
        8,
        math.min(30, width - 8)
    )

    local fraction = 0
    if total > 0 then
        fraction = current / total
    end

    fraction = math.max(0, math.min(1, fraction))

    local filled = math.floor(barWidth * fraction)
    local bar =
        "["
        .. string.rep("=", filled)
        .. string.rep(" ", barWidth - filled)
        .. "]"

    centre(y, bar, colors.green)
    centre(
        y + 1,
        tostring(current) .. "/" .. tostring(total),
        colors.white
    )
    centre(
        y + 2,
        clip(label or "", math.max(1, width - 4)),
        colors.lightGray
    )
    resetColours()
end

local function safePath(path)
    if type(path) ~= "string" or path == "" then
        return false
    end

    if string.sub(path, 1, 1) == "/" then
        return false
    end

    if string.find(path, "..", 1, true) then
        return false
    end

    return true
end

local function ensureDirectory(path)
    local directory = fs.getDir(path)

    if directory ~= "" and not fs.exists(directory) then
        fs.makeDir(directory)
    end
end

local function deleteIfExists(path)
    if fs.exists(path) then
        fs.delete(path)
    end
end

local function cleanTemporary()
    if fs.exists(TEMP_ROOT) then
        fs.delete(TEMP_ROOT)
    end
end

local function prepareTemporary()
    cleanTemporary()
    fs.makeDir(TEMP_ROOT)
end

local function writeFile(path, contents)
    ensureDirectory(path)
    deleteIfExists(path)

    local file = fs.open(path, "w")
    if not file then
        return false, "Could not write " .. path
    end

    local ok, reason = pcall(function()
        file.write(contents)
    end)

    file.close()

    if not ok then
        deleteIfExists(path)
        return false, tostring(reason)
    end

    return true
end

local function downloadText(path)
    if not http or not http.get then
        return nil, "HTTP is disabled or unavailable"
    end

    local response, reason = http.get(BASE_URL .. path)

    if not response then
        return nil,
            "Could not download "
            .. path
            .. ": "
            .. tostring(reason)
    end

    local contents = response.readAll()
    response.close()

    if not contents or #contents == 0 then
        return nil, "Downloaded file was empty: " .. path
    end

    return contents
end

local function loadManifest()
    local contents, reason = downloadText(MANIFEST_REMOTE)
    if not contents then
        return nil, reason
    end

    local written, writeReason =
        writeFile(MANIFEST_LOCAL, contents)

    if not written then
        return nil, writeReason
    end

    local loaded, manifest = pcall(dofile, MANIFEST_LOCAL)

    if not loaded then
        return nil, "Manifest error: " .. tostring(manifest)
    end

    if type(manifest) ~= "table"
        or type(manifest.files) ~= "table"
    then
        return nil, "Manifest format is invalid"
    end

    if #manifest.files == 0 then
        return nil, "Manifest does not contain any files"
    end

    return manifest
end

local function loadDeviceRole()
    if not fs.exists(DEVICE_CONFIG) then
        return nil
    end

    local loaded, device = pcall(dofile, DEVICE_CONFIG)

    if not loaded
        or type(device) ~= "table"
        or type(device.type) ~= "string"
    then
        return nil
    end

    local role = string.upper(device.type)

    if role == "" or role == "UNKNOWN" then
        return nil
    end

    return role
end

local function addPackage(set, value)
    if type(value) == "string" and value ~= "" then
        set[string.upper(value)] = true
    end
end

local function addPackageList(set, values)
    if type(values) == "string" then
        addPackage(set, values)
        return
    end

    if type(values) ~= "table" then
        return
    end

    for _, value in ipairs(values) do
        addPackage(set, value)
    end
end

local function selectedPackages(manifest, role)
    -- No package table means the existing full-manifest behaviour.
    if type(manifest.packages) ~= "table" then
        return nil
    end

    local selected = {}

    addPackageList(selected, manifest.packages.default)

    local roles = manifest.packages.roles

    if type(roles) == "table" then
        if role and roles[role] then
            addPackageList(selected, roles[role])
        elseif roles.DEFAULT then
            addPackageList(selected, roles.DEFAULT)
        end
    end

    return selected
end

local function entrySelected(entry, packages)
    if not packages then
        return true
    end

    -- Untagged files stay installed during migration. Once we update the
    -- manifest, every role-specific file will receive a package tag.
    if entry.packages == nil then
        return true
    end

    if type(entry.packages) == "string" then
        return packages[string.upper(entry.packages)] == true
    end

    if type(entry.packages) ~= "table" then
        return false
    end

    for _, name in ipairs(entry.packages) do
        if type(name) == "string"
            and packages[string.upper(name)]
        then
            return true
        end
    end

    return false
end

local function selectFiles(manifest, packages)
    local selected = {}
    local unselected = {}

    for index, entry in ipairs(manifest.files) do
        if type(entry) ~= "table" then
            return nil, nil,
                "Invalid manifest entry " .. tostring(index)
        end

        if not safePath(entry.source)
            or not safePath(entry.destination)
        then
            return nil, nil,
                "Unsafe manifest path in entry " .. tostring(index)
        end

        if entrySelected(entry, packages) then
            table.insert(selected, entry)
        else
            table.insert(unselected, entry)
        end
    end

    if #selected == 0 then
        return nil, nil,
            "No files were selected for this device"
    end

    return selected, unselected
end

local function getPackageNames(packages)
    local result = {}

    if not packages then
        return result
    end

    for name, enabled in pairs(packages) do
        if enabled then
            table.insert(result, name)
        end
    end

    table.sort(result)
    return result
end

local function replaceFile(destination, contents)
    deleteIfExists(TEMP_FILE)
    deleteIfExists(BACKUP_FILE)

    local written, reason =
        writeFile(TEMP_FILE, contents)

    if not written then
        return false, reason
    end

    ensureDirectory(destination)

    local hadExisting = fs.exists(destination)

    if hadExisting then
        local backedUp, backupReason =
            pcall(
                fs.move,
                destination,
                BACKUP_FILE
            )

        if not backedUp then
            deleteIfExists(TEMP_FILE)
            return false,
                "Could not prepare "
                .. destination
                .. ": "
                .. tostring(backupReason)
        end
    end

    local committed, commitReason =
        pcall(
            fs.move,
            TEMP_FILE,
            destination
        )

    if not committed then
        if hadExisting
            and fs.exists(BACKUP_FILE)
            and not fs.exists(destination)
        then
            pcall(
                fs.move,
                BACKUP_FILE,
                destination
            )
        end

        deleteIfExists(TEMP_FILE)

        return false,
            "Could not install "
            .. destination
            .. ": "
            .. tostring(commitReason)
    end

    deleteIfExists(BACKUP_FILE)
    return true
end

local function removeObsolete(manifest, unselected)
    -- Only modular manifests remove deselected package files.
    if type(manifest.packages) == "table" then
        for _, entry in ipairs(unselected or {}) do
            local path = entry.destination

            if safePath(path) and fs.exists(path) then
                fs.delete(path)
            end
        end
    end

    if type(manifest.remove) == "table" then
        for _, path in ipairs(manifest.remove) do
            if safePath(path) and fs.exists(path) then
                fs.delete(path)
            end
        end
    end
end

local function writeInstallState(
    manifest,
    role,
    packages,
    selected
)
    ensureDirectory(INSTALL_STATE)

    local installedFiles = {}

    for _, entry in ipairs(selected) do
        table.insert(installedFiles, entry.destination)
    end

    local state = {
        name = manifest.name or "MCNet",
        version = manifest.version or "UNKNOWN",
        protocol = manifest.protocol or 1,
        entrypoint = manifest.entrypoint or "kernel/boot.lua",
        files = #selected,
        installedFiles = installedFiles,
        role = role or "UNCONFIGURED",
        packages = getPackageNames(packages),
        modular = type(manifest.packages) == "table",
        computerID = os.getComputerID()
    }

    local file = fs.open(INSTALL_STATE, "w")
    if not file then
        return false, "Could not write install metadata"
    end

    local ok, reason = pcall(function()
        file.write("return ")
        file.write(textutils.serialize(state))
        file.write("\n")
    end)

    file.close()

    if not ok then
        return false, tostring(reason)
    end

    return true
end

local function install()
    cleanTemporary()
    header("Contacting deployment server...")

    local manifest, reason = loadManifest()
    if not manifest then
        error(reason, 0)
    end

    local role = loadDeviceRole()
    local packages = selectedPackages(manifest, role)

    local selected, unselected, selectReason =
        selectFiles(manifest, packages)

    if not selected then
        error(selectReason, 0)
    end

    header("Preparing " .. tostring(manifest.name or "MCNet"))
    print("")
    print("Package : " .. tostring(manifest.name or "MCNet"))
    print("Version : " .. tostring(manifest.version or "UNKNOWN"))
    print("Device  : " .. tostring(role or "UNCONFIGURED"))

    if packages then
        local names = getPackageNames(packages)
        print("Mode    : Modular")
        print(
            "Packages: "
            .. (
                #names > 0
                and table.concat(names, ", ")
                or "shared only"
            )
        )
    else
        print("Mode    : Legacy/full")
    end

    print(
        "Files   : "
        .. tostring(#selected)
        .. "/"
        .. tostring(#manifest.files)
    )
    print("")

    prepareTemporary()

    for index, entry in ipairs(selected) do
        progress(
            index - 1,
            #selected,
            "Downloading " .. entry.source
        )

        local contents, downloadReason =
            downloadText(entry.source)

        if not contents then
            cleanTemporary()
            error(downloadReason, 0)
        end

        progress(
            index - 1,
            #selected,
            "Installing " .. entry.destination
        )

        local installed, installReason =
            replaceFile(entry.destination, contents)

        if not installed then
            cleanTemporary()
            error(installReason, 0)
        end

        sleep(0.02)
    end

    progress(
        #selected,
        #selected,
        "Removing obsolete packages"
    )

    removeObsolete(manifest, unselected)

    local metadataWritten, metadataReason =
        writeInstallState(
            manifest,
            role,
            packages,
            selected
        )

    if not metadataWritten then
        cleanTemporary()
        error(metadataReason, 0)
    end

    cleanTemporary()

    header("Installation complete")
    print("")
    setText(colors.lime)
    print(
        "MCNet "
        .. tostring(manifest.version or "")
        .. " installed."
    )
    resetColours()
    print("")
    print("Installed " .. tostring(#selected) .. " files.")
    print("The bootstrap will reboot this device.")
end

local completed, reason = pcall(install)
resetColours()

if not completed then
    cleanTemporary()
    clear()
    setText(colors.red)
    print("MCNet installation failed:")
    resetColours()
    print("")
    print(tostring(reason))
    print("")
    error("Installation stopped", 0)
end