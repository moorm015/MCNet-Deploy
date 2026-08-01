-- MCNet persistent instant messaging service
-- Version 0.8.0

local module = {}
local PATH = ".mcnet/messages.lua"
local MAX_MESSAGES = 250

local function copyTable(source)
    local result = {}

    for key, value in pairs(source or {}) do
        result[key] = value
    end

    return result
end

local function timestamp()
    return {
        day = os.day and os.day() or 0,
        time = os.time and os.time() or 0
    }
end

local function generateMessageID(address)
    return tostring(address or "UNKNOWN")
        .. "-MSG-"
        .. tostring(os.day and os.day() or 0)
        .. "-"
        .. tostring(math.floor((os.time and os.time() or 0) * 1000))
        .. "-"
        .. tostring(math.random(100000, 999999))
end

local function normaliseStore(value)
    value = type(value) == "table" and value or {}

    if type(value.inbox) ~= "table" then
        value.inbox = {}
    end

    if type(value.outbox) ~= "table" then
        value.outbox = {}
    end

    return value
end

local function loadStore(path)
    if not fs.exists(path) then
        return normaliseStore({})
    end

    local loaded, value = pcall(dofile, path)

    if not loaded then
        return normaliseStore({})
    end

    return normaliseStore(value)
end

local function trim(list)
    while #list > MAX_MESSAGES do
        table.remove(list, 1)
    end
end

local function saveStore(store, path)
    local directory = fs.getDir(path)

    if directory ~= "" and not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local temporary = path .. ".tmp"

    if fs.exists(temporary) then
        fs.delete(temporary)
    end

    local file = fs.open(temporary, "w")

    if not file then
        return false, "Could not write message store"
    end

    file.write("return ")
    file.write(textutils.serialize(store))
    file.write("\n")
    file.close()

    if fs.exists(path) then
        fs.delete(path)
    end

    fs.move(temporary, path)
    return true
end

function module.new(network, initialDevice, path)
    local messaging = {}
    local device = copyTable(initialDevice or {})
    local storePath = path or PATH
    local store = loadStore(storePath)

    local function findInbox(messageId)
        for _, item in ipairs(store.inbox) do
            if item.id == messageId then
                return item
            end
        end

        return nil
    end

    local function findOutboxByPacket(packetId)
        for _, item in ipairs(store.outbox) do
            if item.packetId == packetId then
                return item
            end
        end

        return nil
    end

    local function submit(item)
        local sent, packetId =
            network.send(
                item.to,
                "MESSAGING",
                "TEXT",
                {
                    messageId = item.id,
                    text = item.text,
                    sentDay = item.day,
                    sentTime = item.time
                }
            )

        if not sent then
            item.status = "FAILED"
            item.reason = packetId
            saveStore(store, storePath)
            return false, packetId
        end

        item.packetId = packetId
        item.status = "QUEUED"
        item.reason = nil
        saveStore(store, storePath)
        return true, packetId
    end

    network.on("MESSAGING", function(packet)
        if packet.type ~= "TEXT" or type(packet.payload) ~= "table" then
            return
        end

        local messageId =
            tostring(
                packet.payload.messageId
                or packet.id
            )

        if findInbox(messageId) then
            return
        end

        local item = {
            id = messageId,
            packetId = packet.id,
            from = packet.source,
            to = packet.destination,
            text = tostring(packet.payload.text or ""),
            day = tonumber(packet.payload.sentDay) or 0,
            time = tonumber(packet.payload.sentTime) or 0,
            receivedDay = os.day and os.day() or 0,
            receivedTime = os.time and os.time() or 0,
            unread = true
        }

        table.insert(store.inbox, item)
        trim(store.inbox)
        saveStore(store, storePath)

        if os.queueEvent then
            os.queueEvent(
                "mcnet_message_received",
                item.id,
                item.from
            )
        end
    end)

    network.onDelivery(function(packetId, status, reason)
        local item = findOutboxByPacket(packetId)

        if not item then
            return
        end

        item.status = status
        item.reason = reason

        if status == "DELIVERED" then
            item.deliveredDay = os.day and os.day() or 0
            item.deliveredTime = os.time and os.time() or 0
        end

        saveStore(store, storePath)
    end)

    function messaging.setDevice(newDevice)
        device = copyTable(newDevice or device)
    end

    function messaging.send(destination, text)
        destination = string.upper(tostring(destination or ""))
        text = tostring(text or "")

        if destination == "" or destination == "UNKNOWN" then
            return false, "Destination is invalid"
        end

        if text == "" then
            return false, "Message is empty"
        end

        local created = timestamp()

        local item = {
            id = generateMessageID(device.address),
            from = device.address,
            to = destination,
            text = text,
            day = created.day,
            time = created.time,
            status = "QUEUED"
        }

        table.insert(store.outbox, item)
        trim(store.outbox)
        saveStore(store, storePath)

        local sent, reason = submit(item)

        if not sent then
            return false, reason
        end

        return true, item.id
    end

    function messaging.retry(messageId)
        for _, item in ipairs(store.outbox) do
            if item.id == messageId then
                item.status = "QUEUED"
                item.reason = nil
                return submit(item)
            end
        end

        return false, "Message was not found"
    end

    function messaging.getInbox()
        local result = {}

        for index = #store.inbox, 1, -1 do
            table.insert(result, copyTable(store.inbox[index]))
        end

        return result
    end

    function messaging.getOutbox()
        local result = {}

        for index = #store.outbox, 1, -1 do
            table.insert(result, copyTable(store.outbox[index]))
        end

        return result
    end

    function messaging.getUnreadCount()
        local count = 0

        for _, item in ipairs(store.inbox) do
            if item.unread then
                count = count + 1
            end
        end

        return count
    end

    function messaging.markRead(messageId)
        local item = findInbox(messageId)

        if not item then
            return false
        end

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

    function messaging.getPath()
        return storePath
    end

    function messaging.getSummary()
        return {
            inbox = #store.inbox,
            outbox = #store.outbox,
            unread = messaging.getUnreadCount()
        }
    end

    -- Resume messages which were waiting for an acknowledgement when the
    -- computer stopped. The stable message ID prevents duplicate inbox rows.
    for _, item in ipairs(store.outbox) do
        if item.status == "QUEUED"
            or item.status == "SENT"
            or item.status == "RETRYING" then
            submit(item)
        end
    end

    return messaging
end

return module
