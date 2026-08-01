-- MCNet tower link-state routing database
-- Version 0.8.0

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

local function sortedValues(map, field)
    local result = {}

    for _, value in pairs(map or {}) do
        table.insert(result, value)
    end

    table.sort(result, function(left, right)
        return tostring(left[field] or left.address or "") < tostring(right[field] or right.address or "")
    end)

    return result
end

local function addEdge(graph, left, right)
    if not left or not right or left == "" or right == "" or left == right then
        return
    end

    graph[left] = graph[left] or {}
    graph[right] = graph[right] or {}
    graph[left][right] = true
    graph[right][left] = true
end

function module.new(selfAddress, config)
    local routing = {}
    local address = tostring(selfAddress or "UNKNOWN")
    local neighbours = {}
    local localEndpoints = {}
    local lsdb = {}

    local function fresh(record, timeout)
        local timestamp =
            record
            and (
                record.lastSeen
                or record.receivedAt
            )

        return timestamp
            and now() - timestamp <= timeout
    end

    function routing.setAddress(newAddress)
        address = tostring(newAddress or "UNKNOWN")
        neighbours = {}
        localEndpoints = {}
        lsdb = {}
    end

    function routing.updateNeighbour(neighbourAddress, distance, metadata)
        neighbourAddress = tostring(neighbourAddress or "")

        if neighbourAddress == "" or neighbourAddress == address then
            return false
        end

        local record = neighbours[neighbourAddress] or {
            address = neighbourAddress
        }

        record.distance = tonumber(distance) or record.distance or 0
        record.lastSeen = now()
        record.region = metadata and metadata.region or record.region
        record.friendlyName = metadata and metadata.friendlyName or record.friendlyName
        neighbours[neighbourAddress] = record
        return true
    end

    function routing.registerEndpoint(endpointAddress, distance, metadata)
        endpointAddress = tostring(endpointAddress or "")

        if endpointAddress == "" or endpointAddress == address then
            return false
        end

        local record = localEndpoints[endpointAddress] or {
            address = endpointAddress
        }

        record.distance = tonumber(distance) or record.distance or 0
        record.lastSeen = now()
        record.type = metadata and metadata.type or record.type
        record.region = metadata and metadata.region or record.region
        record.friendlyName = metadata and metadata.friendlyName or record.friendlyName
        record.systemName = metadata and metadata.systemName or record.systemName
        localEndpoints[endpointAddress] = record
        return true
    end

    function routing.createLSA(bootId, sequence, device)
        local neighbourList = {}
        local endpointList = {}

        for neighbourAddress, record in pairs(neighbours) do
            if fresh(record, config.neighbourTimeout) then
                table.insert(neighbourList, neighbourAddress)
            end
        end

        table.sort(neighbourList)

        for endpointAddress, record in pairs(localEndpoints) do
            if fresh(record, config.endpointTimeout) then
                table.insert(endpointList, {
                    address = endpointAddress,
                    type = record.type,
                    region = record.region,
                    friendlyName = record.friendlyName,
                    systemName = record.systemName
                })
            end
        end

        table.sort(endpointList, function(left, right)
            return tostring(left.address) < tostring(right.address)
        end)

        return {
            origin = address,
            bootId = tostring(bootId or ""),
            sequence = tonumber(sequence) or 0,
            generated = now(),
            region = device and device.region or "UNKNOWN",
            friendlyName = device and device.friendlyName or "",
            neighbours = neighbourList,
            endpoints = endpointList
        }
    end

    function routing.acceptLSA(payload)
        if type(payload) ~= "table" then
            return false, "LSA payload is invalid"
        end

        local origin = tostring(payload.origin or "")

        if origin == "" or origin == address then
            return false, "LSA origin is invalid"
        end

        local bootId = tostring(payload.bootId or "")
        local sequence = tonumber(payload.sequence)

        if bootId == "" or not sequence then
            return false, "LSA identity is incomplete"
        end

        local current = lsdb[origin]

        if current
            and current.bootId == bootId
            and sequence <= current.sequence then
            return false, "LSA is not newer"
        end

        lsdb[origin] = {
            origin = origin,
            bootId = bootId,
            sequence = sequence,
            receivedAt = now(),
            region = payload.region,
            friendlyName = payload.friendlyName,
            neighbours = payload.neighbours or {},
            endpoints = payload.endpoints or {}
        }

        return true
    end

    function routing.prune()
        local currentTime = now()

        for neighbourAddress, record in pairs(neighbours) do
            if currentTime - (record.lastSeen or 0) > config.neighbourTimeout then
                neighbours[neighbourAddress] = nil
            end
        end

        for endpointAddress, record in pairs(localEndpoints) do
            if currentTime - (record.lastSeen or 0) > config.endpointTimeout then
                localEndpoints[endpointAddress] = nil
            end
        end

        for origin, record in pairs(lsdb) do
            if currentTime - (record.receivedAt or 0) > config.topologyTimeout then
                lsdb[origin] = nil
            end
        end
    end

    function routing.isLocalEndpoint(destination)
        local record = localEndpoints[destination]
        return fresh(record, config.endpointTimeout) == true
    end

    function routing.getEndpointOwner(destination)
        if routing.isLocalEndpoint(destination) then
            return address
        end

        for origin, record in pairs(lsdb) do
            if fresh(record, config.topologyTimeout) then
                for _, endpoint in ipairs(record.endpoints or {}) do
                    if endpoint.address == destination then
                        return origin
                    end
                end
            end
        end

        return nil
    end

    function routing.getNextHop(destination)
        routing.prune()
        destination = tostring(destination or "")

        if destination == "" then
            return nil, "Destination is missing"
        end

        if destination == address then
            return address, "local"
        end

        if routing.isLocalEndpoint(destination) then
            return destination, "endpoint"
        end

        local owner = routing.getEndpointOwner(destination)

        if not owner then
            if neighbours[destination] or lsdb[destination] then
                owner = destination
            end
        end

        if not owner then
            return nil, "No route is known"
        end

        if owner == address then
            return destination, "endpoint"
        end

        local graph = {}

        for neighbourAddress in pairs(neighbours) do
            addEdge(graph, address, neighbourAddress)
        end

        for origin, record in pairs(lsdb) do
            for _, neighbourAddress in ipairs(record.neighbours or {}) do
                addEdge(graph, origin, neighbourAddress)
            end
        end

        local queue = { address }
        local head = 1
        local visited = {
            [address] = true
        }
        local parent = {}

        while head <= #queue do
            local current = queue[head]
            head = head + 1

            if current == owner then
                break
            end

            for neighbourAddress in pairs(graph[current] or {}) do
                if not visited[neighbourAddress] then
                    visited[neighbourAddress] = true
                    parent[neighbourAddress] = current
                    table.insert(queue, neighbourAddress)
                end
            end
        end

        if not visited[owner] then
            return nil, "Destination tower is unreachable"
        end

        local cursor = owner

        while parent[cursor] and parent[cursor] ~= address do
            cursor = parent[cursor]
        end

        if parent[cursor] == address then
            return cursor, "tower"
        end

        if cursor == owner and neighbours[cursor] then
            return cursor, "tower"
        end

        return nil, "Could not determine the first hop"
    end

    function routing.getNeighbours()
        routing.prune()
        return sortedValues(neighbours, "address")
    end

    function routing.getLocalEndpoints()
        routing.prune()
        return sortedValues(localEndpoints, "address")
    end

    function routing.getTopology()
        routing.prune()
        return sortedValues(lsdb, "origin")
    end

    function routing.getKnownDestinations()
        routing.prune()

        local result = {}
        local seen = {}

        local function add(destination, owner, kind)
            if destination and destination ~= "" and not seen[destination] then
                seen[destination] = true
                table.insert(result, {
                    destination = destination,
                    owner = owner,
                    kind = kind
                })
            end
        end

        add(address, address, "TOWER")

        for neighbourAddress in pairs(neighbours) do
            add(neighbourAddress, neighbourAddress, "TOWER")
        end

        for endpointAddress in pairs(localEndpoints) do
            add(endpointAddress, address, "ENDPOINT")
        end

        for origin, record in pairs(lsdb) do
            add(origin, origin, "TOWER")

            for _, endpoint in ipairs(record.endpoints or {}) do
                add(endpoint.address, origin, endpoint.type or "ENDPOINT")
            end
        end

        table.sort(result, function(left, right)
            return tostring(left.destination) < tostring(right.destination)
        end)

        return result
    end

    function routing.getSummary()
        routing.prune()

        return {
            neighbours = countMap(neighbours),
            localEndpoints = countMap(localEndpoints),
            topologyEntries = countMap(lsdb),
            knownDestinations = #routing.getKnownDestinations()
        }
    end

    return routing
end

return module
