-- MCNet platform controller tests
-- Version 0.9.2
--
-- Run directly from the MCNet root:
--
--   tests/trains/platform_controller_test.lua
--
-- These tests exercise the logical platform state machine only.
-- No real detector, bundled cable or locking track is required.

local platformController =
    dofile(
        "services/trains/platform_controller.lua"
    )

local passed = 0
local failed = 0

local function fail(message)
    error(
        tostring(message),
        0
    )
end

local function assertEqual(
    actual,
    expected,
    message
)
    if actual ~= expected then
        fail(
            (message or "Values differ")
            .. "\nExpected: "
            .. tostring(expected)
            .. "\nActual:   "
            .. tostring(actual)
        )
    end
end

local function assertTrue(
    value,
    message
)
    if value ~= true then
        fail(
            (message or "Expected true")
            .. "\nActual: "
            .. tostring(value)
        )
    end
end

local function assertFalse(
    value,
    message
)
    if value ~= false then
        fail(
            (message or "Expected false")
            .. "\nActual: "
            .. tostring(value)
        )
    end
end

local function assertContains(
    text,
    expected,
    message
)
    text =
        tostring(
            text or ""
        )

    expected =
        tostring(
            expected or ""
        )

    if not string.find(
        text,
        expected,
        1,
        true
    ) then

        fail(
            (message or "Expected text was not found")
            .. "\nExpected to contain: "
            .. expected
            .. "\nActual: "
            .. text
        )
    end
end

local function runTest(
    name,
    fn
)
    local ok, reason =
        pcall(fn)

    if ok then
        passed =
            passed + 1

        print(
            "[PASS] "
            .. tostring(name)
        )
    else
        failed =
            failed + 1

        print(
            "[FAIL] "
            .. tostring(name)
        )

        print(
            "       "
            .. tostring(reason)
        )
    end
end

local function newController()
    return platformController.new({
        id = "P1",
        name = "Platform 1",
        approachTimeout = 0,
        departureTimeout = 0
    })
end

local function clearInputs(controller)
    return controller.update({
        d1 = false,
        d2 = false,
        d3 = false
    })
end

local function arriveAndBerth(
    controller,
    trainId
)
    clearInputs(
        controller
    )

    if trainId then
        local ok, reason =
            controller.assignTrain(
                trainId
            )

        assertTrue(
            ok,
            reason
        )
    end

    local state =
        controller.update({
            d1 = true,
            d2 = false,
            d3 = false
        })

    assertEqual(
        state.state,
        "APPROACHING",
        "D1 should start an approach"
    )

    state =
        controller.update({
            d1 = true,
            d2 = true,
            d3 = false
        })

    assertEqual(
        state.state,
        "ENTERING",
        "D2 should move the platform to ENTERING"
    )

    state =
        controller.update({
            d1 = false,
            d2 = true,
            d3 = false
        })

    assertEqual(
        state.state,
        "BERTHED",
        "D1 clearing after D2 should prove the whole train is inside"
    )

    return state
end

runTest(
    "startup clear is EMPTY",
    function()
        local controller =
            newController()

        local state =
            clearInputs(
                controller
            )

        assertEqual(
            state.state,
            "EMPTY"
        )

        assertFalse(
            state.occupied
        )

        assertTrue(
            controller.isClear()
        )

        assertFalse(
            controller.wantsRelease()
        )
    end
)

runTest(
    "normal arrival reaches BERTHED",
    function()
        local controller =
            newController()

        local state =
            arriveAndBerth(
                controller,
                "TRAIN-001"
            )

        assertEqual(
            state.state,
            "BERTHED"
        )

        assertTrue(
            state.occupied
        )

        assertEqual(
            state.trainId,
            "TRAIN-001"
        )

        assertFalse(
            controller.wantsRelease(),
            "A berthed train must remain held until departure is authorised"
        )
    end
)

runTest(
    "departure release and D3 clearance returns EMPTY",
    function()
        local controller =
            newController()

        arriveAndBerth(
            controller,
            "TRAIN-002"
        )

        local ok, reason =
            controller.requestDeparture(
                "TRAIN-002"
            )

        assertTrue(
            ok,
            reason
        )

        local state =
            controller.getState()

        assertEqual(
            state.state,
            "RELEASED"
        )

        assertTrue(
            controller.wantsRelease(),
            "H1 should request power after departure authorisation"
        )

        state =
            controller.update({
                d1 = false,
                d2 = false,
                d3 = true
            })

        assertEqual(
            state.state,
            "DEPARTING"
        )

        assertFalse(
            controller.wantsRelease(),
            "H1 should return to HOLD once the train reaches D3"
        )

        state =
            controller.update({
                d1 = false,
                d2 = false,
                d3 = false
            })

        assertEqual(
            state.state,
            "EMPTY"
        )

        assertFalse(
            state.occupied
        )

        assertEqual(
            state.trainId,
            nil
        )

        assertTrue(
            controller.isClear()
        )
    end
)

runTest(
    "D2 clearing does not clear a departing platform",
    function()
        local controller =
            newController()

        arriveAndBerth(
            controller
        )

        local ok =
            controller.requestDeparture()

        assertTrue(ok)

        local state =
            controller.update({
                d1 = false,
                d2 = false,
                d3 = false
            })

        assertEqual(
            state.state,
            "RELEASED",
            "D2 clearing alone must not clear the platform"
        )

        assertTrue(
            state.occupied
        )
    end
)

runTest(
    "requestDeparture refuses non-BERTHED state",
    function()
        local controller =
            newController()

        clearInputs(
            controller
        )

        local ok, reason =
            controller.requestDeparture()

        assertFalse(ok)

        assertContains(
            reason,
            "BERTHED"
        )

        assertFalse(
            controller.wantsRelease()
        )
    end
)

