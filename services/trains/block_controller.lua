-- MCNet local railway block state controller
-- Version 0.9.8
--
-- ComputerCraft 1.75 / CraftOS 1.7 compatible.
--
-- Logical controller for ONE directional block between two boundaries.
-- It does not touch redstone directly; a later TRACK controller will own the
-- bundled cables and feed this module:
--
--   previous block
--        |
--     [HOLD]   locking track owned by THIS block entrance
--     [ENTRY]  boundary detector
--        |
--      BLOCK
--        |
--     [HOLD]   locking track owned by NEXT block entrance
--     [EXIT]   boundary detector
--        |
--      next block
--
-- Normal sequence:
--
--   CLEAR -> RESERVED -> RELEASED -> ENTERING -> OCCUPIED -> LEAVING -> CLEAR
--
-- Safety:
--   * unpowered locking track = HOLD
--   * powered locking track = RELEASE
--   * authority is consumed on ENTRY ON; HOLD is restored immediately
--   * ENTRY OFF proves the whole consist entered this block
--   * EXIT OFF, after EXIT ON, proves the whole consist cleared this block
--   * impossible/unknown sequences = FAULT + HOLD
--   * startup with an active detector = FAULT + maintenance resynchronisation

local module = {}

local VALID_STATES = {
    CLEAR = true,
    RESERVED = true,
    RELEASED = true,
    ENTERING = true,
    OCCUPIED = true,
    LEAVING = true,
    FAULT = true
}

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local result = {}
    seen[value] = result

    for key, item in pairs(value) do
        result[copy(key, seen)] = copy(item, seen)
    end

    return result
end

local function cleanId(value)
    value = string.upper(tostring(value or ""))
    value = string.gsub(value, "%s+", "-")
    value = string.gsub(value, "[^A-Z0-9%-_]", "")
    return value
end

local function now()
    return os.clock and os.clock() or 0
end

local function asBool(value)
    return value == true
end

function module.defaultConfig()
    return {
        id = "BLOCK-A1-A2",
        name = "Block A1-A2",

        -- Leave these at zero until physical railway timings are measured.
        releaseTimeout = 0,
        traversalTimeout = 0,
        clearanceTimeout = 0
    }
end

function module.normaliseConfig(config)
    config = type(config) == "table" and config or {}
    local default = module.defaultConfig()
    local id = cleanId(config.id or config.blockId or default.id)

    if id == "" then id = default.id end

    return {
        id = id,
        name = tostring(config.name or default.name),
        releaseTimeout = math.max(0, tonumber(config.releaseTimeout) or 0),
        traversalTimeout = math.max(0, tonumber(config.traversalTimeout) or 0),
        clearanceTimeout = math.max(0, tonumber(config.clearanceTimeout) or 0)
    }
end

