--[[
    MCNet Modem Driver Test
    Version: 0.1.0

    Tests the modem driver on a single ComputerCraft computer.
    A modem must be attached before running this test.
]]

local packet = dofile("services/communications/packet.lua")
local modemDriver = dofile("drivers/modem.lua")

local passed = 0
local failed = 0

local function pass(message)
    passed = passed + 1
    print("[PASS] " .. message)
end

local function fail(message, reason)
    failed = failed + 1

    if reason ~= nil then
        print("[FAIL] " .. message .. ": " .. tostring(reason))
    else
        print("[FAIL] " .. message)
    end
end

local function expect(condition, message, reason)
    if condition then
        pass(message)
    else
        fail(message, reason)
    end
end

print("MCNet Modem Driver Test")
print("=======================")
print("")

-- Test 1: Driver constants

expect(
    modemDriver.CHANNEL.DATA == 43000,
    "Data channel is correct"
)

expect(
    modemDriver.CHANNEL.DISCOVERY == 43001,
    "Discovery channel is correct"
)

expect(
    modemDriver.CHANNEL.CONTROL == 43002,
    "Control channel is correct"
)

expect(
    modemDriver.CHANNEL.UPDATE == 43003,
    "Update channel is correct"
)

expect(
    modemDriver.CHANNEL.EMERGENCY == 43004,
    "Emergency channel is correct"
)

expect(
    modemDriver.DEFAULT_CHANNEL == modemDriver.CHANNEL.DATA,
    "Default channel is the data channel"
)

-- Test 2: Find attached modem

local modemSide = modemDriver.getSide()

expect(
    modemSide ~= nil,
    "Attached modem was found",
    "Attach a wired or wireless modem to the computer"
)

if modemSide ~= nil then
    print("       Modem side: " .. tostring(modemSide))
end

-- Continue only if a modem exists.

