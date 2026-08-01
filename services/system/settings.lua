-- MCNet persistent console settings

local module = {}
local PATH = ".mcnet/settings.lua"

local defaults = {
    theme = "green",
    animations = true,
    logo = "random",
    layout = "auto",
    display = "native",
    monitorScale = 1,
    showFooter = true,
    showStatus = true,
    bootTarget = "console"
}

local function copyTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

local function allowed(value, choices, fallback)
    for _, choice in ipairs(choices) do
        if value == choice then
            return value
        end
    end
    return fallback
end

function module.default()
    return copyTable(defaults)
end

function module.normalise(settings)
    local result = module.default()
    settings = settings or {}

    for key, value in pairs(settings) do
        result[key] = value
    end

    result.theme = allowed(result.theme, { "green", "amber", "ice", "redstone", "monochrome" }, "green")
    result.logo = allowed(result.logo, { "random", "creeper", "skeleton", "zombie", "spider", "enderman", "blaze", "off" }, "random")
    result.layout = allowed(result.layout, { "auto", "compact", "full" }, "auto")
    result.bootTarget = allowed(result.bootTarget, { "console", "role" }, "console")

    result.animations = result.animations ~= false
    result.showFooter = result.showFooter ~= false
    result.showStatus = result.showStatus ~= false

    if type(result.display) ~= "string" or result.display == "" then
        result.display = "native"
    end

    result.monitorScale = tonumber(result.monitorScale) or 1
    result.monitorScale = math.floor(result.monitorScale * 2 + 0.5) / 2

    if result.monitorScale < 0.5 then
        result.monitorScale = 0.5
    elseif result.monitorScale > 5 then
        result.monitorScale = 5
    end

    return result
end

function module.load(path)
    path = path or PATH

    if not fs.exists(path) then
        return module.default()
    end

    local loaded, settings = pcall(dofile, path)
    if not loaded or type(settings) ~= "table" then
        return module.default()
    end

    return module.normalise(settings)
end

function module.save(settings, path)
    path = path or PATH
    settings = module.normalise(settings)

    local directory = fs.getDir(path)
    if directory ~= "" and not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local file = fs.open(path, "w")
    if not file then
        return false, "Could not open settings file"
    end

    file.write("return ")
    file.write(textutils.serialize(settings))
    file.write("\n")
    file.close()
    return true
end

function module.reset(path)
    local settings = module.default()
    local saved, reason = module.save(settings, path)
    return saved, reason, settings
end

function module.getPath()
    return PATH
end

return module
