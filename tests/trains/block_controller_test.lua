-- MCNet block controller tests
-- Version 0.9.8
--
-- Run from the MCNet root:
--   tests/trains/block_controller_test.lua

local blockController = dofile("services/trains/block_controller.lua")

local passed = 0
local failed = 0

local function fail(message)
    error(tostring(message), 0)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(
            (message or "Values differ")
            .. "\nExpected: " .. tostring(expected)
            .. "\nActual:   " .. tostring(actual)
        )
    end
end

local function assertTrue(value, message)
    if value ~= true then
        fail((message or "Expected true") .. "\nActual: " .. tostring(value))
    end
end

local function assertFalse(value, message)
    if value ~= false then
        fail((message or "Expected false") .. "\nActual: " .. tostring(value))
    end
end

local function assertContains(text, expected, message)
    text = tostring(text or "")
    expected = tostring(expected or "")

    if not string.find(text, expected, 1, true) then
        fail(
            (message or "Expected text was not found")
            .. "\nExpected to contain: " .. expected
            .. "\nActual: " .. text
        )
    end
end

local function runTest(name, fn)
    local ok, reason = pcall(fn)

    if ok then
        passed = passed + 1
        print("[PASS] " .. tostring(name))
    else
        failed = failed + 1
        print("[FAIL] " .. tostring(name))
        print("       " .. tostring(reason))
    end
end

local function newController()
    return blockController.new({
        id = "A1-A2",
        name = "Test Block",
        releaseTimeout = 0,
        traversalTimeout = 0,
        clearanceTimeout = 0
    })
end

local function clearInputs(controller)
    return controller.update({ entry = false, exit = false })
end

local function reserveAndRelease(controller, trainId)
    local ok, reason = controller.reserve(trainId)
    assertTrue(ok, reason)

    ok, reason = controller.authoriseEntry(trainId)
    assertTrue(ok, reason)
end

local function enterFully(controller, trainId)
    clearInputs(controller)
    reserveAndRelease(controller, trainId)

    local state = controller.update({ entry = true, exit = false })
    assertEqual(state.state, "ENTERING")

    state = controller.update({ entry = false, exit = false })
    assertEqual(state.state, "OCCUPIED")

    return state
end

local function completeTraversal(controller, trainId)
    enterFully(controller, trainId)

    local state = controller.update({ entry = false, exit = true })
    assertEqual(state.state, "LEAVING")

    state = controller.update({ entry = false, exit = false })
    assertEqual(state.state, "CLEAR")

    return state
end

runTest("startup clear is CLEAR and holding", function()
    local c = newController()
    local state = clearInputs(c)

    assertEqual(state.state, "CLEAR")
    assertTrue(c.isClear())
    assertFalse(c.isOccupied())
    assertFalse(c.wantsRelease())
end)

runTest("reservation alone keeps entrance held", function()
    local c = newController()
    clearInputs(c)

    local ok, reason = c.reserve("TRAIN-001")
    assertTrue(ok, reason)

    local state = c.getState()
    assertEqual(state.state, "RESERVED")
    assertEqual(state.trainId, "TRAIN-001")
    assertTrue(state.reserved)
    assertFalse(state.occupied)
    assertFalse(c.wantsRelease())
end)

runTest("authorised reservation requests RELEASE", function()
    local c = newController()
    clearInputs(c)
    reserveAndRelease(c, "TRAIN-002")

    assertEqual(c.getState().state, "RELEASED")
    assertTrue(c.wantsRelease())
end)

runTest("ENTRY ON consumes authority and restores HOLD", function()
    local c = newController()
    clearInputs(c)
    reserveAndRelease(c, "TRAIN-003")

    local state = c.update({ entry = true, exit = false })

    assertEqual(state.state, "ENTERING")
    assertTrue(state.occupied)
    assertFalse(c.wantsRelease())
end)

runTest("ENTRY OFF proves whole consist entered", function()
    local c = newController()
    local state = enterFully(c, "TRAIN-004")

    assertEqual(state.state, "OCCUPIED")
    assertTrue(state.sawEntryClear)
    assertTrue(state.occupied)
end)

runTest("normal EXIT ON then OFF returns CLEAR", function()
    local c = newController()
    local state = completeTraversal(c, "TRAIN-005")

    assertTrue(c.isClear())
    assertFalse(state.occupied)
    assertFalse(state.reserved)
    assertEqual(state.trainId, nil)
    assertFalse(c.wantsRelease())
end)

runTest("EXIT ON alone does not clear the block", function()
    local c = newController()
    enterFully(c, "TRAIN-006")

    local state = c.update({ entry = false, exit = true })

    assertEqual(state.state, "LEAVING")
    assertTrue(state.occupied)
    assertFalse(c.isClear())
end)

runTest("second train cannot reserve occupied reservation", function()
    local c = newController()
    clearInputs(c)

    local ok, reason = c.reserve("TRAIN-007")
    assertTrue(ok, reason)

    ok, reason = c.reserve("TRAIN-008")
    assertFalse(ok)
    assertContains(reason, "not clear")
end)

runTest("same train may repeat its reservation safely", function()
    local c = newController()
    clearInputs(c)

    local ok, reason = c.reserve("TRAIN-009")
    assertTrue(ok, reason)

    ok, reason = c.reserve("TRAIN-009")
    assertTrue(ok, reason)
    assertEqual(c.getState().trainId, "TRAIN-009")
end)

