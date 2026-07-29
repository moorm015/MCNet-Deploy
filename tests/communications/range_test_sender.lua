-- MCNet wireless range test sender
-- Intended for a wireless pocket computer.

local SEND_CHANNEL = 4242
local REPLY_CHANNEL = 4243
local TIMEOUT_SECONDS = 4

local modem = peripheral.find("modem")

if not modem then
    error("No wireless modem found")
end

modem.open(REPLY_CHANNEL)

local sequence = 0

term.clear()
term.setCursorPos(1, 1)

print("MCNet Range Test")
print("----------------")
print("Pocket ID: " .. os.getComputerID())
print("")
print("Type a message and press Enter.")
print("Type exit to stop.")
print("")

while true do
    write("> ")
    local text = read()

    if text == "exit" then
        print("Range test stopped")
        break
    end

    sequence = sequence + 1

    local packet = {
        type = "RANGE_TEST",
        sender = os.getComputerID(),
        sequence = sequence,
        text = text
    }

    modem.transmit(SEND_CHANNEL, REPLY_CHANNEL, packet)

    print("Sent packet " .. sequence)
    print("Waiting for reply...")

    local timer = os.startTimer(TIMEOUT_SECONDS)
    local replied = false

    while not replied do
        local event, side, channel, replyChannel, message, distance =
            os.pullEvent()

        if event == "modem_message" and channel == REPLY_CHANNEL then
            if type(message) == "table" and message.type == "ACK" then
                print("Reply received")
                print("Receiver: " .. tostring(message.receiver))

                if distance then
                    print("Distance: " .. tostring(distance) .. " blocks")
                end

                replied = true
            end
        elseif event == "timer" and side == timer then
            print("No reply - out of range or receiver offline")
            replied = true
        end
    end

    print("")
end