runTest(
    "cancel departure restores BERTHED hold",
    function()
        local controller =
            newController()

        arriveAndBerth(
            controller
        )

        local ok =
            controller.requestDeparture()

        assertTrue(ok)

        assertTrue(
            controller.wantsRelease()
        )

        ok =
            controller.cancelDeparture()

        assertTrue(ok)

        local state =
            controller.getState()

        assertEqual(
            state.state,
            "BERTHED"
        )

        assertFalse(
            controller.wantsRelease()
        )
    end
)

runTest(
    "manual hold restores BERTHED before D3",
    function()
        local controller =
            newController()

        arriveAndBerth(
            controller
        )

        assertTrue(
            controller.requestDeparture()
        )

        assertTrue(
            controller.hold()
        )

        local state =
            controller.getState()

        assertEqual(
            state.state,
            "BERTHED"
        )

        assertFalse(
            controller.wantsRelease()
        )
    end
)

runTest(
    "D2 without D1 creates fail-safe fault",
    function()
        local controller =
            newController()

        clearInputs(
            controller
        )

        local state =
            controller.update({
                d1 = false,
                d2 = true,
                d3 = false
            })

        assertEqual(
            state.state,
            "FAULT"
        )

        assertTrue(
            controller.isFaulted()
        )

        assertFalse(
            controller.wantsRelease()
        )

        assertEqual(
            state.fault.code,
            "D2_WITHOUT_APPROACH"
        )
    end
)

runTest(
    "D3 while EMPTY creates fail-safe fault",
    function()
        local controller =
            newController()

        clearInputs(
            controller
        )

        local state =
            controller.update({
                d1 = false,
                d2 = false,
                d3 = true
            })

        assertEqual(
            state.state,
            "FAULT"
        )

        assertEqual(
            state.fault.code,
            "D3_WITHOUT_TRAIN"
        )

        assertFalse(
            controller.wantsRelease()
        )
    end
)

runTest(
    "startup with active detector requires resync",
    function()
        local controller =
            newController()

        local state =
            controller.update({
                d1 = true,
                d2 = false,
                d3 = false
            })

        assertEqual(
            state.state,
            "FAULT"
        )

        assertEqual(
            state.fault.code,
            "STARTUP_SENSOR_ACTIVE"
        )

        assertFalse(
            controller.wantsRelease()
        )
    end
)

runTest(
    "fault cannot clear while detector remains active",
    function()
        local controller =
            newController()

        controller.update({
            d1 = true,
            d2 = false,
            d3 = false
        })

        local ok, reason =
            controller.clearFault()

        assertFalse(ok)

        assertContains(
            reason,
            "detector"
        )

        assertTrue(
            controller.isFaulted()
        )
    end
)

runTest(
    "fault clears after all detectors become clear",
    function()
        local controller =
            newController()

        controller.update({
            d1 = true,
            d2 = false,
            d3 = false
        })

        controller.update({
            d1 = false,
            d2 = false,
            d3 = false
        })

        local ok, reason =
            controller.clearFault()

        assertTrue(
            ok,
            reason
        )

        local state =
            controller.getState()

        assertEqual(
            state.state,
            "EMPTY"
        )

        assertFalse(
            controller.isFaulted()
        )

        assertTrue(
            controller.isClear()
        )
    end
)

runTest(
    "train assignment rejects a different train",
    function()
        local controller =
            newController()

        clearInputs(
            controller
        )

        local ok, reason =
            controller.assignTrain(
                "TRAIN-A"
            )

        assertTrue(
            ok,
            reason
        )

        ok, reason =
            controller.assignTrain(
                "TRAIN-B"
            )

        assertFalse(ok)

        assertContains(
            reason,
            "TRAIN-A"
        )

        local state =
            controller.getState()

        assertEqual(
            state.trainId,
            "TRAIN-A"
        )
    end
)

runTest(
    "departure refuses wrong assigned train",
    function()
        local controller =
            newController()

        arriveAndBerth(
            controller,
            "TRAIN-A"
        )

        local ok, reason =
            controller.requestDeparture(
                "TRAIN-B"
            )

        assertFalse(ok)

        assertContains(
            reason,
            "does not match"
        )

        assertFalse(
            controller.wantsRelease()
        )

        assertEqual(
            controller.getState().state,
            "BERTHED"
        )
    end
)

runTest(
    "force reset can resynchronise a physically checked berth",
    function()
        local controller =
            newController()

        controller.update({
            d1 = true,
            d2 = false,
            d3 = false
        })

        local ok, reason =
            controller.forceReset(
                "TRAIN-RESYNC",
                "BERTHED"
            )

        assertTrue(
            ok,
            reason
        )

        local state =
            controller.getState()

        assertEqual(
            state.state,
            "BERTHED"
        )

        assertTrue(
            state.occupied
        )

        assertEqual(
            state.trainId,
            "TRAIN-RESYNC"
        )

        assertFalse(
            controller.wantsRelease()
        )
    end
)

runTest(
    "stop always leaves release request off",
    function()
        local controller =
            newController()

        arriveAndBerth(
            controller
        )

        assertTrue(
            controller.requestDeparture()
        )

        assertTrue(
            controller.wantsRelease()
        )

        controller.stop()

        assertFalse(
            controller.wantsRelease()
        )
    end
)

print("")
print(
    "Platform controller tests complete"
)

print(
    "Passed: "
    .. tostring(passed)
)

print(
    "Failed: "
    .. tostring(failed)
)

if failed > 0 then
    error(
        tostring(failed)
        .. " platform controller test(s) failed",
        0
    )
end

return true