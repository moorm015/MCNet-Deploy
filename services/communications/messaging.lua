-- MCNet persistent messaging with core mailbox and direct fallback
-- Version 0.9.0

local module = {}
local PATH = ".mcnet/messages.lua"
local MAX_MESSAGES = 250

local function copyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function timestamp()
    return { day = os.day and os.day() or 0, time = os.time and os.time() or 0 }
end

local function generateMessageID(address)
    return tostring(address or "UNKNOWN") .. "-MSG-"
        .. tostring(os.day and os.day() or 0) .. "-"
        .. tostring(math.floor((os.time and os.time() or 0) * 1000)) .. "-"
        .. tostring(math.random(100000, 999999))
end

local function normaliseStore(value)
    value = type(value) == "table" and value or {}
    if type(value.inbox) ~= "table" then value.inbox = {} end
    if type(value.outbox) ~= "table" then value.outbox = {} end
    return value
end

local function loadStore(path)
    if not fs.exists(path) then return normaliseStore({}) end
    local loaded, value = pcall(dofile, path)
    if not loaded then return normaliseStore({}) end
    return normaliseStore(value)
end

local function trim(list)
    while #list > MAX_MESSAGES do table.remove(list, 1) end
end

local function saveStore(store, path)
    local directory = fs.getDir(path)
    if directory ~= "" and not fs.exists(directory) then fs.makeDir(directory) end
    local temporary = path .. ".tmp"
    if fs.exists(temporary) then fs.delete(temporary) end
    local file = fs.open(temporary, "w")
    if not file then return false, "Could not write message store" end
    file.write("return ")
    file.write(textutils.serialize(store))
    file.write("\n")
    file.close()
    if fs.exists(path) then fs.delete(path) end
    fs.move(temporary, path)
    return true
end