function module.new(config)
    config = module.normaliseConfig(config)

    local controller = {}
    local events = {}

    local state = {
        blockId = config.id,
        name = config.name,
        state = "CLEAR",

        occupied = false,
        reserved = false,
        trainId = nil,

        entry = false,
        exit = false,
        previousEntry = false,
        previousExit = false,

        desiredRelease = false,
        firstUpdate = true,

        sawEntry = false,
        sawEntryClear = false,
        sawExit = false,

        reservedAt = nil,
        releasedAt = nil,
        enteredAt = nil,
        fullyEnteredAt = nil,
        exitStartedAt = nil,
        clearedAt = nil,
        lastChange = now(),

        fault = nil
    }

    local function event(eventType, details)
        local item = {
            type = tostring(eventType or "UNKNOWN"),
            blockId = state.blockId,
            trainId = state.trainId,
            time = now()
        }

        if type(details) == "table" then
            for key, value in pairs(details) do
                item[key] = copy(value)
            end
        end

        events[#events + 1] = item
    end

    local function changeState(newState, reason)
        newState = string.upper(tostring(newState or "FAULT"))
        if not VALID_STATES[newState] then newState = "FAULT" end

        if state.state ~= newState then
            local previous = state.state
            state.state = newState
            state.lastChange = now()

            event("STATE_CHANGED", {
                previous = previous,
                current = newState,
                reason = reason
            })
        end
    end

    local function hold()
        state.desiredRelease = false
    end

    local function clearMovement()
        state.sawEntry = false
        state.sawEntryClear = false
        state.sawExit = false
        state.releasedAt = nil
        state.enteredAt = nil
        state.fullyEnteredAt = nil
        state.exitStartedAt = nil
    end

    local function fault(code, message)
        hold()

        state.fault = {
            code = tostring(code or "BLOCK_FAULT"),
            message = tostring(message or "Unknown block fault"),
            time = now()
        }

        -- Any fault makes the block unavailable regardless of detector state.
        state.occupied = true

        changeState("FAULT", state.fault.message)
        event("FAULT", state.fault)
    end

    local function rising(current, previous)
        return current and not previous
    end

    local function falling(current, previous)
        return not current and previous
    end

    local function readInputs(inputs)
        inputs = type(inputs) == "table" and inputs or {}

        state.previousEntry = state.entry
        state.previousExit = state.exit

        state.entry = asBool(inputs.entry or inputs.inbound or inputs.entrance)
        state.exit = asBool(inputs.exit or inputs.outbound)
    end

    local function firstUpdateSafe()
        if not state.firstUpdate then return true end
        state.firstUpdate = false

        if state.entry or state.exit then
            fault(
                "STARTUP_SENSOR_ACTIVE",
                "Block detector active at controller startup; maintenance resynchronisation required"
            )
            return false
        end

        return true
    end

    local function processEdges()
        if state.state == "FAULT" then return end

        local entryRise = rising(state.entry, state.previousEntry)
        local entryFall = falling(state.entry, state.previousEntry)
        local exitRise = rising(state.exit, state.previousExit)
        local exitFall = falling(state.exit, state.previousExit)

        -- Front of train crosses into this block.
        if entryRise then
            if state.state == "RELEASED" then
                state.sawEntry = true
                state.occupied = true
                state.enteredAt = now()

                -- Consume authority immediately: the entrance returns to HOLD.
                hold()

                changeState("ENTERING", "Entrance detector active; train front entered block")
                event("TRAIN_ENTERED")
                event("ENTRY_HOLD_RESTORED")
            elseif state.state == "RESERVED" then
                fault("ENTRY_WHILE_HELD", "Entrance detector activated before entry authority was released")
                return
            elseif state.state == "CLEAR" then
                fault("UNAUTHORISED_ENTRY", "Entrance detector activated while block was clear and unreserved")
                return
            else
                fault(
                    "SECOND_OR_UNEXPECTED_ENTRY",
                    "Entrance detector activated while block was already occupied or processing another train"
                )
                return
            end
        end

        -- Rear clears ENTRY: whole consist is now inside this block.
        if entryFall then
            if state.sawEntry and state.state == "ENTERING" then
                state.sawEntryClear = true
                state.fullyEnteredAt = now()

                changeState("OCCUPIED", "Entrance detector cleared; whole consist is inside block")
                event("TRAIN_FULLY_ENTERED")
            elseif state.state ~= "CLEAR"
                and state.state ~= "RESERVED"
                and state.state ~= "RELEASED" then

                fault(
                    "ENTRY_CLEARED_UNEXPECTEDLY",
                    "Entrance detector cleared without a recognised entry sequence"
                )
                return
            end
        end

        -- Front reaches the block exit.
        if exitRise then
            if state.state == "OCCUPIED" and state.sawEntryClear then
                state.sawExit = true
                state.exitStartedAt = now()

                changeState("LEAVING", "Exit detector active; train front is leaving block")
                event("TRAIN_EXIT_STARTED")
            elseif state.state == "ENTERING" then
                fault(
                    "EXIT_BEFORE_ENTRY_CLEAR",
                    "Exit activated before the whole consist cleared ENTRY; block may be too short or sequence is invalid"
                )
                return
            elseif state.state == "CLEAR"
                or state.state == "RESERVED"
                or state.state == "RELEASED" then

                fault("EXIT_WITHOUT_OCCUPANCY", "Exit detector activated before a valid train occupied the block")
                return
            else
                fault("UNEXPECTED_EXIT", "Exit detector activated in an unexpected block state")
                return
            end
        end

        -- Rear clears EXIT: whole consist has left this block.
        if exitFall then
            if state.sawExit and state.state == "LEAVING" then
                local clearedTrain = state.trainId

                hold()
                state.occupied = false
                state.reserved = false
                state.clearedAt = now()

                event("TRAIN_CLEARED", { clearedTrainId = clearedTrain })

                state.trainId = nil
                state.fault = nil
                state.reservedAt = nil
                clearMovement()

                changeState("CLEAR", "Exit detector cleared; whole consist has left block")
            elseif state.state ~= "CLEAR" then
                fault(
                    "EXIT_CLEARED_UNEXPECTEDLY",
                    "Exit detector cleared without a recognised exit sequence"
                )
                return
            end
        end
    end

    local function processTimeouts()
        if state.state == "FAULT" then return end

        local current = now()

        if config.releaseTimeout > 0
            and state.state == "RELEASED"
            and state.releasedAt
            and current - state.releasedAt > config.releaseTimeout then

            fault(
                "RELEASE_TIMEOUT",
                "Entry authority remained released too long without the train entering"
            )
            return
        end

        if config.traversalTimeout > 0
            and (state.state == "ENTERING" or state.state == "OCCUPIED")
            and state.enteredAt
            and current - state.enteredAt > config.traversalTimeout then

            fault(
                "TRAVERSAL_TIMEOUT",
                "Train did not reach the block exit within the configured timeout"
            )
            return
        end

        if config.clearanceTimeout > 0
            and state.state == "LEAVING"
            and state.exitStartedAt
            and current - state.exitStartedAt > config.clearanceTimeout then

            fault(
                "CLEARANCE_TIMEOUT",
                "Exit detector remained active too long for the whole consist to clear"
            )
        end
    end

    function controller.update(inputs)
        events = {}
        readInputs(inputs)

        if firstUpdateSafe() then
            processEdges()
            processTimeouts()
        end

        return copy(state), copy(events)
    end

    function controller.getState()
        return copy(state)
    end

    function controller.getConfig()
        return copy(config)
    end

    function controller.getEvents()
        return copy(events)
    end

    function controller.wantsRelease()
        return state.state ~= "FAULT" and state.desiredRelease == true
    end

    function controller.isClear()
        return state.state == "CLEAR"
            and not state.occupied
            and not state.reserved
            and not state.entry
            and not state.exit
    end

    function controller.isReserved()
        return state.reserved == true
            and state.state ~= "CLEAR"
            and state.state ~= "FAULT"
    end

    function controller.isOccupied()
        return state.occupied == true or state.state == "FAULT"
    end

    function controller.isFaulted()
        return state.state == "FAULT"
    end

    function controller.reserve(trainId)
        trainId = cleanId(trainId)

        if trainId == "" then return false, "Train ID is required" end
        if state.state == "FAULT" then return false, "Block is faulted" end

        if state.state ~= "CLEAR" then
            if state.trainId == trainId and state.reserved then
                return true
            end

            return false, "Block is not clear"
        end

        if state.entry or state.exit then
            return false, "Cannot reserve block while a detector is active"
        end

        hold()
        state.trainId = trainId
        state.reserved = true
        state.occupied = false
        state.reservedAt = now()
        state.clearedAt = nil
        clearMovement()

        changeState("RESERVED", "Block reserved for train " .. trainId)
        event("BLOCK_RESERVED")

        return true
    end

    function controller.authoriseEntry(trainId)
        if state.state ~= "RESERVED" then
            return false, "Block must be RESERVED before entry can be authorised"
        end

        if trainId and tostring(trainId) ~= "" then
            local requested = cleanId(trainId)

            if requested == "" then return false, "Train ID is invalid" end

            if state.trainId and requested ~= state.trainId then
                return false, "Train ID does not match block reservation"
            end
        end

        if state.entry or state.exit then
            return false, "Cannot release entry while a block detector is already active"
        end

        state.desiredRelease = true
        state.releasedAt = now()

        changeState("RELEASED", "Entry authorised for reserved train")
        event("ENTRY_RELEASED")

        return true
    end

    function controller.hold()
        hold()

        if state.state == "RELEASED" and not state.entry then
            state.releasedAt = nil
            changeState("RESERVED", "Entry authority withdrawn before train entered")
            event("ENTRY_AUTHORITY_WITHDRAWN")
        end

        return true
    end

    function controller.cancelReservation(trainId)
        if state.state == "FAULT" then
            hold()
            return false, "Block is faulted"
        end

        if state.state ~= "RESERVED" and state.state ~= "RELEASED" then
            return false, "Reservation can only be cancelled before the train enters"
        end

        if trainId and tostring(trainId) ~= "" then
            local requested = cleanId(trainId)

            if state.trainId and requested ~= state.trainId then
                return false, "Train ID does not match block reservation"
            end
        end

        if state.entry or state.exit or state.occupied then
            return false, "Cannot cancel reservation after train movement has begun"
        end

        local cancelledTrain = state.trainId

        hold()
        state.reserved = false
        state.trainId = nil
        state.reservedAt = nil
        clearMovement()

        changeState("CLEAR", "Block reservation cancelled before entry")
        event("RESERVATION_CANCELLED", { cancelledTrainId = cancelledTrain })

        return true
    end

    function controller.clearFault()
        if state.state ~= "FAULT" then return true end

        if state.entry or state.exit then
            return false, "Cannot clear fault while a block detector is active"
        end

        hold()
        state.occupied = false
        state.reserved = false
        state.trainId = nil
        state.fault = nil
        state.reservedAt = nil
        state.clearedAt = now()
        clearMovement()
        state.firstUpdate = false

        changeState("CLEAR", "Fault cleared with both detectors clear")
        event("FAULT_CLEARED")

        return true
    end

    function controller.forceReset(trainId, newState)
        -- Maintenance only. A human must first inspect the physical railway.
        hold()

        newState = string.upper(tostring(newState or "CLEAR"))

        if not VALID_STATES[newState] or newState == "FAULT" then
            return false, "Invalid reset state"
        end

        local cleanedTrain = nil
        if trainId and tostring(trainId) ~= "" then
            cleanedTrain = cleanId(trainId)
        end

        if newState ~= "CLEAR" and not cleanedTrain then
            return false, "A train ID is required when resetting to a non-clear state"
        end

        -- Maintenance reset must never unexpectedly power a locking track.
        if newState == "RELEASED" then newState = "RESERVED" end

        state.trainId = cleanedTrain
        state.fault = nil
        state.firstUpdate = false
        state.reserved = newState ~= "CLEAR"
        state.occupied =
            newState == "ENTERING"
            or newState == "OCCUPIED"
            or newState == "LEAVING"

        state.sawEntry = state.occupied
        state.sawEntryClear = newState == "OCCUPIED" or newState == "LEAVING"
        state.sawExit = newState == "LEAVING"

        state.reservedAt = newState ~= "CLEAR" and now() or nil
        state.releasedAt = nil
        state.enteredAt = state.occupied and now() or nil
        state.fullyEnteredAt = state.sawEntryClear and now() or nil
        state.exitStartedAt = state.sawExit and now() or nil

        changeState(newState, "Manual maintenance resynchronisation")
        event("FORCE_RESET", { newState = newState, trainId = state.trainId })

        return true
    end

    function controller.stop()
        hold()
    end

    return controller
end

return module
