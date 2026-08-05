-- MCNet core server: directory, presence, tower registry and mailbox
-- Version 0.9.1

local module = {}
local STORE_PATH = ".mcnet/core_server.lua"

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[deepCopy(key, seen)] = deepCopy(item, seen) end
    return result
end

local function normaliseStore(value)
    value = type(value) == "table" and value or {}
    if type(value.devices) ~= "table" then value.devices = {} end
    if type(value.towers) ~= "table" then value.towers = {} end
    if type(value.mailbox) ~= "table" then value.mailbox = {} end
    if type(value.events) ~= "table" then value.events = {} end
    if type(value.stats) ~= "table" then value.stats = {} end
    local defaults = {
        heartbeats = 0, snapshots = 0, mailboxStored = 0,
        mailboxDelivered = 0, mailboxAttempts = 0
    }
    for key, item in pairs(defaults) do
        if type(value.stats[key]) ~= "number" then value.stats[key] = item end
    end
    for _, item in pairs(value.devices) do item.online = false; item.lastSeenClock = nil end
    for _, item in pairs(value.towers) do item.online = false; item.lastSeenClock = nil end
    for _, item in pairs(value.mailbox) do
        if item.state ~= "DELIVERED" then item.state = "PENDING" end
        item.deliveryPacketId = nil
        item.nextAttempt = 0
    end
    return value
end

local function loadStore(path)
    if not fs.exists(path) then return normaliseStore({}) end
    local loaded, value = pcall(dofile, path)
    if not loaded then return normaliseStore({}) end
    return normaliseStore(value)
end

local function saveStore(store, path)
    local serial = deepCopy(store)
    for _, item in pairs(serial.devices or {}) do item.lastSeenClock = nil end
    for _, item in pairs(serial.towers or {}) do item.lastSeenClock = nil end
    for _, item in pairs(serial.mailbox or {}) do item.deliveryPacketId = nil end
    local directory = fs.getDir(path)
    if directory ~= "" and not fs.exists(directory) then fs.makeDir(directory) end
    local temporary = path .. ".tmp"
    if fs.exists(temporary) then fs.delete(temporary) end
    local file = fs.open(temporary, "w")
    if not file then return false, "Could not write core server store" end
    file.write("return ")
    file.write(textutils.serialize(serial))
    file.write("\n")
    file.close()
    if fs.exists(path) then fs.delete(path) end
    fs.move(temporary, path)
    return true
end

local function safeTrim(list, maximum)
    while #list > maximum do table.remove(list, 1) end
end

