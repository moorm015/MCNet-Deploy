-- MCNet multi-monitor display-wall configuration
-- Version 0.9.0

local module = {}
local PATH = ".mcnet/display.lua"

local dashboards = {
    { id = "communications.overview", label = "Communications overview", category = "Communications" },
    { id = "communications.towers", label = "Tower status", category = "Communications" },
    { id = "communications.devices", label = "Device directory", category = "Communications" },
    { id = "communications.mailbox", label = "Mailbox status", category = "Communications" },
    { id = "power.overview", label = "Power overview (future)", category = "Power" },
    { id = "trains.network", label = "Rail network map (future)", category = "Trains" },
    { id = "trains.stations", label = "Station board (future)", category = "Trains" },
    { id = "trains.routes", label = "Routes and line status (future)", category = "Trains" }
}

local function copyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then result[key] = copyTable(value) else result[key] = value end
    end
    return result
end

local function validDashboard(id)
    for _, item in ipairs(dashboards) do if item.id == id then return true end end
    return false
end

function module.default()
    return { refreshInterval = 2, screens = {} }
end

function module.normalise(value)
    local result = module.default()
    value = type(value) == "table" and value or {}
    result.refreshInterval = tonumber(value.refreshInterval) or 2
    if result.refreshInterval < 1 then result.refreshInterval = 1 end
    if result.refreshInterval > 30 then result.refreshInterval = 30 end
    if type(value.screens) == "table" then
        for name, profile in pairs(value.screens) do
            if type(name) == "string" and type(profile) == "table" then
                local dashboard = tostring(profile.dashboard or "communications.overview")
                if not validDashboard(dashboard) then dashboard = "communications.overview" end
                local scale = tonumber(profile.textScale) or 0.5
                if scale < 0.5 then scale = 0.5 end
                if scale > 5 then scale = 5 end
                result.screens[name] = { dashboard = dashboard, textScale = scale }
            end
        end
    end
    return result
end

function module.load(path)
    path = path or PATH
    if not fs.exists(path) then return module.default() end
    local loaded, value = pcall(dofile, path)
    if not loaded then return module.default() end
    return module.normalise(value)
end

function module.save(value, path)
    path = path or PATH
    value = module.normalise(value)
    local directory = fs.getDir(path)
    if directory ~= "" and not fs.exists(directory) then fs.makeDir(directory) end
    local temporary = path .. ".tmp"
    if fs.exists(temporary) then fs.delete(temporary) end
    local file = fs.open(temporary, "w")
    if not file then return false, "Could not write display configuration" end
    file.write("return ")
    file.write(textutils.serialize(value))
    file.write("\n")
    file.close()
    if fs.exists(path) then fs.delete(path) end
    fs.move(temporary, path)
    return true
end

function module.getDashboards(category)
    local result = {}
    for _, item in ipairs(dashboards) do
        if not category or item.category == category then result[#result + 1] = copyTable(item) end
    end
    return result
end

function module.getCategories()
    return { "Communications", "Power", "Trains" }
end

function module.getLabel(id)
    for _, item in ipairs(dashboards) do if item.id == id then return item.label end end
    return tostring(id)
end

function module.getPath() return PATH end
return module
