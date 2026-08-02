-- MCNet display configuration tests

local display = dofile("services/system/display_config.lua")
local path = ".mcnet/display_test.lua"
local passed, failed = 0, 0
if fs.exists(path) then fs.delete(path) end
if fs.exists(path .. ".tmp") then fs.delete(path .. ".tmp") end
local function check(name, condition)
    if condition then passed=passed+1; print("PASS  "..name)
    else failed=failed+1; print("FAIL  "..name) end
end
local value = display.normalise({refreshInterval=0,screens={left={dashboard="communications.towers",textScale=0.1}}})
check("refresh clamps", value.refreshInterval == 1)
check("scale clamps", value.screens.left.textScale == 0.5)
check("dashboard retained", value.screens.left.dashboard == "communications.towers")
local saved = display.save(value,path)
check("configuration saves", saved == true and fs.exists(path))
local loaded = display.load(path)
check("configuration loads", loaded.screens.left.dashboard == "communications.towers")
check("future dashboards listed", #display.getDashboards("Trains") == 3)
if fs.exists(path) then fs.delete(path) end
if fs.exists(path .. ".tmp") then fs.delete(path .. ".tmp") end
print("") print("Passed: "..tostring(passed)) print("Failed: "..tostring(failed))
if failed>0 then error("Display configuration tests failed",0) end
