-- MCNet station controller tests
-- Version 0.9.2
--
-- Run from the MCNet root:
--
--   tests/trains/station_controller_test.lua
--
-- These tests mock bundled redstone I/O. No real detector, bundled cable,
-- monitor or locking track is required.
--
-- Main safety goal:
-- prove that several platform controllers can share one bundled output cable
-- without overwriting each other's H1 release colours.

local realRedstone =
    redstone

local platformController =
    dofile(
        "services/trains/platform_controller.lua"
    )

local stationControllerModule =
    dofile(
        "services/trains/station_controller.lua"
    )

local inputBySide = {}
local outputBySide = {}
local outputHistory = {}

redstone = {
    getBundledInput = function(side)
        return inputBySide[side]
            or 0
    end,

    setBundledOutput = function(
        side,
        value
    )
        outputBySide[side] =
            value

        outputHistory[
            #outputHistory + 1
        ] = {
            side = side,
            value = value
        }
    end
}

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

local function colourHas(
    value,
    colour
)
    if colors
        and colors.test then

        return colors.test(
            value,
            colour
        )
    end

    if bit
        and bit.band then

        return bit.band(
            value,
            colour
        ) ~= 0
    end

    fail(
        "No bundled colour test function is available"
    )
end

local function combine(...)
    local values = {
        ...
    }

    local result = 0

    for _, colour in ipairs(
        values
    ) do
        if colors
            and colors.combine then

            result =
                colors.combine(
                    result,
                    colour
                )
        elseif bit
            and bit.bor then

            result =
                bit.bor(
                    result,
                    colour
                )
        else
            result =
                result + colour
        end
    end

    return result
end

local function resetMock()
    inputBySide = {
        left = 0,
        back = 0
    }

    outputBySide = {
        right = 999999
    }

    outputHistory = {}
end

local function makeStationConfig()
    return {
        stationId = "TEST_STATION",
        mapId = "CENTRAL",
        name = "Test Station",
        status = "OPEN",

        platforms = {
            {
                id = "P1",
                name = "Platform 1",
                enabled = true
            },

            {
                id = "P2",
                name = "Platform 2",
                enabled = true
            }
        }
    }
end

local function makeIOConfig()
    return {
        format = 1,

        pollInterval = 0.1,

        outputSide = "right",

        platforms = {
            P1 = {
                inputSide = "left",

                d1 = colors.white,
                d2 = colors.orange,
                d3 = colors.magenta,

                h1 = colors.white
            },

            P2 = {
                inputSide = "left",

                d1 = colors.lightBlue,
                d2 = colors.yellow,
                d3 = colors.lime,

                h1 = colors.orange
            }
        }
    }
end

local function newStation()
    resetMock()

    local controller,
        reason =
        stationControllerModule.new({
            platformControllerModule =
                platformController,

            stationConfig =
                makeStationConfig(),

            ioConfig =
                makeIOConfig()
        })

    assertTrue(
        controller ~= nil,
        reason
    )

    return controller
end

local function setInput(
    side,
    value
)
    inputBySide[side] =
        value
end

local function getOutput()
    return outputBySide.right
        or 0
end

local function updateClear(
    controller
)
    setInput(
        "left",
        0
    )

    return controller.update()
end

local function arriveP1(
    controller
)
    updateClear(
        controller
    )

    setInput(
        "left",
        colors.white
    )

    controller.update()

    setInput(
        "left",
        combine(
            colors.white,
            colors.orange
        )
    )

    controller.update()

    setInput(
        "left",
        colors.orange
    )

    controller.update()

    return controller.getPlatformState(
        "P1"
    )
end

local function arriveP2(
    controller,
    preserveP1D2
)
    local base =
        preserveP1D2
        and colors.orange
        or 0

    setInput(
        "left",
        combine(
            base,
            colors.lightBlue
        )
    )

    controller.update()

    setInput(
        "left",
        combine(
            base,
            colors.lightBlue,
            colors.yellow
        )
    )

    controller.update()

    setInput(
        "left",
        combine(
            base,
            colors.yellow
        )
    )

    controller.update()

    return controller.getPlatformState(
        "P2"
    )
end

