-- MCNet multi-monitor display-wall configuration
-- Version 0.9.6
--
-- Stores per-monitor dashboard profiles for DISPLAY computers.
--
-- Current profile fields:
--   dashboard = dashboard ID
--   textScale = monitor text scale
--   station   = rail station/map ID when required
--   platform  = platform ID when required
--
-- This service intentionally contains dashboard metadata only. Rendering is
-- performed by applications/roles/display.lua.
--
-- Legacy v0.9.0 train dashboard IDs are accepted and upgraded automatically.

local module = {}

local PATH = ".mcnet/display.lua"

local dashboards = {
    {
        id = "communications.overview",
        label = "Communications overview",
        category = "Communications",
        description = "Core Server, towers, devices, mailbox and heartbeat status."
    },
    {
        id = "communications.towers",
        label = "Tower status",
        category = "Communications",
        description = "MCNet tower availability and routing status."
    },
    {
        id = "communications.devices",
        label = "Device directory",
        category = "Communications",
        description = "Known MCNet devices and their online state."
    },
    {
        id = "communications.mailbox",
        label = "Mailbox status",
        category = "Communications",
        description = "Persistent mailbox queue and delivery statistics."
    },

    {
        id = "trains.station_sign",
        label = "Station identity",
        category = "Trains",
        description = "Station name, served lines and rotating passenger information.",
        needsStation = true
    },
    {
        id = "trains.departures",
        label = "Station departures",
        category = "Trains",
        description = "Upcoming departures for the selected station.",
        needsStation = true
    },
    {
        id = "trains.platform",
        label = "Platform departure board",
        category = "Trains",
        description = "Next trains and calling points for one selected platform.",
        needsStation = true,
        needsPlatform = true
    },
    {
        id = "trains.line_map",
        label = "Station line map",
        category = "Trains",
        description = "Clean Tube-style line diagram for the selected station. Interchanges rotate through their served lines.",
        needsStation = true
    },
    {
        id = "trains.map",
        label = "Rail network map",
        category = "Trains",
        description = "Tube-style network map highlighting the selected station.",
        needsStation = true
    },
    {
        id = "trains.network_status",
        label = "Rail network status",
        category = "Trains",
        description = "Passenger-facing line and network status."
    },
    {
        id = "trains.operations",
        label = "Live rail operations (future)",
        category = "Trains",
        description = "Future live train tracking and operational control display.",
        future = true
    },

    {
        id = "power.overview",
        label = "Power overview (future)",
        category = "Power",
        description = "Future MCNet power telemetry dashboard.",
        future = true
    }
}

local categories = {
    "Communications",
    "Trains",
    "Power"
}

local aliases = {
    -- v0.9.0 train display IDs.
    ["trains.line"] = "trains.line_map",
    ["trains.network"] = "trains.map",
    ["trains.stations"] = "trains.departures",
    ["trains.routes"] = "trains.network_status"
}

local function copyTable(source)
    local result = {}

    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end

    return result
end

local function canonicalDashboard(id)
    id = tostring(id or "communications.overview")

    if aliases[id] then
        return aliases[id]
    end

    return id
end

local function findDashboard(id)
    id = canonicalDashboard(id)

    for _, item in ipairs(dashboards) do
        if item.id == id then
            return item
        end
    end

    return nil
end

local function validDashboard(id)
    return findDashboard(id) ~= nil
end

local function cleanStation(value)
    value =
        string.upper(
            tostring(
                value
                or "CENTRAL"
            )
        )

    value =
        string.gsub(
            value,
            "%s+",
            "_"
        )

    value =
        string.gsub(
            value,
            "[^A-Z0-9_%-]",
            ""
        )

    if value == "" then
        return "CENTRAL"
    end

    return value
end

local function cleanPlatform(value)
    value =
        string.upper(
            tostring(
                value
                or "P1"
            )
        )

    value =
        string.gsub(
            value,
            "%s+",
            ""
        )

    value =
        string.gsub(
            value,
            "[^A-Z0-9_%-]",
            ""
        )

    if value == "" then
        return "P1"
    end

    return value
end

function module.defaultProfile()
    return {
        dashboard = "communications.overview",
        textScale = 0.5,
        station = "CENTRAL",
        platform = "P1"
    }
end

function module.default()
    return {
        format = 2,
        refreshInterval = 2,
        screens = {}
    }