function module.new(network, initialDevice, config, path)
    local server = {}
    local device = deepCopy(initialDevice or {})
    local settings = config or {}
    local storePath = path or STORE_PATH
    local store = loadStore(storePath)
    local running = false
    local deliveryPackets = {}
    local lastSave = -1000

    local function now() return os.clock() end
    local function stamp()
        return os.day and os.day() or 0, os.time and os.time() or 0
    end

    do
        local day, time = stamp()
        store.devices[device.address] = {
            address = device.address,
            systemName = device.systemName,
            friendlyName = device.friendlyName,
            type = "SERVER",
            region = device.region,
            owner = device.owner,
            status = "ONLINE",
            online = true,
            computerID = device.computerID,
            version = device.version,
            protocol = device.protocol,
            selectedTower = network.getStatus and network.getStatus().selectedTower or nil,
            lastSeenDay = day,
            lastSeenTime = time,
            lastSeenClock = now()
        }
    end

    local function recordEvent(kind, message, source)
        local day, time = stamp()
        store.events[#store.events + 1] = {
            day = day, time = time, kind = tostring(kind or "INFO"),
            message = tostring(message or ""), source = source
        }
        safeTrim(store.events, settings.maxEvents or 300)
    end

    local function save(force)
        if force or now() - lastSave >= 2 then
            lastSave = now()
            saveStore(store, storePath)
        end
    end

    local function recordHeartbeat(packet)
        local payload = type(packet.payload) == "table" and packet.payload or {}
        local identity = type(payload.device) == "table" and payload.device or {}
        local address = string.upper(tostring(packet.source or identity.address or ""))
        if address == "" then return end
        local previous = store.devices[address]
        local wasOnline = previous and previous.online
        local day, time = stamp()
        local entry = previous or {}
        entry.address = address
        entry.systemName = tostring(identity.systemName or entry.systemName or "")
        entry.friendlyName = tostring(identity.friendlyName or entry.friendlyName or "")
        entry.type = string.upper(tostring(identity.type or entry.type or "UNKNOWN"))
        entry.region = tostring(identity.region or entry.region or "UNKNOWN")
        entry.owner = tostring(identity.owner or entry.owner or "MCNet")
        entry.status = "ONLINE"
        entry.online = true
        entry.computerID = identity.computerID
        entry.version = identity.version
        entry.protocol = identity.protocol
        entry.selectedTower = payload.selectedTower
        entry.lastSeenDay = day
        entry.lastSeenTime = time
        entry.lastSeenClock = now()
        store.devices[address] = entry

        if entry.type == "TOWER" then
            local tower = store.towers[address] or {}
            for key, value in pairs(entry) do tower[key] = value end
            tower.network = deepCopy(payload.network or {})
            store.towers[address] = tower
        end

        store.stats.heartbeats = store.stats.heartbeats + 1
        if not wasOnline then recordEvent("ONLINE", address .. " came online", address) end
        save(false)
    end

    local function deviceArray()
        local result = {}
        for _, entry in pairs(store.devices) do
            local item = deepCopy(entry)
            item.lastSeenClock = nil
            result[#result + 1] = item
        end
        table.sort(result, function(a, b) return tostring(a.address) < tostring(b.address) end)
        return result
    end

    local function towerArray()
        local result = {}
        for _, entry in pairs(store.towers) do
            local item = deepCopy(entry)
            item.lastSeenClock = nil
            result[#result + 1] = item
        end
        table.sort(result, function(a, b) return tostring(a.address) < tostring(b.address) end)
        return result
    end

    local function mailboxSummary()
        local pending, sent, delivered = 0, 0, 0
        for _, item in pairs(store.mailbox) do
            if item.state == "DELIVERED" then delivered = delivered + 1
            elseif item.state == "SENT" then sent = sent + 1
            else pending = pending + 1 end
        end
        return { pending = pending, sent = sent, deliveredRecent = delivered }
    end

    local function snapshot()
        local onlineDevices, onlineTowers = 0, 0
        for _, item in pairs(store.devices) do if item.online then onlineDevices = onlineDevices + 1 end end
        for _, item in pairs(store.towers) do if item.online then onlineTowers = onlineTowers + 1 end end
        local day, time = stamp()
        return {
            server = {
                address = device.address,
                friendlyName = device.friendlyName,
                online = true,
                day = day,
                time = time
            },
            devices = deviceArray(),
            towers = towerArray(),
            mailbox = mailboxSummary(),
            stats = deepCopy(store.stats),
            events = deepCopy(store.events),
            totals = {
                devices = (function() local n=0 for _ in pairs(store.devices) do n=n+1 end return n end)(),
                devicesOnline = onlineDevices,
                towers = (function() local n=0 for _ in pairs(store.towers) do n=n+1 end return n end)(),
                towersOnline = onlineTowers
            }
        }
    end

    local function sendSnapshot(destination)
        store.stats.snapshots = store.stats.snapshots + 1
        return network.send(destination, "CORE", "SNAPSHOT", snapshot(), { priority = 3 })
    end

    local function sendMailboxState(destination, messageId, state, reason)
        return network.send(destination, "MAILBOX", state == "STORED" and "RECEIPT" or "STATUS", {
            messageId = messageId,
            state = state,
            reason = reason
        }, { priority = 6 })
    end

    local function removeOldestDelivered(requiredSlots)
        requiredSlots = math.max(0, tonumber(requiredSlots) or 0)
        if requiredSlots == 0 then return 0 end

        local delivered = {}
        for messageId, item in pairs(store.mailbox) do
            if item.state == "DELIVERED" then
                delivered[#delivered + 1] = {
                    id = messageId,
                    day = tonumber(item.deliveredDay or item.createdDay) or 0,
                    time = tonumber(item.deliveredTime or item.createdTime) or 0
                }
            end
        end

        table.sort(delivered, function(left, right)
            if left.day == right.day then return left.time < right.time end
            return left.day < right.day
        end)

        local removed = 0
        for index = 1, math.min(requiredSlots, #delivered) do
            store.mailbox[delivered[index].id] = nil
            removed = removed + 1
        end
        return removed
    end

    local function storeMessage(packet)
        local payload = type(packet.payload) == "table" and packet.payload or {}
        local incoming = type(payload.message) == "table" and payload.message or payload
        local messageId = tostring(incoming.id or incoming.messageId or "")
        local destination = string.upper(tostring(incoming.to or incoming.destination or ""))
        if messageId == "" or destination == "" then return end

        local item = store.mailbox[messageId]
        if not item then
            local mailboxCount = 0
            for _ in pairs(store.mailbox) do mailboxCount = mailboxCount + 1 end
            local maximum = settings.maxMailbox or 500
            if mailboxCount >= maximum then
                local needed = mailboxCount - maximum + 1
                mailboxCount = mailboxCount - removeOldestDelivered(needed)
            end
            if mailboxCount >= maximum then
                sendMailboxState(packet.source, messageId, "FAILED", "Core mailbox is full")
                recordEvent("MAIL", "Rejected message because the mailbox is full", packet.source)
                return
            end

            local day, time = stamp()
            item = {
                id = messageId,
                from = packet.source,
                to = destination,
                text = tostring(incoming.text or ""),
                day = tonumber(incoming.day or incoming.sentDay) or day,
                time = tonumber(incoming.time or incoming.sentTime) or time,
                state = "PENDING",
                createdDay = day,
                createdTime = time,
                attempts = 0,
                nextAttempt = 0
            }
            store.mailbox[messageId] = item
            store.stats.mailboxStored = store.stats.mailboxStored + 1
            recordEvent("MAIL", "Stored message " .. messageId .. " for " .. destination, packet.source)
        end

        if item.state == "DELIVERED" then
            sendMailboxState(packet.source, messageId, "DELIVERED")
        else
            sendMailboxState(packet.source, messageId, "STORED")
        end
        save(true)
    end

    local function confirmDelivery(packet)
        local payload = type(packet.payload) == "table" and packet.payload or {}
        local messageId = tostring(payload.messageId or "")
        local item = store.mailbox[messageId]
        if not item or item.to ~= packet.source then return end
        if item.state == "DELIVERED" then
            sendMailboxState(item.from, messageId, "DELIVERED")
            return
        end
        item.state = "DELIVERED"
        item.deliveryPacketId = nil
        item.deliveredClock = now()
        item.deliveredDay, item.deliveredTime = stamp()
        store.stats.mailboxDelivered = store.stats.mailboxDelivered + 1
        recordEvent("MAIL", "Delivered message " .. messageId .. " to " .. item.to, item.to)
        sendMailboxState(item.from, messageId, "DELIVERED")
        save(true)
    end

    local function reportMailboxStatus(packet)
        local payload = type(packet.payload) == "table" and packet.payload or {}
        local ids = type(payload.messageIds) == "table" and payload.messageIds or {}
        if payload.messageId then ids[#ids + 1] = payload.messageId end

        for _, value in ipairs(ids) do
            local messageId = tostring(value or "")
            if messageId ~= "" then
                local item = store.mailbox[messageId]
                if not item or item.from ~= packet.source then
                    sendMailboxState(packet.source, messageId, "UNKNOWN", "Mailbox record was not found")
                elseif item.state == "DELIVERED" then
                    sendMailboxState(packet.source, messageId, "DELIVERED")
                else
                    sendMailboxState(packet.source, messageId, "STORED")
                end
            end
        end
    end

    network.on("CORE", function(packet)
        if packet.type == "HEARTBEAT" then
            recordHeartbeat(packet)
        elseif packet.type == "SNAPSHOT_REQUEST" then
            sendSnapshot(packet.source)
        elseif packet.type == "EVENT" then
            local payload = type(packet.payload) == "table" and packet.payload or {}
            recordEvent(payload.kind or "REMOTE", payload.message or "Remote event", packet.source)
            save(false)
        end
    end)

    network.on("MAILBOX", function(packet)
        if packet.type == "SUBMIT" then storeMessage(packet)
        elseif packet.type == "DELIVERED" then confirmDelivery(packet)
        elseif packet.type == "STATUS_REQUEST" then reportMailboxStatus(packet) end
    end)

    network.onDelivery(function(packetId, status, reason)
        if status ~= "DELIVERED" and status ~= "FAILED" then return end
        local messageId = deliveryPackets[packetId]
        if not messageId then return end
        deliveryPackets[packetId] = nil
        local item = store.mailbox[messageId]
        if not item then return end
        item.deliveryPacketId = nil
        if item.state == "DELIVERED" then
            save(false)
            return
        end
        if status == "DELIVERED" then
            item.state = "SENT"
            item.nextAttempt = now() + (settings.mailboxRetryInterval or 6)
        elseif status == "FAILED" then
            item.state = "PENDING"
            item.lastReason = reason
            item.nextAttempt = now() + (settings.mailboxRetryInterval or 6)
        end
        save(false)
    end)

    local function markOffline()
        local expired = {}
        for address, item in pairs(store.devices) do
            if address ~= device.address
                and item.online
                and (not item.lastSeenClock or now() - item.lastSeenClock > (settings.onlineTimeout or 28)) then
                expired[#expired + 1] = address
            end
        end
        for _, address in ipairs(expired) do
            local item = store.devices[address]
            item.online = false
            item.status = "OFFLINE"
            if store.towers[address] then
                store.towers[address].online = false
                store.towers[address].status = "OFFLINE"
            end
            recordEvent("OFFLINE", address .. " went offline", address)
        end
        if #expired > 0 then save(true) end
    end

    local function attemptMailbox()
        for messageId, item in pairs(store.mailbox) do
            if item.state ~= "DELIVERED"
                and not item.deliveryPacketId
                and now() >= (item.nextAttempt or 0) then
                local destination = store.devices[item.to]
                if destination and destination.online then
                    local sent, packetId = network.send(item.to, "MESSAGING", "MAILBOX_DELIVERY", {
                        messageId = item.id,
                        text = item.text,
                        sentDay = item.day,
                        sentTime = item.time,
                        originalSource = item.from,
                        mailboxServer = device.address
                    }, { priority = 7 })
                    item.attempts = (item.attempts or 0) + 1
                    store.stats.mailboxAttempts = store.stats.mailboxAttempts + 1
                    item.nextAttempt = now() + (settings.mailboxRetryInterval or 6)
                    if sent then
                        item.deliveryPacketId = packetId
                        item.state = "SENDING"
                        deliveryPackets[packetId] = messageId
                    end
                end
            end
        end
    end

    function server.tick()
        local selfEntry = store.devices[device.address]
        if selfEntry then
            selfEntry.online = true
            selfEntry.status = "ONLINE"
            selfEntry.lastSeenClock = now()
            selfEntry.lastSeenDay, selfEntry.lastSeenTime = stamp()
            selfEntry.selectedTower = network.getStatus and network.getStatus().selectedTower or selfEntry.selectedTower
        end
        markOffline()
        attemptMailbox()
        save(false)
    end

    function server.run()
        running = true
        server.tick()
        local timer = os.startTimer(1)
        while running do
            local event = { os.pullEvent() }
            if event[1] == "timer" and event[2] == timer then
                server.tick()
                timer = os.startTimer(1)
            end
        end
    end


    -- Prepare a read-only archive bundle.
    --
    -- This does not modify the live store. It selects older delivered
    -- messages and older events while retaining recent records locally.
    --
    -- The returned token must be supplied to commitArchive() only after the
    -- archive manager has written and verified the archive disk.
    function server.prepareArchive(options)
        options = type(options) == "table" and options or {}

        local retainDelivered =
            math.max(
                0,
                math.floor(
                    tonumber(options.retainDelivered)
                    or tonumber(settings.archiveRetainDelivered)
                    or 50
                )
            )

        local retainEvents =
            math.max(
                0,
                math.floor(
                    tonumber(options.retainEvents)
                    or tonumber(settings.archiveRetainEvents)
                    or 200
                )
            )

        local delivered = {}

        for messageId, item in pairs(store.mailbox) do
            if item.state == "DELIVERED" then
                delivered[#delivered + 1] = {
                    id = messageId,
                    day = tonumber(item.deliveredDay or item.createdDay) or 0,
                    time = tonumber(item.deliveredTime or item.createdTime) or 0
                }
            end
        end

        table.sort(
            delivered,
            function(left, right)
                if left.day == right.day then
                    if left.time == right.time then
                        return tostring(left.id) < tostring(right.id)
                    end

                    return left.time < right.time
                end

                return left.day < right.day
            end
        )

        local archiveMessageCount =
            math.max(
                0,
                #delivered - retainDelivered
            )

        local archiveMessages = {}
        local archiveMessageIds = {}

        for index = 1, archiveMessageCount do
            local messageId = delivered[index].id
            local item = store.mailbox[messageId]

            if item and item.state == "DELIVERED" then
                archiveMessages[messageId] =
                    deepCopy(item)

                archiveMessageIds[#archiveMessageIds + 1] =
                    messageId
            end
        end

        local archiveEventCount =
            math.max(
                0,
                #store.events - retainEvents
            )

        local archiveEvents = {}

        for index = 1, archiveEventCount do
            archiveEvents[index] =
                deepCopy(store.events[index])
        end

        local bundle = {
            messages = archiveMessages,
            events = archiveEvents,
            devices = deepCopy(store.devices),
            towers = deepCopy(store.towers),
            stats = deepCopy(store.stats),
            generatedBy = device.address,
            generatedDay = os.day and os.day() or 0,
            generatedTime = os.time and os.time() or 0
        }

        local token = {
            format = 1,
            storePath = storePath,
            createdClock = now(),
            createdDay = os.day and os.day() or 0,
            createdTime = os.time and os.time() or 0,
            messageIds = deepCopy(archiveMessageIds),
            events = deepCopy(archiveEvents),
            retainDelivered = retainDelivered,
            retainEvents = retainEvents
        }

        return true, bundle, token
    end

    local function archiveEventsStillMatch(expected)
        if type(expected) ~= "table" then
            return false
        end

        if #store.events < #expected then
            return false
        end

        for index, archived in ipairs(expected) do
            local current = store.events[index]

            if type(current) ~= "table" then
                return false
            end

            if tostring(current.kind or "") ~=
                    tostring(archived.kind or "")
                or tostring(current.message or "") ~=
                    tostring(archived.message or "")
                or tostring(current.source or "") ~=
                    tostring(archived.source or "")
                or tonumber(current.day or 0) ~=
                    tonumber(archived.day or 0)
                or tonumber(current.time or 0) ~=
                    tonumber(archived.time or 0) then

                return false
            end
        end

        return true
    end

    -- Commit an archive after the archive manager has successfully written
    -- and verified a disk.
    --
    -- Only records described by the token are pruned. Pending, sending and
    -- failed mailbox records are never removed here.
    function server.commitArchive(token, archiveMetadata)
        if type(token) ~= "table" then
            return false, "Archive token is invalid"
        end

        if type(token.messageIds) ~= "table"
            or type(token.events) ~= "table" then

            return false, "Archive token is incomplete"
        end

        if token.storePath
            and token.storePath ~= storePath then

            return false,
                "Archive token belongs to another store"
        end

        if not archiveEventsStillMatch(token.events) then
            return false,
                "Live event history changed before archive commit"
        end

        local removedMessages = 0

        for _, messageId in ipairs(token.messageIds) do
            local item = store.mailbox[messageId]

            if item and item.state == "DELIVERED" then
                store.mailbox[messageId] = nil
                removedMessages =
                    removedMessages + 1
            end
        end

        local removedEvents =
            #token.events

        for _ = 1, removedEvents do
            table.remove(store.events, 1)
        end

        local archiveId =
            type(archiveMetadata) == "table"
            and archiveMetadata.archiveId
            or "UNKNOWN"

        recordEvent(
            "ARCHIVE",
            "Committed "
                .. tostring(archiveId)
                .. ": "
                .. tostring(removedMessages)
                .. " messages, "
                .. tostring(removedEvents)
                .. " events",
            device.address
        )

        local saved, reason =
            saveStore(store, storePath)

        if not saved then
            return false,
                "Archive records were selected but the live store could not be saved: "
                .. tostring(reason)
        end

        lastSave = now()

        return true, {
            archiveId = archiveId,
            messagesRemoved = removedMessages,
            eventsRemoved = removedEvents,
            messagesRemaining = (function()
                local count = 0
                for _ in pairs(store.mailbox) do
                    count = count + 1
                end
                return count
            end)(),
            eventsRemaining = #store.events
        }
    end

    function server.getArchiveSummary(options)
        local prepared,
            bundle,
            token =
            server.prepareArchive(options)

        if not prepared then
            return {
                ready = false,
                reason = bundle
            }
        end

        local messagesEligible = 0
        local deliveredTotal = 0
        local mailboxTotal = 0
        local mailboxPending = 0
        local mailboxSent = 0

        for _ in pairs(bundle.messages or {}) do
            messagesEligible =
                messagesEligible + 1
        end

        for _, item in pairs(store.mailbox) do
            mailboxTotal =
                mailboxTotal + 1

            if item.state == "DELIVERED" then
                deliveredTotal =
                    deliveredTotal + 1
            elseif item.state == "SENT" then
                mailboxSent =
                    mailboxSent + 1
            else
                mailboxPending =
                    mailboxPending + 1
            end
        end

        local messagesRetained =
            math.max(
                0,
                deliveredTotal
                - messagesEligible
            )

        local eventsTotal =
            #store.events

        local eventsEligible =
            #(bundle.events or {})

        local eventsRetained =
            math.max(
                0,
                eventsTotal
                - eventsEligible
            )

        return {
            ready =
                messagesEligible > 0
                or eventsEligible > 0,

            -- Backwards-compatible names used by the current server UI.
            messages =
                messagesEligible,

            events =
                eventsEligible,

            retainDelivered =
                token.retainDelivered,

            retainEvents =
                token.retainEvents,

            -- Expanded message reporting.
            mailboxTotal =
                mailboxTotal,

            mailboxPending =
                mailboxPending,

            mailboxSent =
                mailboxSent,

            deliveredTotal =
                deliveredTotal,

            messagesEligible =
                messagesEligible,

            messagesRetained =
                messagesRetained,

            deliveredRetentionLimit =
                token.retainDelivered,

            -- Expanded event reporting.
            eventsTotal =
                eventsTotal,

            eventsEligible =
                eventsEligible,

            eventsRetained =
                eventsRetained,

            eventRetentionLimit =
                token.retainEvents
        }
    end

    function server.stop() running = false end
    function server.getSnapshot() return snapshot() end
    function server.getStorePath() return storePath end
    function server.log(kind, message, source) recordEvent(kind, message, source); save(false) end
    return server
end

return module