-- MCNet persistent messaging tests

local messagingLibrary = dofile("services/communications/messaging.lua")
local passed = 0
local failed = 0
local testPath = ".mcnet/messages_test.lua"
local handlers = {}
local deliveryHandlers = {}
local packetCounter = 0

if fs.exists(testPath) then
    fs.delete(testPath)
end

if fs.exists(testPath .. ".tmp") then
    fs.delete(testPath .. ".tmp")
end

local fakeNetwork = {}

function fakeNetwork.on(service, handler)
    handlers[service] = handler
    return true
end

function fakeNetwork.onDelivery(handler)
    table.insert(deliveryHandlers, handler)
    return true
end

function fakeNetwork.send(destination, service, packetType, payload)
    packetCounter = packetCounter + 1
    return true, "PKT-" .. tostring(packetCounter)
end

local messaging = messagingLibrary.new(fakeNetwork, {
    address = "PDA-001"
}, testPath)

local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

local sent, messageId = messaging.send("PDA-002", "Hello")
check("message queues", sent == true and type(messageId) == "string")
check("outbox stores message", #messaging.getOutbox() == 1)

for _, handler in ipairs(deliveryHandlers) do
    handler("PKT-1", "DELIVERED")
end

local outbox = messaging.getOutbox()
check("delivery updates status", outbox[1].status == "DELIVERED")

handlers.MESSAGING({
    id = "REMOTE-PACKET",
    source = "PDA-002",
    destination = "PDA-001",
    service = "MESSAGING",
    type = "TEXT",
    payload = {
        messageId = "REMOTE-MSG-1",
        text = "Reply",
        sentDay = 5,
        sentTime = 12
    }
})

local inbox = messaging.getInbox()
check("incoming message stored", #inbox == 1 and inbox[1].text == "Reply")
check("incoming message unread", messaging.getUnreadCount() == 1)

handlers.MESSAGING({
    id = "REMOTE-PACKET-2",
    source = "PDA-002",
    destination = "PDA-001",
    service = "MESSAGING",
    type = "TEXT",
    payload = {
        messageId = "REMOTE-MSG-1",
        text = "Reply",
        sentDay = 5,
        sentTime = 12
    }
})

check("duplicate message ignored", #messaging.getInbox() == 1)

messaging.markRead("REMOTE-MSG-1")
check("mark read works", messaging.getUnreadCount() == 0)

if fs.exists(testPath) then
    fs.delete(testPath)
end

if fs.exists(testPath .. ".tmp") then
    fs.delete(testPath .. ".tmp")
end

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Messaging tests failed", 0)
end