local function berthBoth(
    controller
)
    updateClear(
        controller
    )

    -- P1 approach.
    setInput(
        "left",
        colors.white
    )

    controller.update()

    -- P1 berth.
    setInput(
        "left",
        combine(
            colors.white,
            colors.orange
        )
    )

    controller.update()

    -- P1 rear clears D1; P1 is now BERTHED.
    setInput(
        "left",
        colors.orange
    )

    controller.update()

    -- P2 approach while P1 remains on its berth detector.
    setInput(
        "left",
        combine(
            colors.orange,
            colors.lightBlue
        )
    )

    controller.update()

    -- P2 berth.
    setInput(
        "left",
        combine(
            colors.orange,
            colors.lightBlue,
            colors.yellow
        )
    )

    controller.update()

    -- P2 rear clears D1; both trains are berthed.
    setInput(
        "left",
        combine(
            colors.orange,
            colors.yellow
        )
    )

    controller.update()

    assertEqual(
        controller.getPlatformState(
            "P1"
        ).state,
        "BERTHED"
    )

    assertEqual(
        controller.getPlatformState(
            "P2"
        ).state,
        "BERTHED"
    )
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

runTest(
    "construction immediately writes fail-safe HOLD",
    function()
        local controller =
            newStation()

        assertEqual(
            getOutput(),
            0,
            "Station construction must clear all H1 release outputs"
        )

        assertTrue(
            #outputHistory >= 1
        )

        assertEqual(
            outputHistory[1].value,
            0
        )

        controller.stop()

        assertEqual(
            getOutput(),
            0
        )
    end
)

runTest(
    "clear startup leaves both platforms EMPTY",
    function()
        local controller =
            newStation()

        controller.update()

        assertEqual(
            controller.getPlatformState(
                "P1"
            ).state,
            "EMPTY"
        )

        assertEqual(
            controller.getPlatformState(
                "P2"
            ).state,
            "EMPTY"
        )

        assertEqual(
            getOutput(),
            0
        )
    end
)

runTest(
    "P1 normal arrival reaches BERTHED",
    function()
        local controller =
            newStation()

        local state =
            arriveP1(
                controller
            )

        assertEqual(
            state.state,
            "BERTHED"
        )

        assertTrue(
            state.occupied
        )

        assertEqual(
            getOutput(),
            0,
            "A berthed train must remain held"
        )
    end
)

runTest(
    "releasing P1 powers only P1 H1 colour",
    function()
        local controller =
            newStation()

        arriveP1(
            controller
        )

        local ok, reason =
            controller.requestDeparture(
                "P1"
            )

        assertTrue(
            ok,
            reason
        )

        local output =
            getOutput()

        assertTrue(
            colourHas(
                output,
                colors.white
            )
        )

        assertFalse(
            colourHas(
                output,
                colors.orange
            ),
            "P2 release colour must remain off"
        )
    end
)

runTest(
    "P1 and P2 releases combine on one bundled output",
    function()
        local controller =
            newStation()

        berthBoth(
            controller
        )

        local ok, reason =
            controller.requestDeparture(
                "P1"
            )

        assertTrue(
            ok,
            reason
        )

        ok, reason =
            controller.requestDeparture(
                "P2"
            )

        assertTrue(
            ok,
            reason
        )

        local output =
            getOutput()

        assertTrue(
            colourHas(
                output,
                colors.white
            ),
            "P1 H1 colour should be present"
        )

        assertTrue(
            colourHas(
                output,
                colors.orange
            ),
            "P2 H1 colour should be present"
        )

        assertEqual(
            output,
            combine(
                colors.white,
                colors.orange
            ),
            "No unrelated H1 colours should be written"
        )
    end
)

runTest(
    "holding P1 does not cancel P2 release",
    function()
        local controller =
            newStation()

        berthBoth(
            controller
        )

        assertTrue(
            controller.requestDeparture(
                "P1"
            )
        )

        assertTrue(
            controller.requestDeparture(
                "P2"
            )
        )

        local ok, reason =
            controller.holdPlatform(
                "P1"
            )

        assertTrue(
            ok,
            reason
        )

        local output =
            getOutput()

        assertFalse(
            colourHas(
                output,
                colors.white
            ),
            "P1 H1 should be HOLD"
        )

        assertTrue(
            colourHas(
                output,
                colors.orange
            ),
            "P2 H1 must remain RELEASED"
        )
    end
)

