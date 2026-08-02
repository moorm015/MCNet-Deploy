-- MCNet directory, presence and network-monitoring client
-- Version 0.9.0

local module = {}
local CACHE_PATH = ".mcnet/core_cache.lua"

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[deepCopy(key, seen)] = deepCopy(item, seen) end
    return result
end

local function normaliseCache(value)
    value = type(value) == "table" and value or {}
    if type(value.devices) ~= "table" then value.devices = {} end
    if type(value.towers) ~= "table" then value.towers = {} end
    if type(value.stats) ~= "table" then value.stats = {} end
    if type(value.events) ~= "table" then value.events = {} end
    if type(value.mailbox) ~= "table" then value.mailbox = {} end
    return value
end

local function loadCache(path)
    if not fs.exists(path) then return normaliseCache({}) end
    local loaded, value = pcall(dofile, path)
    if not loaded then return normaliseCache({}) end
    return normaliseCache(value)
end

local function saveCache(cache, path)
    local directory = fs.getDir(path)
    if directory ~= "" and not fs.exists(directory) then fs.makeDir(directory) end
    local temporary = path .. ".tmp"
    if fs.exists(temporary) then fs.delete(temporary) end
    local file = fs.open(temporary, "w")
    if not file then return false end
    file.write("return ")
    file.write(textutils.serialize(cache))
    file.write("\n")
    file.close()
    if fs.exists(path) then fs.delete(path) end
    fs.move(temporary, path)
    return true
end

function module.new(network, initialDevice, config, cachePath)
    local client = {}
    local device = deepCopy(initialDevice or {})
    local settings = config or {}
    local path = cachePath or CACHE_PATH
    local cache = loadCache(path)
    local running = false
    local lastHeartbeat = -1000
    local lastSnapshotRequest = -1000
    local lastSnapshotClock = nil
    local heartbeatPacketId = nil
    local snapshotPacketId = nil

    local function now() return os.clock() end

    local function identityPayload()
        local status = network.getStatus()
        return {
            device = {
                address = device.address,
                systemName = device.systemName,
                friendlyName = device.friendlyName,
                type = device.type,
                region = device.region,
                owner = device.owner,
                status = "ONLINE",
                computerID = device.computerID,
                version = device.version,
                protocol = device.protocol
            },
            selectedTower = status.selectedTower,
            network = status
        }
    end

    local function sendHeartbeat()
        if heartbeatPacketId then return false end
        local sent, packetId = network.send(
            settings.coreAddress,
            "CORE",
            "HEARTBEAT",
            identityPayload(),
            { priority = 5 }
        )
        if sent then heartbeatPacketId = packetId end
        return sent
    end

    local function requestSnapshot()
        if snapshotPacketId then return false end
        local sent, packetId = network.send(
            settings.coreAddress,
            "CORE",
            "SNAPSHOT_REQUEST",
            { requestedBy = device.address },
            { priority = 2 }
        )
        if sent then snapshotPacketId = packetId end
        return sent
    end

    network.on("CORE", function(packet)
        if packet.type ~= "SNAPSHOT" or type(packet.payload) ~= "table" then return end
        cache = normaliseCache(deepCopy(packet.payload))
        cache.receivedDay = os.day and os.day() or 0
        cache.receivedTime = os.time and os.time() or 0
        lastSnapshotClock = now()
        saveCache(cache, path)
        if os.queueEvent then os.queueEvent("mcnet_core_snapshot") end
    end)

    network.onDelivery(function(packetId, status)
        if status ~= "DELIVERED" and status ~= "FAILED" then return end
        if packetId == heartbeatPacketId then heartbeatPacketId = nil end
        if packetId == snapshotPacketId then snapshotPacketId = nil end
    end)

    function client.tick(force)
        local current = now()
        if force or current - lastHeartbeat >= (settings.heartbeatInterval or 8) then
            lastHeartbeat = current
            sendHeartbeat()
        end
        if force or current - lastSnapshotRequest >= (settings.snapshotInterval or 12) then
            lastSnapshotRequest = current
            requestSnapshot()
        end
    end

    function client.run()
        running = true
        client.tick(true)
        local timer = os.startTimer(1)
        while running do
            local event = { os.pullEvent() }
            if event[1] == "timer" and event[2] == timer then
                client.tick(false)
                timer = os.startTimer(1)
            end
        end
    end

    function client.stop() running = false end
    function client.setDevice(value) device = deepCopy(value or device) end
    function client.requestSnapshot() lastSnapshotRequest = -1000; return requestSnapshot() end

    function client.isCoreOnline()
        return lastSnapshotClock ~= nil
            and now() - lastSnapshotClock <= (settings.onlineTimeout or 28)
    end

    function client.getSnapshot()
        local result = deepCopy(cache)
        result.coreOnline = client.isCoreOnline()
        result.coreAddress = settings.coreAddress
        return result
    end

    function client.getDirectory()
        local result = {}
        for _, item in ipairs(cache.devices or {}) do result[#result + 1] = deepCopy(item) end
        table.sort(result, function(a, b)
            local an = tostring(a.friendlyName or a.address or "")
            local bn = tostring(b.friendlyName or b.address or "")
            return string.lower(an) < string.lower(bn)
        end)
        return result
    end

    function client.getTowers()
        local result = {}
        for _, item in ipairs(cache.towers or {}) do result[#result + 1] = deepCopy(item) end
        table.sort(result, function(a, b) return tostring(a.address) < tostring(b.address) end)
        return result
    end

    function client.getDevice(address)
        address = string.upper(tostring(address or ""))
        for _, item in ipairs(cache.devices or {}) do
            if item.address == address then return deepCopy(item) end
        end
        return nil
    end

    function client.resolve(address)
        local item = client.getDevice(address)
        if not item then return tostring(address or "UNKNOWN") end
        if item.friendlyName and item.friendlyName ~= "" then return item.friendlyName end
        if item.systemName and item.systemName ~= "" then return item.systemName end
        return item.address
    end

    function client.getStatus()
        return {
            coreAddress = settings.coreAddress,
            online = client.isCoreOnline(),
            devices = #(cache.devices or {}),
            towers = #(cache.towers or {}),
            receivedDay = cache.receivedDay,
            receivedTime = cache.receivedTime
        }
    end

    function client.getCachePath() return path end
    return client
end

return module
