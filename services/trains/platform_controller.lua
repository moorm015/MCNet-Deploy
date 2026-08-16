-- MCNet local railway platform state controller
-- Version 0.9.2
--
-- Controls the LOGICAL state of ONE platform road.
--
-- IMPORTANT:
-- This module does NOT read redstone and does NOT write bundled outputs.
-- A station-level controller owns the physical bundled cables and calls:
--
--     platform.update({
--         d1 = true/false,
--         d2 = true/false,
--         d3 = true/false
--     })
--
-- The station controller then asks:
--
--     platform.wantsRelease()
--
-- and combines the release requests from every platform into ONE bundled
-- output value before writing the cable.
--
-- This avoids multiple platform controllers overwriting each other's
-- bundled-output colours.
--
-- Standard MCNet platform hardware:
--
--   D1 = approach detector
--   D2 = berth detector
--   H1 = locking track
--   D3 = departure detector
--
-- Tested physical sequence:
--
--   EMPTY
--     D1 ON
--   APPROACHING
--     D2 ON
--   ENTERING
--     D1 OFF
--   BERTHED
--     H1 remains HOLD until departure is authorised
--   RELEASED
--     D3 ON
--   DEPARTING
--     D3 OFF
--   EMPTY
--
-- H1 behaviour:
--
--   false = unpowered = HOLD
--   true  = powered   = RELEASE
--
-- FAIL SAFE:
--   Any fault or uncertain state requests HOLD.
--
-- D3 ON -> OFF is the normal proof that the entire consist has cleared
-- the platform exit. D2 clearing by itself does NOT clear the platform.

local module = {}

local VALID_STATES = {
    EMPTY = true,
    APPROACHING = true,
    ENTERING = true,
    BERTHED = true,
    RELEASED = true,
    DEPARTING = true,
    FAULT = true
}

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local result = {}
    seen[value] = result

    for key, item in pairs(value) do
        result[deepCopy(key, seen)] =
            deepCopy(item, seen)
    end

    return result
end

local function cleanIdentifier(value)
    value =
        string.upper(
            tostring(value or "")
        )

    value =
        string.gsub(
            value,
            "%s+",
            "-"
        )

    value =
        string.gsub(
            value,
            "[^A-Z0-9%-_]",
            ""
        )

    return value
end

local function nowClock()
    if os.clock then
        return os.clock()
    end

    return 0
end

local function bool(value)
    return value == true
end

function module.defaultConfig()
    return {
        id = "P1",

        name = "Platform 1",

        -- Optional safety timeouts.
        --
        -- Leave at zero until the real railway has been measured.
        approachTimeout = 0,

        departureTimeout = 0
    }
end

function module.normaliseConfig(config)
    local default =
        module.defaultConfig()

    config =
        type(config) == "table"
        and config
        or {}

    local id =
        cleanIdentifier(
            config.id
            or config.platformId
            or default.id
        )

    if id == "" then
        id = default.id
    end

    return {
        id = id,

        name =
            tostring(
                config.name
                or default.name
            ),

        approachTimeout =
            math.max(
                0,
                tonumber(
                    config.approachTimeout
                )
                or 0
            ),

        departureTimeout =
            math.max(
                0,
                tonumber(
                    config.departureTimeout
                )
                or 0
            )
    }
end

