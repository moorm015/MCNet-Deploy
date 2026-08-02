-- MCNet core directory and mailbox tests

local serverLibrary = dofile("services/communications/core_server.lua")
local passed, failed = 0, 0
local path = ".mcnet/core_server_test.lua"
local handlers, deliveryHandlers, sends = {}, {}, {}
local counter = 0

local function clean()
    if fs.exists(path) then fs.delete(path) end
    if fs.exists(path .. ".tmp") then fs.delete(path .. ".tmp") end
end
clean()

local network = {}
function network.on(service, handler) handlers[service] = handler; return true end
function network.onDelivery(handler) deliveryHandlers[#deliveryHandlers+1]=handler; return true end
function network.send(destination, service, packetType, payload)
    counter=counter+1
    local id="CORE-PKT-"..tostring(counter)
    sends[id]={destination=destination,service=service,type=packetType,payload=payload}
    return true,id
end

local server = serverLibrary.new(network, {address="SRV-001",friendlyName="MCNet Core"}, {
    onlineTimeout=28, mailboxRetryInterval=1, mailboxRetention=120,
    maxMailbox=50, maxEvents=50
}, path)

local function check(name, condition)
    if condition then passed=passed+1; print("PASS  "..name)
    else failed=failed+1; print("FAIL  "..name) end
end

handlers.CORE({source="TWR-001",type="HEARTBEAT",payload={
    device={address="TWR-001",friendlyName="Home Tower",type="TOWER",region="HOME"},
    network={localEndpoints=2,neighbours=1,counters={framesForwarded=10}}
}})
handlers.CORE({source="PDA-002",type="HEARTBEAT",payload={
    device={address="PDA-002",friendlyName="Dad's PDA",type="PDA",region="HOME"},
    selectedTower="TWR-001",network={}
}})
local snap=server.getSnapshot()
check("directory records devices", snap.totals.devices == 3 and snap.totals.devicesOnline == 3)
check("core server registers itself", snap.devices[1] ~= nil)
check("tower registry records tower", snap.totals.towers == 1 and snap.towers[1].address == "TWR-001")

handlers.MAILBOX({source="PDA-001",type="SUBMIT",payload={message={
    id="MSG-1",from="PDA-001",to="PDA-002",text="Hello",day=1,time=2
}}})
check("mailbox stores message", server.getSnapshot().mailbox.pending == 1)
server.tick()
local deliveryId = nil
for id, item in pairs(sends) do
    if item.service == "MESSAGING" and item.type == "MAILBOX_DELIVERY" then deliveryId=id end
end
check("online recipient is attempted", deliveryId ~= nil)

handlers.MAILBOX({source="PDA-002",type="DELIVERED",payload={messageId="MSG-1"}})
local final=server.getSnapshot()
check("delivery confirmation counted", final.stats.mailboxDelivered == 1)
check("message retained for status reconciliation", final.mailbox.deliveredRecent == 1)

handlers.MAILBOX({source="PDA-001",type="STATUS_REQUEST",payload={messageIds={"MSG-1"}}})
local statusFound = false
for _, item in pairs(sends) do
    if item.service == "MAILBOX" and item.type == "STATUS"
        and item.payload.messageId == "MSG-1" and item.payload.state == "DELIVERED" then
        statusFound = true
    end
end
check("sender can reconcile delivered status", statusFound)

clean()
print("")
print("Passed: "..tostring(passed))
print("Failed: "..tostring(failed))
if failed>0 then error("Core service tests failed",0) end