if modemSide ~= nil then
    -- Test 3: Open MCNet channels

    local opened, openReason = modemDriver.open()

    expect(
        opened == true,
        "Modem driver opened successfully",
        openReason
    )

    expect(
        modemDriver.isOpen() == true,
        "Modem driver reports open state"
    )

    expect(
        modemDriver.isChannelOpen(modemDriver.CHANNEL.DATA),
        "Data channel was opened"
    )

    expect(
        modemDriver.isChannelOpen(modemDriver.CHANNEL.DISCOVERY),
        "Discovery channel was opened"
    )

    expect(
        modemDriver.isChannelOpen(modemDriver.CHANNEL.CONTROL),
        "Control channel was opened"
    )

    expect(
        modemDriver.isChannelOpen(modemDriver.CHANNEL.UPDATE),
        "Update channel was opened"
    )

    expect(
        modemDriver.isChannelOpen(modemDriver.CHANNEL.EMERGENCY),
        "Emergency channel was opened"
    )

    -- Calling open twice should be safe.

    local openedAgain, openAgainReason = modemDriver.open()

    expect(
        openedAgain == true,
        "Opening an already-open driver is safe",
        openAgainReason
    )

    -- Test 4: Create a valid test packet

    local testPacket = packet.create({
        source = "TEST-001",
        destination = "TEST-002",
        service = packet.SERVICE.COMMUNICATIONS,
        type = packet.TYPE.MESSAGE,

        payload = {
            text = "MCNet modem test"
        }
    })

    local packetValid, packetReason = packet.validate(testPacket)

    expect(
        packetValid == true,
        "Test packet is valid",
        packetReason
    )

    -- Test 5: Send valid packet

    local sent, sendReason = modemDriver.send(testPacket)

    expect(
        sent == true,
        "Valid packet was transmitted",
        sendReason
    )

    -- Test 6: Send on another MCNet channel

    local controlSent, controlReason = modemDriver.send(
        testPacket,
        modemDriver.CHANNEL.CONTROL
    )

    expect(
        controlSent == true,
        "Packet was transmitted on control channel",
        controlReason
    )

    -- Test 7: Reject invalid channel

    local invalidChannelSent, invalidChannelReason =
        modemDriver.send(testPacket, 70000)

    expect(
        invalidChannelSent == false,
        "Invalid modem channel was rejected",
        invalidChannelReason
    )

    -- Test 8: Reject non-integer channel

    local decimalChannelSent, decimalChannelReason =
        modemDriver.send(testPacket, 43000.5)

    expect(
        decimalChannelSent == false,
        "Non-integer modem channel was rejected",
        decimalChannelReason
    )

    -- Test 9: Reject invalid packet

    local invalidPacket = {
        version = packet.PROTOCOL_VERSION,
        id = "INVALID-TEST",
        source = "",
        destination = "TEST-002",
        service = packet.SERVICE.COMMUNICATIONS,
        type = packet.TYPE.MESSAGE,
        ttl = packet.DEFAULT_TTL,
        priority = packet.PRIORITY.NORMAL
    }

    local invalidSent, invalidSendReason =
        modemDriver.send(invalidPacket)

    expect(
        invalidSent == false,
        "Invalid packet was rejected before transmission",
        invalidSendReason
    )

    -- Test 10: Reject direct packet passed to broadcast()

    local incorrectBroadcast, incorrectBroadcastReason =
        modemDriver.broadcast(testPacket)

    expect(
        incorrectBroadcast == false,
        "Direct packet was rejected by broadcast",
        incorrectBroadcastReason
    )

    -- Test 11: Accept proper broadcast packet

    local broadcastPacket = packet.create({
        source = "TEST-001",
        destination = packet.DESTINATION.BROADCAST,
        service = packet.SERVICE.DISCOVERY,
        type = packet.TYPE.ANNOUNCE,

        payload = {
            message = "MCNet test broadcast"
        }
    })

    local broadcastSent, broadcastReason =
        modemDriver.broadcast(broadcastPacket)

    expect(
        broadcastSent == true,
        "Broadcast packet was transmitted",
        broadcastReason
    )

    -- Test 12: Reject invalid timeout without waiting

    local timeoutPacket, timeoutReason =
        modemDriver.receive(-1)

    expect(
        timeoutPacket == nil
            and timeoutReason
                == "Receive timeout must be a non-negative number",
        "Negative receive timeout was rejected",
        timeoutReason
    )

    -- Test 13: Receive timeout

    print("")
    print("Testing one-second receive timeout...")

    local received, receiveReason =
        modemDriver.receive(1)

    expect(
        received == nil and receiveReason == "timeout",
        "Receive returned after timeout",
        receiveReason
    )

    -- Test 14: Close MCNet channels

    local closed, closeReason = modemDriver.close()

    expect(
        closed == true,
        "Modem driver closed successfully",
        closeReason
    )

    expect(
        modemDriver.isOpen() == false,
        "Modem driver reports closed state"
    )

    expect(
        not modemDriver.isChannelOpen(modemDriver.CHANNEL.DATA),
        "Data channel was closed"
    )

    expect(
        not modemDriver.isChannelOpen(modemDriver.CHANNEL.DISCOVERY),
        "Discovery channel was closed"
    )

    expect(
        not modemDriver.isChannelOpen(modemDriver.CHANNEL.CONTROL),
        "Control channel was closed"
    )

    expect(
        not modemDriver.isChannelOpen(modemDriver.CHANNEL.UPDATE),
        "Update channel was closed"
    )

    expect(
        not modemDriver.isChannelOpen(modemDriver.CHANNEL.EMERGENCY),
        "Emergency channel was closed"
    )

    -- Test 15: Sending while closed must fail

    local sentWhileClosed, closedSendReason =
        modemDriver.send(testPacket)

    expect(
        sentWhileClosed == false,
        "Transmission while closed was rejected",
        closedSendReason
    )

    -- Calling close twice should be safe.

    local closedAgain, closeAgainReason = modemDriver.close()

    expect(
        closedAgain == true,
        "Closing an already-closed driver is safe",
        closeAgainReason
    )
end

print("")
print("Test summary")
print("============")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed == 0 then
    print("")
    print("All modem driver tests passed.")
else
    print("")
    print("Modem driver tests failed.")
end