function module.new(network, initialDevice, options)
    if type(options) == "string" then options = { path = options } end
    options = options or {}
    local messaging = {}
    local device = copyTable(initialDevice or {})
    local coreConfig = options.coreConfig or {}
    local coreAddress = string.upper(tostring(coreConfig.coreAddress or "SRV-001"))
    local storePath = options.path or PATH
    local store = loadStore(storePath)
    local packetMap = {}

    local function findInbox(messageId)
        for _, item in ipairs(store.inbox) do if item.id == messageId then return item end end
        return nil
    end

    local function findOutbox(messageId)
        for _, item in ipairs(store.outbox) do if item.id == messageId then return item end end
        return nil
    end

    local function rememberPacket(packetId, messageId, kind)
        packetMap[packetId] = { messageId = messageId, kind = kind }
    end

    local function sendDirect(item)
        local sent, packetId = network.send(item.to, "MESSAGING", "TEXT", {
            messageId = item.id,
            text = item.text,
            sentDay = item.day,
            sentTime = item.time,
            originalSource = item.from
        }, { priority = 5 })

        if not sent then
            item.status = "FAILED"
            item.reason = packetId
            saveStore(store, storePath)
            return false, packetId
        end

        item.packetId = packetId
        item.route = "DIRECT"
        item.status = "SENDING"
        item.reason = nil
        rememberPacket(packetId, item.id, "DIRECT")
        saveStore(store, storePath)
        return true, packetId
    end

    local function submitToCore(item)
        if coreAddress == "" or coreAddress == "UNKNOWN" then return sendDirect(item) end
        local sent, packetId = network.send(coreAddress, "MAILBOX", "SUBMIT", {
            message = {
                id = item.id,
                from = item.from,
                to = item.to,
                text = item.text,
                day = item.day,
                time = item.time
            }
        }, { priority = 6 })

        if not sent then return sendDirect(item) end
        item.packetId = packetId
        item.route = "CORE"
        item.status = "SUBMITTING"
        item.reason = nil
        rememberPacket(packetId, item.id, "SUBMIT")
        saveStore(store, storePath)
        return true, packetId
    end

    local function storeIncoming(packet, mailboxDelivery)
        if type(packet.payload) ~= "table" then return end
        local messageId = tostring(packet.payload.messageId or packet.id)
        if not findInbox(messageId) then
            local originalSource = tostring(packet.payload.originalSource or packet.source)
            local item = {
                id = messageId,
                packetId = packet.id,
                from = originalSource,
                to = packet.destination,
                text = tostring(packet.payload.text or ""),
                day = tonumber(packet.payload.sentDay) or 0,
                time = tonumber(packet.payload.sentTime) or 0,
                receivedDay = os.day and os.day() or 0,
                receivedTime = os.time and os.time() or 0,
                unread = true,
                route = mailboxDelivery and "CORE" or "DIRECT"
            }
            table.insert(store.inbox, item)
            trim(store.inbox)
            saveStore(store, storePath)
            if os.queueEvent then os.queueEvent("mcnet_message_received", item.id, item.from) end
        end

        if mailboxDelivery then
            local mailboxServer = tostring(packet.payload.mailboxServer or coreAddress)
            network.send(mailboxServer, "MAILBOX", "DELIVERED", { messageId = messageId }, { priority = 7 })
        end
    end

    network.on("MESSAGING", function(packet)
        if packet.type == "TEXT" then storeIncoming(packet, false)
        elseif packet.type == "MAILBOX_DELIVERY" then storeIncoming(packet, true) end
    end)

    network.on("MAILBOX", function(packet)
        if type(packet.payload) ~= "table" then return end
        local messageId = tostring(packet.payload.messageId or "")
        local item = findOutbox(messageId)
        if not item then return end

        if packet.type == "RECEIPT" and packet.payload.state == "STORED" then
            item.status = "STORED"
            item.reason = nil
        elseif packet.type == "STATUS" then
            local state = tostring(packet.payload.state or item.status)
            if state == "UNKNOWN" then
                -- The core no longer has this record. Submit the original
                -- message again using its stable ID; the recipient still
                -- deduplicates it if it was delivered previously.
                item.status = "QUEUED"
                item.reason = "Mailbox record was not found; resubmitting"
                saveStore(store, storePath)
                submitToCore(item)
                return
            end

            item.status = state
            item.reason = packet.payload.reason
            if item.status == "DELIVERED" then
                item.deliveredDay = os.day and os.day() or 0
                item.deliveredTime = os.time and os.time() or 0
            end
        end
        saveStore(store, storePath)
    end)

    network.onDelivery(function(packetId, status, reason)
        local mapped = packetMap[packetId]
        if not mapped then return end
        if status == "DELIVERED" or status == "FAILED" then packetMap[packetId] = nil end
        local item = findOutbox(mapped.messageId)
        if not item then return end

        if mapped.kind == "SUBMIT" then
            if status == "DELIVERED" then
                -- The core may return its STORED receipt before the transport
                -- acknowledgement arrives. Never regress a later mailbox state.
                if item.status == "SUBMITTING" then
                    item.status = "SUBMITTED"
                    item.reason = nil
                end
            elseif status == "FAILED" then
                item.status = "FALLBACK"
                item.reason = "Core server unavailable; trying direct delivery"
                saveStore(store, storePath)
                sendDirect(item)
                return
            end
        elseif mapped.kind == "DIRECT" then
            if status == "DELIVERED" then
                item.status = "DELIVERED"
                item.reason = nil
                item.deliveredDay = os.day and os.day() or 0
                item.deliveredTime = os.time and os.time() or 0
            elseif status == "FAILED" then
                item.status = "FAILED"
                item.reason = reason
            else
                item.status = status
            end
        end
        saveStore(store, storePath)
    end)

    function messaging.setDevice(newDevice) device = copyTable(newDevice or device) end

    function messaging.send(destination, text)
        destination = string.upper(tostring(destination or ""))
        text = tostring(text or "")
        if destination == "" or destination == "UNKNOWN" then return false, "Destination is invalid" end
        if text == "" then return false, "Message is empty" end

        local created = timestamp()
        local item = {
            id = generateMessageID(device.address),
            from = device.address,
            to = destination,
            text = text,
            day = created.day,
            time = created.time,
            status = "QUEUED",
            route = "CORE"
        }
        table.insert(store.outbox, item)
        trim(store.outbox)
        saveStore(store, storePath)
        local sent, reason = submitToCore(item)
        if not sent then return false, reason end
        return true, item.id
    end

    function messaging.retry(messageId)
        local item = findOutbox(messageId)
        if not item then return false, "Message was not found" end
        item.status = "QUEUED"
        item.reason = nil
        return submitToCore(item)
    end

    function messaging.getInbox()
        local result = {}
        for index = #store.inbox, 1, -1 do result[#result + 1] = copyTable(store.inbox[index]) end
        return result
    end

    function messaging.getOutbox()
        local result = {}
        for index = #store.outbox, 1, -1 do result[#result + 1] = copyTable(store.outbox[index]) end
        return result
    end

    function messaging.getUnreadCount()
        local count = 0
        for _, item in ipairs(store.inbox) do if item.unread then count = count + 1 end end
        return count
    end

    function messaging.markRead(messageId)
        local item = findInbox(messageId)
        if not item then return false end
        item.unread = false
        saveStore(store, storePath)
        return true
    end

    function messaging.deleteInbox(messageId)
        for index, item in ipairs(store.inbox) do
            if item.id == messageId then
                table.remove(store.inbox, index)
                saveStore(store, storePath)
                return true
            end
        end
        return false
    end

    function messaging.getPath() return storePath end
    function messaging.getSummary()
        return { inbox = #store.inbox, outbox = #store.outbox, unread = messaging.getUnreadCount() }
    end

    -- Resume interrupted submissions and reconcile messages already stored
    -- by SRV-001. The status request itself is safely queued until a tower is
    -- available, so this also works immediately after a PDA boots.
    local storedIds = {}
    for _, item in ipairs(store.outbox) do
        if item.status == "STORED" or item.status == "SUBMITTED" then
            storedIds[#storedIds + 1] = item.id
        elseif item.status ~= "DELIVERED" then
            submitToCore(item)
        end
    end

    if #storedIds > 0 and coreAddress ~= "" and coreAddress ~= "UNKNOWN" then
        network.send(coreAddress, "MAILBOX", "STATUS_REQUEST", {
            messageIds = storedIds
        }, { priority = 4 })
    end

    return messaging
end

return module