function module.new(config)
    config =
        module.normaliseConfig(
            config
        )

    local controller = {}

    local state = {
        platformId =
            config.id,

        name =
            config.name,

        state =
            "EMPTY",

        occupied =
            false,

        trainId =
            nil,

        d1 = false,
        d2 = false,
        d3 = false,

        previousD1 = false,
        previousD2 = false,
        previousD3 = false,

        releaseRequested =
            false,

        desiredRelease =
            false,

        sawApproach =
            false,

        sawBerth =
            false,

        sawExit =
            false,

        firstUpdate =
            true,

        lastChange =
            nowClock(),

        approachStarted =
            nil,

        departureStarted =
            nil,

        fault =
            nil
    }

    local events = {}

    local function queueEvent(
        eventType,
        details
    )
        local event = {
            type =
                tostring(
                    eventType
                    or "UNKNOWN"
                ),

            platformId =
                state.platformId,

            trainId =
                state.trainId,

            time =
                nowClock()
        }

        if type(details)
            == "table" then

            for key, value in pairs(
                details
            ) do
                event[key] =
                    deepCopy(value)
            end
        end

        events[#events + 1] =
            event
    end

    local function setState(
        newState,
        reason
    )
        newState =
            string.upper(
                tostring(
                    newState
                    or "FAULT"
                )
            )

        if not VALID_STATES[
            newState
        ] then
            newState =
                "FAULT"
        end

        if state.state
            ~= newState then

            local previous =
                state.state

            state.state =
                newState

            state.lastChange =
                nowClock()

            queueEvent(
                "STATE_CHANGED",
                {
                    previous =
                        previous,

                    current =
                        newState,

                    reason =
                        reason
                }
            )
        end
    end

    local function hold()
        state.releaseRequested =
            false

        state.desiredRelease =
            false
    end

    local function setFault(
        code,
        message
    )
        hold()

        state.fault = {
            code =
                tostring(
                    code
                    or "PLATFORM_FAULT"
                ),

            message =
                tostring(
                    message
                    or "Unknown platform fault"
                ),

            time =
                nowClock()
        }

        setState(
            "FAULT",
            state.fault.message
        )

        queueEvent(
            "FAULT",
            state.fault
        )
    end

    local function rising(
        current,
        previous
    )
        return current
            and not previous
    end

    local function falling(
        current,
        previous
    )
        return not current
            and previous
    end

    local function updateSensors(
        inputs
    )
        inputs =
            type(inputs) == "table"
            and inputs
            or {}

        state.previousD1 =
            state.d1

        state.previousD2 =
            state.d2

        state.previousD3 =
            state.d3

        state.d1 =
            bool(
                inputs.d1
                or inputs.approach
            )

        state.d2 =
            bool(
                inputs.d2
                or inputs.berth
            )

        state.d3 =
            bool(
                inputs.d3
                or inputs.exit
            )
    end

    local function checkFirstUpdate()
        if not state.firstUpdate then
            return true
        end

        state.firstUpdate =
            false

        -- A station computer booting while any detector is already active
        -- cannot safely infer where the train came from or which transition
        -- has already happened.
        --
        -- Fail safe and require a maintenance resynchronisation.
        if state.d1
            or state.d2
            or state.d3 then

            setFault(
                "STARTUP_SENSOR_ACTIVE",
                "Platform detector active at controller startup; maintenance resynchronisation required"
            )

            return false
        end

        return true
    end

    local function processEdges()
        if state.state == "FAULT" then
            return
        end

        local d1Rise =
            rising(
                state.d1,
                state.previousD1
            )

        local d1Fall =
            falling(
                state.d1,
                state.previousD1
            )

        local d2Rise =
            rising(
                state.d2,
                state.previousD2
            )

        local d2Fall =
            falling(
                state.d2,
                state.previousD2
            )

        local d3Rise =
            rising(
                state.d3,
                state.previousD3
            )

        local d3Fall =
            falling(
                state.d3,
                state.previousD3
            )

        -- D1 ON: train enters platform approach.
        if d1Rise then
            if state.state
                == "EMPTY" then

                state.occupied =
                    true

                state.sawApproach =
                    true

                state.approachStarted =
                    nowClock()

                setState(
                    "APPROACHING",
                    "D1 approach detector active"
                )

                queueEvent(
                    "APPROACH_ENTERED"
                )
            else
                setFault(
                    "UNEXPECTED_D1",
                    "D1 activated while platform was not empty"
                )

                return
            end
        end

        -- D2 ON: train reaches berth detector.
        if d2Rise then
            if state.state == "APPROACHING"
                or state.state == "ENTERING" then

                state.sawBerth =
                    true

                setState(
                    "ENTERING",
                    "D2 berth detector active"
                )

                queueEvent(
                    "BERTH_DETECTED"
                )
            elseif state.state == "EMPTY" then
                setFault(
                    "D2_WITHOUT_APPROACH",
                    "D2 activated before a valid D1 approach"
                )

                return
            elseif state.state ~= "BERTHED"
                and state.state ~= "RELEASED"
                and state.state ~= "DEPARTING" then

                setFault(
                    "UNEXPECTED_D2",
                    "D2 activated in an unexpected platform state"
                )

                return
            end
        end

        -- D1 OFF after D2:
        -- rear of train has cleared the approach detector, so the whole
        -- consist is inside the platform.
        if d1Fall then
            if state.sawApproach
                and state.sawBerth
                and (
                    state.state == "ENTERING"
                    or state.state == "APPROACHING"
                ) then

                hold()

                setState(
                    "BERTHED",
                    "D1 cleared after D2; whole consist is inside platform"
                )

                queueEvent(
                    "TRAIN_BERTHED"
                )
            elseif state.sawApproach
                and not state.sawBerth then

                setFault(
                    "APPROACH_CLEARED_WITHOUT_BERTH",
                    "D1 cleared before D2 detected the arriving train"
                )

                return
            end
        end

        -- D3 ON: departure reaches exit detector.
        if d3Rise then
            if state.state == "RELEASED"
                or state.state == "BERTHED" then

                state.sawExit =
                    true

                state.departureStarted =
                    state.departureStarted
                    or nowClock()

                setState(
                    "DEPARTING",
                    "D3 departure detector active"
                )

                queueEvent(
                    "DEPARTURE_ENTERED"
                )

                -- Once the train reaches D3 the locking track no longer
                -- needs power. Return immediately to fail-safe HOLD.
                hold()

                queueEvent(
                    "HOLD_RESTORED"
                )
            elseif state.state == "EMPTY" then
                setFault(
                    "D3_WITHOUT_TRAIN",
                    "D3 activated while platform was empty"
                )

                return
            elseif state.state ~= "DEPARTING" then
                setFault(
                    "UNEXPECTED_D3",
                    "D3 activated in an unexpected platform state"
                )

                return
            end
        end

        -- D2 may clear during departure. This is diagnostic only.
        if d2Fall
            and state.state == "DEPARTING" then

            queueEvent(
                "BERTH_CLEARED"
            )
        end

        -- D3 OFF after D3 ON:
        -- whole consist has cleared the platform.
        if d3Fall then
            if state.sawExit
                and state.state == "DEPARTING" then

                hold()

                queueEvent(
                    "TRAIN_CLEARED"
                )

                state.occupied =
                    false

                state.trainId =
                    nil

                state.sawApproach =
                    false

                state.sawBerth =
                    false

                state.sawExit =
                    false

                state.approachStarted =
                    nil

                state.departureStarted =
                    nil

                state.fault =
                    nil

                setState(
                    "EMPTY",
                    "D3 cleared after departure; whole consist has left platform"
                )
            elseif state.state ~= "EMPTY" then
                setFault(
                    "D3_CLEARED_UNEXPECTEDLY",
                    "D3 cleared without a recognised departure sequence"
                )

                return
            end
        end
    end

    local function processTimeouts()
        if state.state == "FAULT" then
            return
        end

        local now =
            nowClock()

        if config.approachTimeout > 0
            and state.approachStarted
            and (
                state.state == "APPROACHING"
                or state.state == "ENTERING"
            )
            and (
                now
                - state.approachStarted
            ) > config.approachTimeout then

            setFault(
                "APPROACH_TIMEOUT",
                "Train did not complete the platform approach within the configured timeout"
            )

            return
        end

        if config.departureTimeout > 0
            and state.departureStarted
            and (
                state.state == "RELEASED"
                or state.state == "DEPARTING"
            )
            and (
                now
                - state.departureStarted
            ) > config.departureTimeout then

            setFault(
                "DEPARTURE_TIMEOUT",
                "Train did not clear the platform within the configured timeout"
            )

            return
        end
    end

    function controller.update(inputs)
        events = {}

        updateSensors(
            inputs
        )

        if checkFirstUpdate() then
            processEdges()
            processTimeouts()
        end

        return deepCopy(state),
            deepCopy(events)
    end

    function controller.getState()
        return deepCopy(state)
    end

    function controller.getConfig()
        return deepCopy(config)
    end

    function controller.getEvents()
        return deepCopy(events)
    end

    function controller.wantsRelease()
        if state.state == "FAULT" then
            return false
        end

        return state.desiredRelease
            == true
    end

    function controller.assignTrain(trainId)
        trainId =
            cleanIdentifier(
                trainId
            )

        if trainId == "" then
            return false,
                "Train ID is required"
        end

        if state.trainId
            and state.trainId
                ~= trainId then

            return false,
                "Platform already has train "
                .. tostring(
                    state.trainId
                )
        end

        state.trainId =
            trainId

        queueEvent(
            "TRAIN_ASSIGNED",
            {
                trainId =
                    trainId
            }
        )

        return true
    end

    function controller.requestDeparture(trainId)
        if state.state
            ~= "BERTHED" then

            return false,
                "Platform is not in BERTHED state"
        end

        if trainId
            and tostring(trainId)
                ~= "" then

            local requested =
                cleanIdentifier(
                    trainId
                )

            if state.trainId
                and state.trainId
                    ~= requested then

                return false,
                    "Train ID does not match the train assigned to this platform"
            end

            if not state.trainId then
                state.trainId =
                    requested
            end
        end

        state.releaseRequested =
            true

        state.desiredRelease =
            true

        state.departureStarted =
            nowClock()

        setState(
            "RELEASED",
            "Departure authorised"
        )

        queueEvent(
            "TRAIN_RELEASED"
        )

        return true
    end

    function controller.cancelDeparture()
        if state.state == "FAULT" then
            hold()

            return false,
                "Platform is faulted"
        end

        hold()

        if state.state == "RELEASED"
            and not state.d3 then

            setState(
                "BERTHED",
                "Departure authorisation cancelled before D3"
            )
        end

        queueEvent(
            "DEPARTURE_CANCELLED"
        )

        return true
    end

    function controller.hold()
        hold()

        if state.state == "RELEASED"
            and not state.d3 then

            setState(
                "BERTHED",
                "Manual hold restored before D3"
            )
        end

        return true
    end

    function controller.isClear()
        return state.state == "EMPTY"
            and not state.occupied
            and not state.d1
            and not state.d2
            and not state.d3
    end

    function controller.isFaulted()
        return state.state == "FAULT"
    end

    function controller.clearFault()
        if state.state ~= "FAULT" then
            return true
        end

        if state.d1
            or state.d2
            or state.d3 then

            return false,
                "Cannot clear fault while a platform detector is active"
        end

        hold()

        state.occupied =
            false

        state.trainId =
            nil

        state.sawApproach =
            false

        state.sawBerth =
            false

        state.sawExit =
            false

        state.approachStarted =
            nil

        state.departureStarted =
            nil

        state.fault =
            nil

        state.firstUpdate =
            false

        setState(
            "EMPTY",
            "Fault cleared with all detectors clear"
        )

        queueEvent(
            "FAULT_CLEARED"
        )

        return true
    end

    function controller.forceReset(
        trainId,
        newState
    )
        -- Maintenance-only logical resynchronisation.
        --
        -- A human operator must first inspect the physical railway and decide
        -- what MCNet should believe. This function does not prove safety.

        hold()

        newState =
            string.upper(
                tostring(
                    newState
                    or "EMPTY"
                )
            )

        if not VALID_STATES[
            newState
        ]
            or newState == "FAULT" then

            return false,
                "Invalid reset state"
        end

        local cleanedTrain =
            nil

        if trainId
            and tostring(trainId)
                ~= "" then

            cleanedTrain =
                cleanIdentifier(
                    trainId
                )
        end

        state.trainId =
            cleanedTrain

        state.fault =
            nil

        state.firstUpdate =
            false

        state.sawApproach =
            newState ~= "EMPTY"

        state.sawBerth =
            newState == "BERTHED"
            or newState == "RELEASED"
            or newState == "DEPARTING"

        state.sawExit =
            newState == "DEPARTING"

        state.occupied =
            newState ~= "EMPTY"

        state.approachStarted =
            nil

        state.departureStarted =
            nil

        setState(
            newState,
            "Manual maintenance resynchronisation"
        )

        queueEvent(
            "FORCE_RESET",
            {
                newState =
                    newState,

                trainId =
                    state.trainId
            }
        )

        return true
    end

    function controller.stop()
        hold()
    end

    return controller
end

return module