runTest(
    "P1 reaching D3 removes only P1 release colour",
    function()
        local controller =
            newStation()

        berthBoth(
            controller
        )

        assertTrue(
            controller.requestDeparture(
                "P1"
            )
        )

        assertTrue(
            controller.requestDeparture(
                "P2"
            )
        )

        -- P1 D2 clears and P1 D3 becomes active.
        -- P2 remains berthed on its D2 detector.
        setInput(
            "left",
            combine(
                colors.yellow,
                colors.magenta
            )
        )

        controller.update()

        assertEqual(
            controller.getPlatformState(
                "P1"
            ).state,
            "DEPARTING"
        )

        local output =
            getOutput()

        assertFalse(
            colourHas(
                output,
                colors.white
            ),
            "P1 release should be removed once P1 reaches D3"
        )

        assertTrue(
            colourHas(
                output,
                colors.orange
            ),
            "P2 release must not be overwritten by P1"
        )
    end
)

runTest(
    "D3 OFF clears P1 while P2 remains controlled",
    function()
        local controller =
            newStation()

        berthBoth(
            controller
        )

        assertTrue(
            controller.requestDeparture(
                "P1"
            )
        )

        assertTrue(
            controller.requestDeparture(
                "P2"
            )
        )

        setInput(
            "left",
            combine(
                colors.yellow,
                colors.magenta
            )
        )

        controller.update()

        -- P1 D3 now clears; P2 remains on D2.
        setInput(
            "left",
            colors.yellow
        )

        controller.update()

        local p1 =
            controller.getPlatformState(
                "P1"
            )

        local p2 =
            controller.getPlatformState(
                "P2"
            )

        assertEqual(
            p1.state,
            "EMPTY"
        )

        assertEqual(
            p2.state,
            "RELEASED"
        )

        assertFalse(
            colourHas(
                getOutput(),
                colors.white
            )
        )

        assertTrue(
            colourHas(
                getOutput(),
                colors.orange
            )
        )
    end
)

runTest(
    "emergency hold forces every H1 output off",
    function()
        local controller =
            newStation()

        berthBoth(
            controller
        )

        assertTrue(
            controller.requestDeparture(
                "P1"
            )
        )

        assertTrue(
            controller.requestDeparture(
                "P2"
            )
        )

        assertEqual(
            getOutput(),
            combine(
                colors.white,
                colors.orange
            )
        )

        controller.setEmergencyHold(
            true,
            "Test emergency"
        )

        assertTrue(
            controller.isEmergencyHold()
        )

        assertEqual(
            getOutput(),
            0
        )

        local ok, reason =
            controller.requestDeparture(
                "P1"
            )

        assertFalse(ok)

        assertContains(
            reason,
            "emergency hold"
        )
    end
)

runTest(
    "releasing emergency hold restores valid release requests",
    function()
        local controller =
            newStation()

        berthBoth(
            controller
        )

        assertTrue(
            controller.requestDeparture(
                "P1"
            )
        )

        assertTrue(
            controller.requestDeparture(
                "P2"
            )
        )

        controller.setEmergencyHold(
            true
        )

        assertEqual(
            getOutput(),
            0
        )

        controller.setEmergencyHold(
            false
        )

        assertFalse(
            controller.isEmergencyHold()
        )

        assertEqual(
            getOutput(),
            combine(
                colors.white,
                colors.orange
            )
        )
    end
)

runTest(
    "station fault forces fail-safe HOLD",
    function()
        local controller =
            newStation()

        arriveP1(
            controller
        )

        assertTrue(
            controller.requestDeparture(
                "P1"
            )
        )

        assertTrue(
            colourHas(
                getOutput(),
                colors.white
            )
        )

        controller.setStationFault(
            "TEST_FAULT",
            "Testing station fail-safe"
        )

        assertEqual(
            getOutput(),
            0
        )

        local ok, reason =
            controller.requestDeparture(
                "P1"
            )

        assertFalse(ok)

        assertContains(
            reason,
            "faulted"
        )
    end
)

