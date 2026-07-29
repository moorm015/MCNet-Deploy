-- MCNet wireless range test receiver
-- Intended for a stationary computer with a wireless modem on the back.

local CHANNEL = 4242

local modem = peripheral.wrap("back")

if not modem then
    error("No peripheral found on the back")
end

if peripheral.getType("back") ~= "modem" then
    error("The peripheral on the back is not a modem")
end

modem.open(CHANNEL)

term.clear()
term.setCursorPos(1, 1)

print("MCNet Range Test")
print("----------------")
print("Receiver channel: " .. CHANNEL)
print("Computer ID: " .. os.getComputerID())
print("")
print("Waiting for messages...")

while true do
    local _, side, channel, replyChannel, message, distance =
        os.pullEvent("modem_message")

    if channel == CHANNEL then
        print("")
        print("Packet received")

        if type(message) == "table" then
            print("Sender: " .. tostring(message.sender))
            print("Sequence: " .. tostring(message.sequence))
            print("Message: " .. tostring(message.text))
        else
            print("Message: " .. tostring(message))
        end

        if distance then
            print("Distance: " .. tostring(distance) .. " blocks")
        else
            print("Distance unavailable")
        end

        modem.transmit(replyChannel, CHANNEL, {
            type = "ACK",
            receiver = os.getComputerID(),
            receivedDistance = distance
        })
    end
end