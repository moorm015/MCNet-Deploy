-- MCNet responsive layout tests

local layout = dofile("services/ui/layout.lua")
local passed = 0
local failed = 0

local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

local pda = layout.calculate(26, 20, "auto", true)
check("PDA is compact", pda.mode == "compact")
check("PDA uses full width", pda.left == 1 and pda.right == 26)

local computer = layout.calculate(51, 19, "auto", true)
check("computer is standard", computer.mode == "standard")
check("computer has frame", computer.framed == true)

local monitor = layout.calculate(100, 30, "auto", true)
check("large monitor is wide", monitor.mode == "wide")

local forcedCompact = layout.calculate(100, 30, "compact", true)
check("forced compact works", forcedCompact.mode == "compact")

local forcedFull = layout.calculate(26, 20, "full", true)
check("forced full avoids compact", forcedFull.mode ~= "compact")

print("")
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))

if failed > 0 then
    error("Layout tests failed", 0)
end
