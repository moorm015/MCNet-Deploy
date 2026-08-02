-- MCNet routed wireless network service
-- Version 0.8.0
--
-- Endpoints never send application data directly to another endpoint.
-- They register with a tower and send all DATA/ACK frames through it.
-- Towers discover neighbours, flood link-state advertisements, calculate
-- routes, and fall back to controlled flooding when a route is unknown.

local module = {}

local function now()
    return os.clock()
end

local function countMap(value)
    local count = 0

    for _ in pairs(value or {}) do
        count = count + 1
    end

    return count
end

local function copyTable(source)
    local result = {}

    for key, value in pairs(source or {}) do
        result[key] = value
    end

    return result
end

function module.new(options)
    options = options or {}

    local packetLibrary = options.packetLibrary
    local frameLibrary = options.frameLibrary
    local routingLibrary = options.routingLibrary
    local modemDriver = options.modemDriver
    local config = options.config or {}
    local device = options.device or {
        address = "UNKNOWN",
        type = "UNKNOWN",
        region = "UNKNOWN",
        friendlyName = "",
        systemName = ""
    }

    if not packetLibrary
        or not frameLibrary
        or not routingLibrary
        or not modemDriver then
        error("Network service dependencies are incomplete", 0)
    end

    local network = {}
    local running = false
    local role = device.type == "TOWER" and "ROUTER" or "ENDPOINT"
    local routing = routingLibrary.new(device.address, config)
    local handlers = {}
    local deliveryHandlers = {}
    local pending = {}
    local seenFrames = {}
    local deliveredPackets = {}
    local towerCandidates = {}
    local selectedTower = nil
    local modemReady = false
    local lastModemAttempt = -1000
    local lastBeacon = -1000
    local lastRegistration = -1000
    local lastLSA = -1000
    local lsaSequence = 0
    local bootId =
        tostring(device.address or "UNKNOWN")
        .. "-"
        .. tostring(os.getComputerID())
        .. "-"
        .. tostring(math.random(100000, 999999))

    local counters = {
        framesSent = 0,
        framesReceived = 0,
        framesForwarded = 0,
        framesDropped = 0,
        packetsDelivered = 0,
        acknowledgements = 0,
        retries = 0
    }

    local function configured()
        return device
            and device.address
            and device.address ~= ""
            and device.address ~= "UNKNOWN"
    end

    local function isTower()
        return role == "ROUTER"
    end

    local function pruneMap(map, timeout)
        local currentTime = now()
        local expiredKeys = {}

        -- Lua 5.1 must not have keys removed while pairs() is iterating.
        for key, record in pairs(map) do
            local timestamp = type(record) == "table" and record.time or record

            if currentTime - (tonumber(timestamp) or 0) > timeout then
                expiredKeys[#expiredKeys + 1] = key
            end
        end

        for _, key in ipairs(expiredKeys) do
            map[key] = nil
        end
    end

    local function ensureModem(force)
        if config.enabled == false then
            modemReady = false
            return false, "Network is disabled"
        end

        if modemReady and not force then
            return true
        end

        if not force and now() - lastModemAttempt < 3 then
            return false, "Waiting before modem retry"
        end

        lastModemAttempt = now()

        local found, reason = modemDriver.detect(force == true)

        if not found then
            modemReady = false
            return false, reason
        end

        local opened, openReason = modemDriver.open(config.channel)

        if not opened then
            modemReady = false
            return false, openReason
        end

        modemReady = true
        return true
    end

    local function sendRaw(frame)
        local valid, reason = frameLibrary.validate(frame)

        if not valid then
            counters.framesDropped = counters.framesDropped + 1
            return false, reason
        end

        local ready, modemReason = ensureModem(false)

        if not ready then
            return false, modemReason
        end

        local sent, sendReason =
            modemDriver.send(
                config.channel,
                config.channel,
                frame
            )

        if sent then
            counters.framesSent = counters.framesSent + 1
            return true
        end

        modemReady = false
        return false, sendReason
    end

    local function notifyDelivery(packetId, status, reason)
        for _, handler in ipairs(deliveryHandlers) do
            pcall(handler, packetId, status, reason)
        end

        if os.queueEvent then
            os.queueEvent(
                "mcnet_delivery",
                packetId,
                status,
                reason
            )
        end
    end

    local function selectTower()
        if isTower() then
            selectedTower = nil
            return nil
        end

        local currentTime = now()
        local expiredTowers = {}

        -- Collect expired entries first; deleting during pairs() breaks Lua 5.1.
        for address, candidate in pairs(towerCandidates) do
            if currentTime - (candidate.lastSeen or 0) > config.towerTimeout then
                expiredTowers[#expiredTowers + 1] = address
            end
        end

        for _, address in ipairs(expiredTowers) do
            towerCandidates[address] = nil
        end

        local preferred = tostring(config.preferredTower or "")

        if preferred ~= "" and towerCandidates[preferred] then
            selectedTower = preferred
            return selectedTower
        end

        local bestAddress = nil
        local bestDistance = nil

        for address, candidate in pairs(towerCandidates) do
            local distance = tonumber(candidate.distance) or 0

            if not bestAddress
                or distance < bestDistance
                or (
                    distance == bestDistance
                    and address < bestAddress
                ) then
                bestAddress = address
                bestDistance = distance
            end
        end

        selectedTower = bestAddress
        return selectedTower
    end

    local function chooseNextHop(destination)
        if isTower() then
            local nextHop = routing.getNextHop(destination)

            if nextHop then
                return nextHop
            end

            return "TOWERS"
        end

        return selectTower()
    end

    local function makeRoutedFrame(kind, destination, payload, ttl)
        local nextHop = chooseNextHop(destination)

        if not nextHop then
            return nil, "No tower is available"
        end

        return frameLibrary.new(kind, {
            origin = device.address,
            destination = destination,
            previousHop = device.address,
            nextHop = nextHop,
            ttl = ttl or config.frameTTL,
            payload = payload
        })
    end

    local function dispatchPacket(packet, metadata)
        local serviceHandlers = handlers[packet.service] or {}

        for _, handler in ipairs(serviceHandlers) do
            local completed = pcall(handler, packet, metadata)

            if not completed then
                counters.framesDropped = counters.framesDropped + 1
            end
        end

        counters.packetsDelivered = counters.packetsDelivered + 1

        if os.queueEvent then
            os.queueEvent(
                "mcnet_packet",
                packet.service,
                packet.type,
                packet.id
            )
        end
    end

    local function forwardFrame(frame)
        if frame.ttl <= 0 then
            counters.framesDropped = counters.framesDropped + 1
            return false, "TTL expired"
        end

        local forwarded = frameLibrary.copy(frame)
        local decremented = frameLibrary.decrementTTL(forwarded)

        if not decremented then
            counters.framesDropped = counters.framesDropped + 1
            return false, "TTL expired"
        end

        forwarded.previousHop = device.address

        local nextHop = routing.getNextHop(forwarded.destination)

        if nextHop then
            forwarded.nextHop = nextHop
        else
            forwarded.nextHop = "TOWERS"
        end

        local sent, reason = sendRaw(forwarded)

        if sent then
            counters.framesForwarded = counters.framesForwarded + 1
        else
            counters.framesDropped = counters.framesDropped + 1
        end

        return sent, reason
    end

    local function sendAcknowledgement(packet)
        if not packet or not packet.source or packet.source == "BROADCAST" then
            return false
        end

        local acknowledgement, reason =
            makeRoutedFrame(
                "ACK",
                packet.source,
                {
                    ackId = packet.id
                },
                config.frameTTL
            )

        if not acknowledgement then
            return false, reason
        end

        seenFrames[acknowledgement.id] = {
            time = now()
        }

        return sendRaw(acknowledgement)
    end

    local function deliverData(frame, distance)
        local packet = frame.payload
        local valid, reason = packetLibrary.validate(packet)

        if not valid then
            counters.framesDropped = counters.framesDropped + 1
            return false, reason
        end

        if deliveredPackets[packet.id] then
            sendAcknowledgement(packet)
            return true, "duplicate"
        end

        deliveredPackets[packet.id] = {
            time = now()
        }

        dispatchPacket(packet, {
            previousHop = frame.previousHop,
            distance = distance,
            frameId = frame.id
        })

        sendAcknowledgement(packet)
        return true
    end

    local function deliverAcknowledgement(frame)
        local payload = frame.payload

        if type(payload) ~= "table" or not payload.ackId then
            counters.framesDropped = counters.framesDropped + 1
            return false, "ACK payload is invalid"
        end

        local packetId = tostring(payload.ackId)
        local item = pending[packetId]

        if item then
            pending[packetId] = nil
            counters.acknowledgements = counters.acknowledgements + 1
            notifyDelivery(packetId, "DELIVERED")
        end

        return true
    end

    local function processBeacon(frame, distance)
        if frame.origin == device.address then
            return
        end

        local metadata =
            type(frame.payload) == "table"
            and frame.payload
            or {}

        if isTower() then
            routing.updateNeighbour(
                frame.origin,
                distance,
                metadata
            )
            return
        end

        towerCandidates[frame.origin] = {
            address = frame.origin,
            distance = tonumber(distance) or 0,
            lastSeen = now(),
            region = metadata.region,
            friendlyName = metadata.friendlyName,
            systemName = metadata.systemName
        }

        selectTower()
    end

    local function processRegistration(frame, distance)
        if not isTower() or frame.nextHop ~= device.address then
            return
        end

        local metadata =
            type(frame.payload) == "table"
            and frame.payload
            or {}

        routing.registerEndpoint(
            frame.origin,
            distance,
            metadata
        )
    end

    local function processLSA(frame)
        if not isTower() then
            return
        end

        local accepted =
            routing.acceptLSA(frame.payload)

        if not accepted then
            return
        end

        if frame.ttl <= 0 then
            return
        end

        local forwarded = frameLibrary.copy(frame)
        local decremented = frameLibrary.decrementTTL(forwarded)

        if not decremented then
            return
        end

        forwarded.previousHop = device.address
        forwarded.nextHop = "TOWERS"

        if sendRaw(forwarded) then
            counters.framesForwarded = counters.framesForwarded + 1
        end
    end

    local function endpointMayAccept(frame)
        if isTower() then
            return true
        end

        if not selectedTower then
            return false
        end

        return frame.previousHop == selectedTower
    end

    local function processRoutedFrame(frame, distance)
        if not endpointMayAccept(frame) then
            return
        end

        if frame.destination == device.address then
            if frame.kind == "DATA" then
                deliverData(frame, distance)
            elseif frame.kind == "ACK" then
                deliverAcknowledgement(frame)
            end

            return
        end

        if isTower() then
            forwardFrame(frame)
        end
    end

    local function processFrame(frame, distance)
        local valid = frameLibrary.validate(frame)

        if not valid then
            return
        end

        if not configured() then
            return
        end

        if not frameLibrary.isForHop(
            frame,
            device.address,
            isTower()
        ) then
            return
        end

        counters.framesReceived = counters.framesReceived + 1

        if frame.kind == "BEACON" then
            processBeacon(frame, distance)
            return
        end

        if frame.kind == "REGISTER" then
            processRegistration(frame, distance)
            return
        end

        if seenFrames[frame.id] then
            return
        end

        seenFrames[frame.id] = {
            time = now()
        }

        if frame.kind == "LSA" then
            processLSA(frame)
            return
        end

        if frame.kind == "DATA" or frame.kind == "ACK" then
            processRoutedFrame(frame, distance)
        end
    end

    local function sendBeacon()
        if not isTower() or not configured() then
            return
        end

        local frame = frameLibrary.new("BEACON", {
            origin = device.address,
            destination = "*",
            previousHop = device.address,
            nextHop = "*",
            ttl = 1,
            payload = {
                type = device.type,
                region = device.region,
                friendlyName = device.friendlyName,
                systemName = device.systemName,
                bootId = bootId
            }
        })

        sendRaw(frame)
    end

    local function sendRegistration()
        if isTower() or not configured() then
            return
        end

        local tower = selectTower()

        if not tower then
            return
        end

        local frame = frameLibrary.new("REGISTER", {
            origin = device.address,
            destination = tower,
            previousHop = device.address,
            nextHop = tower,
            ttl = 2,
            payload = {
                type = device.type,
                region = device.region,
                friendlyName = device.friendlyName,
                systemName = device.systemName
            }
        })

        sendRaw(frame)
    end

    local function sendLSA()
        if not isTower() or not configured() then
            return
        end

        lsaSequence = lsaSequence + 1

        local payload =
            routing.createLSA(
                bootId,
                lsaSequence,
                device
            )

        local frame = frameLibrary.new("LSA", {
            origin = device.address,
            destination = "TOWERS",
            previousHop = device.address,
            nextHop = "TOWERS",
            ttl = config.frameTTL,
            payload = payload
        })

        seenFrames[frame.id] = {
            time = now()
        }

        sendRaw(frame)
    end

    local function transmitPending(item)
        local frame, reason =
            makeRoutedFrame(
                "DATA",
                item.packet.destination,
                item.packet,
                item.packet.ttl or config.frameTTL
            )

        if not frame then
            item.status = "QUEUED"
            item.reason = reason
            return false, reason
        end

        seenFrames[frame.id] = {
            time = now()
        }

        local sent, sendReason = sendRaw(frame)

        if sent then
            item.attempts = item.attempts + 1
            item.lastAttempt = now()
            item.status = "SENT"
            item.reason = nil

            if item.attempts > 1 then
                counters.retries = counters.retries + 1
            end

            notifyDelivery(
                item.packet.id,
                item.attempts > 1 and "RETRYING" or "SENT"
            )

            return true
        end

        item.status = "QUEUED"
        item.reason = sendReason
        return false, sendReason
    end

    local function maintainPending()
        local currentTime = now()
        local failedItems = {}

        for packetId, item in pairs(pending) do
            local due =
                item.attempts == 0
                or currentTime - (item.lastAttempt or 0) >= config.ackTimeout

            if due then
                if item.attempts >= config.maxRetries then
                    failedItems[#failedItems + 1] = {
                        packetId = packetId,
                        reason = item.reason or "No acknowledgement received"
                    }
                else
                    transmitPending(item)
                end
            end
        end

        -- Remove failed packets after the pairs() traversal has finished.
        for _, failed in ipairs(failedItems) do
            pending[failed.packetId] = nil
            notifyDelivery(failed.packetId, "FAILED", failed.reason)
        end
    end

    function network.on(service, handler)
        service = string.upper(tostring(service or ""))

        if service == "" or type(handler) ~= "function" then
            return false
        end

        handlers[service] = handlers[service] or {}
        table.insert(handlers[service], handler)
        return true
    end

    function network.onDelivery(handler)
        if type(handler) ~= "function" then
            return false
        end

        table.insert(deliveryHandlers, handler)
        return true
    end

    function network.send(destination, service, packetType, payload, optionsValue)
        optionsValue = optionsValue or {}

        if not configured() then
            return false, "This device is not configured"
        end

        destination = string.upper(tostring(destination or ""))

        if destination == "" or destination == "UNKNOWN" then
            return false, "Destination is invalid"
        end

        local packet = packetLibrary.new({
            source = device.address,
            destination = destination,
            service = string.upper(tostring(service or "SYSTEM")),
            type = string.upper(tostring(packetType or "MESSAGE")),
            priority = optionsValue.priority or 0,
            ttl = optionsValue.ttl or config.frameTTL,
            payload = payload
        })

        pending[packet.id] = {
            packet = packet,
            attempts = 0,
            lastAttempt = 0,
            status = "QUEUED"
        }

        transmitPending(pending[packet.id])
        return true, packet.id
    end

    function network.tick()
        ensureModem(false)
        routing.prune()
        pruneMap(seenFrames, config.seenTimeout)
        pruneMap(deliveredPackets, config.seenTimeout)

        if isTower() then
            if now() - lastBeacon >= config.beaconInterval then
                lastBeacon = now()
                sendBeacon()
            end

            if now() - lastLSA >= config.lsaInterval then
                lastLSA = now()
                sendLSA()
            end
        else
            selectTower()

            if now() - lastRegistration >= config.registrationInterval then
                lastRegistration = now()
                sendRegistration()
            end
        end

        maintainPending()
    end

    function network.handleEvent(event)
        if type(event) ~= "table" then
            return
        end

        if event[1] == "modem_message"
            and event[3] == config.channel then
            processFrame(event[5], event[6])
        elseif event[1] == "peripheral"
            or event[1] == "peripheral_detach" then
            modemReady = false
            ensureModem(true)
        end
    end

    function network.run()
        running = true
        ensureModem(true)
        network.tick()

        local timer =
            os.startTimer(config.tickInterval)

        while running do
            local event = {
                os.pullEvent()
            }

            if event[1] == "timer"
                and event[2] == timer then
                network.tick()
                timer =
                    os.startTimer(config.tickInterval)
            else
                network.handleEvent(event)
            end
        end
    end

    function network.stop()
        running = false
    end

    function network.setDevice(newDevice)
        device = copyTable(newDevice or device)
        role = device.type == "TOWER" and "ROUTER" or "ENDPOINT"
        routing.setAddress(device.address)
        towerCandidates = {}
        selectedTower = nil
        lsaSequence = 0
        bootId =
            tostring(device.address or "UNKNOWN")
            .. "-"
            .. tostring(os.getComputerID())
            .. "-"
            .. tostring(math.random(100000, 999999))
    end

    function network.getDevice()
        return copyTable(device)
    end

    function network.getStatus()
        local summary = routing.getSummary()

        return {
            enabled = config.enabled ~= false,
            configured = configured(),
            role = role,
            address = device.address,
            channel = config.channel,
            modemReady = modemReady,
            selectedTower = selectTower(),
            nearbyTowers = countMap(towerCandidates),
            neighbours = summary.neighbours,
            localEndpoints = summary.localEndpoints,
            topologyEntries = summary.topologyEntries,
            knownDestinations = summary.knownDestinations,
            pending = countMap(pending),
            counters = copyTable(counters)
        }
    end

    function network.getNearbyTowers()
        selectTower()

        local result = {}

        for _, candidate in pairs(towerCandidates) do
            table.insert(result, copyTable(candidate))
        end

        table.sort(result, function(left, right)
            local leftDistance = tonumber(left.distance) or 0
            local rightDistance = tonumber(right.distance) or 0

            if leftDistance == rightDistance then
                return tostring(left.address) < tostring(right.address)
            end

            return leftDistance < rightDistance
        end)

        return result
    end

    function network.getNeighbours()
        return routing.getNeighbours()
    end

    function network.getLocalEndpoints()
        return routing.getLocalEndpoints()
    end

    function network.getTopology()
        return routing.getTopology()
    end

    function network.getKnownDestinations()
        return routing.getKnownDestinations()
    end

    function network.getPending()
        local result = {}

        for packetId, item in pairs(pending) do
            table.insert(result, {
                id = packetId,
                destination = item.packet.destination,
                service = item.packet.service,
                type = item.packet.type,
                attempts = item.attempts,
                status = item.status,
                reason = item.reason
            })
        end

        table.sort(result, function(left, right)
            return tostring(left.id) < tostring(right.id)
        end)

        return result
    end

    function network.getConfig()
        return config
    end

    return network
end

return module