end

function module.normaliseProfile(profile)
    profile =
        type(profile) == "table"
        and profile
        or {}

    local result =
        module.defaultProfile()

    local dashboard =
        canonicalDashboard(
            profile.dashboard
        )

    if validDashboard(dashboard) then
        result.dashboard = dashboard
    end

    local scale =
        tonumber(
            profile.textScale
        )
        or result.textScale

    if scale < 0.5 then
        scale = 0.5
    end

    if scale > 5 then
        scale = 5
    end

    result.textScale = scale

    -- Preserve these even for dashboards that do not currently require them.
    -- That makes switching a monitor between rail display types painless.
    result.station =
        cleanStation(
            profile.station
            or result.station
        )

    result.platform =
        cleanPlatform(
            profile.platform
            or result.platform
        )

    return result
end

function module.normalise(value)
    local result =
        module.default()

    value =
        type(value) == "table"
        and value
        or {}

    result.format =
        math.max(
            1,
            math.floor(
                tonumber(
                    value.format
                )
                or result.format
            )
        )

    result.refreshInterval =
        tonumber(
            value.refreshInterval
        )
        or result.refreshInterval

    if result.refreshInterval < 1 then
        result.refreshInterval = 1
    end

    if result.refreshInterval > 30 then
        result.refreshInterval = 30
    end

    if type(value.screens) == "table" then
        for name, profile in pairs(value.screens) do
            if type(name) == "string"
                and name ~= ""
                and type(profile) == "table" then

                result.screens[name] =
                    module.normaliseProfile(
                        profile
                    )
            end
        end
    end

    return result
end

function module.load(path)
    path = path or PATH

    if not fs.exists(path) then
        return module.default()
    end

    local loaded, value =
        pcall(
            dofile,
            path
        )

    if not loaded
        or type(value) ~= "table" then

        return module.default()
    end

    return module.normalise(value)
end

function module.save(value, path)
    path = path or PATH

    value =
        module.normalise(
            value
        )

    local directory =
        fs.getDir(path)

    if directory ~= ""
        and not fs.exists(directory) then

        fs.makeDir(directory)
    end

    local temporary =
        path .. ".tmp"

    if fs.exists(temporary) then
        fs.delete(temporary)
    end

    local file =
        fs.open(
            temporary,
            "w"
        )

    if not file then
        return false,
            "Could not write display configuration"
    end

    local written, reason =
        pcall(
            function()
                file.write("return ")
                file.write(
                    textutils.serialize(
                        value
                    )
                )
                file.write("\n")
            end
        )

    file.close()

    if not written then
        if fs.exists(temporary) then
            fs.delete(temporary)
        end

        return false,
            tostring(reason)
    end

    local checked, saved =
        pcall(
            dofile,
            temporary
        )

    if not checked
        or type(saved) ~= "table" then

        fs.delete(temporary)

        return false,
            "Could not verify display configuration"
    end

    if fs.exists(path) then
        fs.delete(path)
    end

    fs.move(
        temporary,
        path
    )

    return true
end

function module.getDashboards(category)
    local result = {}

    for _, item in ipairs(dashboards) do
        if not category
            or item.category == category then

            result[#result + 1] =
                copyTable(item)
        end
    end

    return result
end

function module.getDashboard(id)
    local item =
        findDashboard(id)

    if not item then
        return nil
    end

    return copyTable(item)
end

function module.getCategories()
    return copyTable(
        categories
    )
end

function module.getLabel(id)
    local item =
        findDashboard(id)

    if item then
        return item.label
    end

    return tostring(id)
end

function module.getDescription(id)
    local item =
        findDashboard(id)

    if item then
        return item.description
    end

    return tostring(id)
end

function module.needsStation(id)
    local item =
        findDashboard(id)

    return item
        and item.needsStation == true
        or false
end

function module.needsPlatform(id)
    local item =
        findDashboard(id)

    return item
        and item.needsPlatform == true
        or false
end

function module.isFuture(id)
    local item =
        findDashboard(id)

    return item
        and item.future == true
        or false
end

function module.resolveDashboard(id)
    local resolved =
        canonicalDashboard(id)

    if validDashboard(resolved) then
        return resolved
    end

    return "communications.overview"
end

function module.getPath()
    return PATH
end

return module
