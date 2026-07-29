-- MCNet packet library test

local packet = dofile("services/communications/packet.lua")

local passed = 0
local failed = 0

local function pass(message)
    passed = passed + 1
    print("[PASS] " .. message)
end

local function fail(message)
    failed = failed + 1
    print("[FAIL] " .. message)
end

local function expect(condition, message)
    if condition then
        pass(message)
    else
        fail(message)
    end
end

print("MCNet Packet Test")
print("=================")
print("")

local testPacket = packet.create({
    source = "pda-max",
    destination = "tower-001",
    service = packet.SERVICE.COMMUNICATIONS,
    type = packet.TYPE.HELLO,
    priority = packet.PRIORITY.NORMAL,

    payload = {
        message = "Hello MCNet"
    }
})

local valid, reason = packet.validate(testPacket)

expect(
    valid,
    "Created packet is valid"
)

if not valid then
    print("Reason: " .. tostring(reason))
end

expect(
    testPacket.version == packet.PROTOCOL_VERSION,
    "Protocol version is correct"
)

expect(
    type(testPacket.id) == "string" and testPacket.id ~= "",
    "Packet ID was generated"
)

expect(
    testPacket.source == "PDA-MAX",
    "Source was normalised to upper case"
)

expect(
    testPacket.destination == "TOWER-001",
    "Destination was normalised to upper case"
)

expect(
    testPacket.service == packet.SERVICE.COMMUNICATIONS,
    "Service was stored correctly"
)

expect(
    testPacket.type == packet.TYPE.HELLO,
    "Packet type was stored correctly"
)

expect(
    testPacket.priority == packet.PRIORITY.NORMAL,
    "Default priority is correct"
)

expect(
    testPacket.ttl == packet.DEFAULT_TTL,
    "Default TTL is correct"
)

expect(
    testPacket.payload.message == "Hello MCNet",
    "Payload was stored correctly"
)

local originalTTL = testPacket.ttl
local forwarded, forwardReason = packet.decrementTTL(testPacket)

expect(
    forwarded and testPacket.ttl == originalTTL - 1,
    "TTL was reduced correctly"
)

if not forwarded then
    print("Reason: " .. tostring(forwardReason))
end

local broadcastPacket = packet.create({
    source = "TOWER-001",
    destination = packet.DESTINATION.BROADCAST,
    service = packet.SERVICE.DISCOVERY,
    type = packet.TYPE.DISCOVER
})

local isBroadcastForDevice = packet.isForDevice(
    broadcastPacket,
    "PDA-MAX"
)

expect(
    isBroadcastForDevice == true,
    "Broadcast packet is accepted by a device"
)

local directPacket = packet.create({
    source = "TOWER-001",
    destination = "PDA-MAX",
    service = packet.SERVICE.COMMUNICATIONS,
    type = packet.TYPE.MESSAGE
})

local isDirectForDevice = packet.isForDevice(
    directPacket,
    "pda-max"
)

expect(
    isDirectForDevice == true,
    "Direct packet is accepted by its destination"
)

local isDirectForWrongDevice = packet.isForDevice(
    directPacket,
    "TRAIN-001"
)

expect(
    isDirectForWrongDevice == false,
    "Direct packet is rejected by another device"
)

local responsePacket = packet.createResponse(
    directPacket,
    "PDA-MAX",
    packet.TYPE.ACK,
    {
        received = true
    }
)

expect(
    responsePacket.destination == directPacket.source,
    "Response is addressed to the original sender"
)

expect(
    responsePacket.service == directPacket.service,
    "Response uses the original service"
)

expect(
    responsePacket.type == packet.TYPE.ACK,
    "Response type was stored correctly"
)

expect(
    responsePacket.payload.received == true,
    "Response payload was stored correctly"
)

local invalidPacket = {
    version = packet.PROTOCOL_VERSION,
    id = "TEST",
    source = "",
    destination = "TOWER-001",
    service = packet.SERVICE.COMMUNICATIONS,
    type = packet.TYPE.HELLO,
    ttl = packet.DEFAULT_TTL,
    priority = packet.PRIORITY.NORMAL
}

local invalidAccepted = packet.validate(invalidPacket)

expect(
    invalidAccepted == false,
    "Invalid packet was rejected"
)

local validAddress = packet.validateAddress("TOWER-001")

expect(
    validAddress == true,
    "Valid address was accepted"
)

local invalidAddress = packet.validateAddress("tower 001")

expect(
    invalidAddress == false,
    "Invalid address was rejected"
)

print("")
print("Packet contents:")
print(textutils.serialize(testPacket))

print("")
print("Test summary")
print("============")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed == 0 then
    print("")
    print("All packet tests passed.")
else
    print("")
    print("Packet tests failed.")
end