runTest("wrong train cannot use another reservation", function()
    local c = newController()
    clearInputs(c)

    local ok, reason = c.reserve("TRAIN-010")
    assertTrue(ok, reason)

    ok, reason = c.authoriseEntry("TRAIN-011")
    assertFalse(ok)
    assertContains(reason, "does not match")
    assertFalse(c.wantsRelease())
end)

runTest("reservation can be cancelled before entry", function()
    local c = newController()
    clearInputs(c)

    local ok, reason = c.reserve("TRAIN-012")
    assertTrue(ok, reason)

    ok, reason = c.cancelReservation("TRAIN-012")
    assertTrue(ok, reason)
    assertTrue(c.isClear())
    assertFalse(c.wantsRelease())
end)

runTest("released authority can be withdrawn before entry", function()
    local c = newController()
    clearInputs(c)
    reserveAndRelease(c, "TRAIN-013")

    c.hold()

    local state = c.getState()
    assertEqual(state.state, "RESERVED")
    assertEqual(state.trainId, "TRAIN-013")
    assertFalse(c.wantsRelease())
end)

runTest("unauthorised entry faults fail safe", function()
    local c = newController()
    clearInputs(c)

    local state = c.update({ entry = true, exit = false })

    assertEqual(state.state, "FAULT")
    assertEqual(state.fault.code, "UNAUTHORISED_ENTRY")
    assertTrue(c.isOccupied())
    assertFalse(c.wantsRelease())
end)

runTest("entry while reserved but held faults", function()
    local c = newController()
    clearInputs(c)

    local ok, reason = c.reserve("TRAIN-014")
    assertTrue(ok, reason)

    local state = c.update({ entry = true, exit = false })

    assertEqual(state.state, "FAULT")
    assertEqual(state.fault.code, "ENTRY_WHILE_HELD")
    assertFalse(c.wantsRelease())
end)

runTest("exit before whole train enters faults", function()
    local c = newController()
    clearInputs(c)
    reserveAndRelease(c, "TRAIN-015")

    local state = c.update({ entry = true, exit = false })
    assertEqual(state.state, "ENTERING")

    state = c.update({ entry = true, exit = true })

    assertEqual(state.state, "FAULT")
    assertEqual(state.fault.code, "EXIT_BEFORE_ENTRY_CLEAR")
    assertFalse(c.wantsRelease())
end)

runTest("exit while clear faults", function()
    local c = newController()
    clearInputs(c)

    local state = c.update({ entry = false, exit = true })

    assertEqual(state.state, "FAULT")
    assertEqual(state.fault.code, "EXIT_WITHOUT_OCCUPANCY")
end)

runTest("second entry while occupied faults", function()
    local c = newController()
    enterFully(c, "TRAIN-016")

    local state = c.update({ entry = true, exit = false })

    assertEqual(state.state, "FAULT")
    assertEqual(state.fault.code, "SECOND_OR_UNEXPECTED_ENTRY")
    assertFalse(c.wantsRelease())
end)

runTest("startup with active ENTRY faults", function()
    local c = newController()
    local state = c.update({ entry = true, exit = false })

    assertEqual(state.state, "FAULT")
    assertEqual(state.fault.code, "STARTUP_SENSOR_ACTIVE")
    assertFalse(c.wantsRelease())
end)

runTest("startup with active EXIT faults", function()
    local c = newController()
    local state = c.update({ entry = false, exit = true })

    assertEqual(state.state, "FAULT")
    assertEqual(state.fault.code, "STARTUP_SENSOR_ACTIVE")
end)

runTest("fault cannot clear while detector is active", function()
    local c = newController()
    c.update({ entry = true, exit = false })

    local ok, reason = c.clearFault()

    assertFalse(ok)
    assertContains(reason, "detector is active")
end)

runTest("fault clears once detectors are physically clear", function()
    local c = newController()

    c.update({ entry = true, exit = false })
    c.update({ entry = false, exit = false })

    local ok, reason = c.clearFault()

    assertTrue(ok, reason)
    assertTrue(c.isClear())
    assertFalse(c.wantsRelease())
end)

runTest("maintenance reset never powers a locking track", function()
    local c = newController()
    clearInputs(c)

    local ok, reason = c.forceReset("TRAIN-017", "RELEASED")

    assertTrue(ok, reason)
    assertEqual(c.getState().state, "RESERVED")
    assertFalse(c.wantsRelease())
end)

runTest("maintenance occupied reset requires train ID", function()
    local c = newController()
    clearInputs(c)

    local ok, reason = c.forceReset(nil, "OCCUPIED")

    assertFalse(ok)
    assertContains(reason, "train ID")
end)

runTest("stop always restores HOLD", function()
    local c = newController()
    clearInputs(c)
    reserveAndRelease(c, "TRAIN-018")

    assertTrue(c.wantsRelease())
    c.stop()
    assertFalse(c.wantsRelease())
end)

print("")
print(tostring(passed) .. " passed, " .. tostring(failed) .. " failed")

if failed > 0 then
    error(tostring(failed) .. " block controller test(s) failed", 0)
end
