-- MCNet contacts tests

local contactsLibrary = dofile("services/communications/contacts.lua")
local path = ".mcnet/contacts_test.lua"
local passed, failed = 0, 0
if fs.exists(path) then fs.delete(path) end
if fs.exists(path .. ".tmp") then fs.delete(path .. ".tmp") end
local contacts = contactsLibrary.new(path)
local function check(name, condition)
    if condition then passed=passed+1; print("PASS  "..name)
    else failed=failed+1; print("FAIL  "..name) end
end
local saved = contacts.add("Dad", "pda 040")
check("contact saves", saved == true)
check("address normalises", contacts.getAll()[1].address == "PDA-040")
check("contact resolves", contacts.resolve("PDA-040") == "Dad")
contacts.add("Father", "PDA-040")
check("duplicate address updates", #contacts.getAll() == 1 and contacts.resolve("PDA-040") == "Father")
contacts.remove("PDA-040")
check("contact removes", #contacts.getAll() == 0)
if fs.exists(path) then fs.delete(path) end
if fs.exists(path .. ".tmp") then fs.delete(path .. ".tmp") end
print("") print("Passed: "..tostring(passed)) print("Failed: "..tostring(failed))
if failed>0 then error("Contacts tests failed",0) end