runTest(
    "clearing station fault restores valid platform command",
    function()
        local controller =
            newStation()

        arriveP1(
            controller
        )

        assertTrue(
            controller.requestDeparture(
                "P1"
            )
        )

        controller.setStationFault(
            "TEST",
            "Test"
        )

        assertEqual(
            getOutput(),
            0
        )

        controller.clearStationFault()

        assertTrue(
            colourHas(
                getOutput(),
                colors.white
            ),
            "Existing safe release request should be recombined after station fault clears"
        )
    end
)

runTest(
    "startup active detector faults only affected platform",
    function()
        resetMock()

        setInput(
            "left",
            colors.white
        )

        local controller,
            reason =
            stationControllerModule.new({
                platformControllerModule =
                    platformController,

                stationConfig =
                    makeStationConfig(),

                ioConfig =
                    makeIOConfig()
            })

        assertTrue(
            controller ~= nil,
            reason
        )

        controller.update()

        local p1 =
            controller.getPlatformState(
                "P1"
            )

        local p2 =
            controller.getPlatformState(
                "P2"
            )

        assertEqual(
            p1.state,
            "FAULT"
        )

        assertEqual(
            p1.fault.code,
            "STARTUP_SENSOR_ACTIVE"
        )

        assertEqual(
            p2.state,
            "EMPTY"
        )

        assertEqual(
            getOutput(),
            0
        )
    end
)

runTest(
    "platform fault clears only after its detectors are clear",
    function()
        resetMock()

        setInput(
            "left",
            colors.white
        )

        local controller,
            reason =
            stationControllerModule.new({
                platformControllerModule =
                    platformController,

                stationConfig =
                    makeStationConfig(),

                ioConfig =
                    makeIOConfig()
            })

        assertTrue(
            controller ~= nil,
            reason
        )

        controller.update()

        local ok, clearReason =
            controller.clearPlatformFault(
                "P1"
            )

        assertFalse(ok)

        assertContains(
            clearReason,
            "detector"
        )

        setInput(
            "left",
            0
        )

        controller.update()

        ok, clearReason =
            controller.clearPlatformFault(
                "P1"
            )

        assertTrue(
            ok,
            clearReason
        )

        assertEqual(
            controller.getPlatformState(
                "P1"
            ).state,
            "EMPTY"
        )
    end
)

runTest(
    "unknown platform commands are rejected",
    function()
        local controller =
            newStation()

        controller.update()

        local ok, reason =
            controller.requestDeparture(
                "P99"
            )

        assertFalse(ok)

        assertContains(
            reason,
            "Unknown"
        )

        ok, reason =
            controller.holdPlatform(
                "P99"
            )

        assertFalse(ok)

        assertContains(
            reason,
            "Unknown"
        )
    end
)

runTest(
    "snapshot contains both platform states and station safety state",
    function()
        local controller =
            newStation()

        controller.update()

        local snapshot =
            controller.getSnapshot()

        assertEqual(
            snapshot.stationId,
            "TEST_STATION"
        )

        assertEqual(
            snapshot.mapId,
            "CENTRAL"
        )

        assertFalse(
            snapshot.emergencyHold
        )

        assertTrue(
            type(
                snapshot.platforms.P1
            ) == "table"
        )

        assertTrue(
            type(
                snapshot.platforms.P2
            ) == "table"
        )

        assertEqual(
            snapshot.platforms.P1.state.state,
            "EMPTY"
        )

        assertEqual(
            snapshot.platforms.P2.state.state,
            "EMPTY"
        )

        assertEqual(
            snapshot.outputSide,
            "right"
        )
    end
)

runTest(
    "stop always clears combined bundled output",
    function()
        local controller =
            newStation()

        arriveP1(
            controller
        )

        assertTrue(
            controller.requestDeparture(
                "P1"
            )
        )

        assertTrue(
            colourHas(
                getOutput(),
                colors.white
            )
        )

        controller.stop()

        assertEqual(
            getOutput(),
            0
        )
    end
)

redstone =
    realRedstone

print("")
print(
    "Station controller tests complete"
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
        .. " station controller test(s) failed",
        0
    )
end

return true