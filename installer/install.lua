-- MCNet standalone installer
-- Version 1.0.0
--
-- This program deliberately depends on no installed MCNet files.
-- It downloads the manifest, stages every listed file, commits the
-- installation, performs manifest removals, and writes install metadata.

local BASE_URL = "https://raw.githubusercontent.com/moorm015/MCNet-Deploy/main/"
local MANIFEST_REMOTE = "mcnet-manifest.lua"
local MANIFEST_LOCAL = ".mcnet-manifest.lua"
local STAGE_ROOT = ".mcnet-stage"
local INSTALL_STATE = ".mcnet/install_state.lua"

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
    local x = math.max(1, math.floor((width - #text) / 2) + 1)
    term.setCursorPos(x, y)
    if colour then
        setText(colour)
    end
    write(text)
end

local function header(subtitle)
    clear()
    centre(1, "MCNet Installer", colors.lime)
    centre(2, string.rep("=", math.min(15, width)), colors.green)
    if subtitle then
        centre(4, subtitle, colors.lightGray)
    end
    resetColours()
end

local function progress(current, total, label)
    refreshSize()
    local y = math.max(6, math.min(height - 3, 11))
    local barWidth = math.max(8, math.min(30, width - 8))
    local fraction = 0

    if total > 0 then
        fraction = current / total
    end

    fraction = math.max(0, math.min(1, fraction))
    local filled = math.floor(barWidth * fraction)
    local bar = "[" .. string.rep("=", filled) .. string.rep(" ", barWidth - filled) .. "]"

    centre(y, bar, colors.green)
    centre(y + 1, tostring(current) .. "/" .. tostring(total), colors.white)
    centre(y + 2, clip(label or "", math.max(1, width - 4)), colors.lightGray)
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

local function writeFile(path, contents)
    ensureDirectory(path)

    if fs.exists(path) then
        fs.delete(path)
    end

    local file = fs.open(path, "w")
    if not file then
        return false, "Could not write " .. path
    end

    file.write(contents)
    file.close()
    return true
end

local function downloadText(path)
    if not http or not http.get then
        return nil, "HTTP is disabled or unavailable"
    end

    local response, reason = http.get(BASE_URL .. path)
    if not response then
        return nil, "Could not download " .. path .. ": " .. tostring(reason)
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

    local written, writeReason = writeFile(MANIFEST_LOCAL, contents)
    if not written then
        return nil, writeReason
    end

    local loaded, manifest = pcall(dofile, MANIFEST_LOCAL)
    if not loaded then
        return nil, "Manifest error: " .. tostring(manifest)
    end

    if type(manifest) ~= "table" or type(manifest.files) ~= "table" then
        return nil, "Manifest format is invalid"
    end

    if #manifest.files == 0 then
        return nil, "Manifest does not contain any files"
    end

    return manifest
end

local function cleanStage()
    if fs.exists(STAGE_ROOT) then
        fs.delete(STAGE_ROOT)
    end
end

local function writeInstallState(manifest)
    ensureDirectory(INSTALL_STATE)

    local state = {
        name = manifest.name or "MCNet",
        version = manifest.version or "UNKNOWN",
        protocol = manifest.protocol or 1,
        entrypoint = manifest.entrypoint or "kernel/boot.lua",
        files = #manifest.files,
        computerID = os.getComputerID()
    }

    local file = fs.open(INSTALL_STATE, "w")
    if not file then
        return false, "Could not write install metadata"
    end

    file.write("return ")
    file.write(textutils.serialize(state))
    file.write("\n")
    file.close()
    return true
end

local function install()
    cleanStage()
    header("Contacting deployment server...")

    local manifest, reason = loadManifest()
    if not manifest then
        error(reason, 0)
    end

    header("Preparing " .. tostring(manifest.name or "MCNet"))
    print("")
    print("Package : " .. tostring(manifest.name or "MCNet"))
    print("Version : " .. tostring(manifest.version or "UNKNOWN"))
    print("Files   : " .. tostring(#manifest.files))
    print("")

    fs.makeDir(STAGE_ROOT)
    local staged = {}

    for index, entry in ipairs(manifest.files) do
        if type(entry) ~= "table" then
            cleanStage()
            error("Invalid manifest entry " .. tostring(index), 0)
        end

        if not safePath(entry.source) or not safePath(entry.destination) then
            cleanStage()
            error("Unsafe manifest path in entry " .. tostring(index), 0)
        end

        progress(index - 1, #manifest.files, "Downloading " .. entry.source)

        local contents, downloadReason = downloadText(entry.source)
        if not contents then
            cleanStage()
            error(downloadReason, 0)
        end

        local stagedPath = STAGE_ROOT .. "/" .. string.format("%03d", index) .. ".file"
        local written, writeReason = writeFile(stagedPath, contents)
        if not written then
            cleanStage()
            error(writeReason, 0)
        end

        table.insert(staged, {
            stagedPath = stagedPath,
            destination = entry.destination
        })

        sleep(0.02)
    end

    progress(#manifest.files, #manifest.files, "Committing installation")

    for _, item in ipairs(staged) do
        ensureDirectory(item.destination)

        if fs.exists(item.destination) then
            fs.delete(item.destination)
        end

        fs.move(item.stagedPath, item.destination)
    end

    if type(manifest.remove) == "table" then
        for _, path in ipairs(manifest.remove) do
            if safePath(path) and fs.exists(path) then
                fs.delete(path)
            end
        end
    end

    local metadataWritten, metadataReason = writeInstallState(manifest)
    if not metadataWritten then
        cleanStage()
        error(metadataReason, 0)
    end

    cleanStage()
    header("Installation complete")
    print("")
    setText(colors.lime)
    print("MCNet " .. tostring(manifest.version or "") .. " installed.")
    resetColours()
    print("")
    print("Installed " .. tostring(#manifest.files) .. " files.")
    print("The bootstrap will reboot this device.")
end

local completed, reason = pcall(install)
resetColours()

if not completed then
    cleanStage()
    clear()
    setText(colors.red)
    print("MCNet installation failed:")
    resetColours()
    print("")
    print(tostring(reason))
    print("")
    error("Installation stopped", 0)
end
