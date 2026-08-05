-- MCNet archive reader application
-- Version 0.9.1
--
-- Read-only application for browsing verified MCNet archive disks.
-- The disk drive is expected directly below the computer.

local application = {}

local DRIVE_SIDE = "bottom"
local ARCHIVE_FOLDER = "mcnet-archive"

local function combine(...)
    local parts = { ... }
    local result = ""

    for _, part in ipairs(parts) do
        local text = tostring(part or "")

        if text ~= "" then
            if result == "" then
                result = text
            else
                result = fs.combine(result, text)
            end
        end
    end

    return result
end

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

local function readLuaFile(path)
    if type(path) ~= "string"
        or path == ""
        or not fs.exists(path)
        or fs.isDir(path) then

        return false,
            "File is unavailable: "
            .. tostring(path)
    end

    local loaded, value =
        pcall(
            dofile,
            path
        )

    if not loaded then
        return false,
            tostring(value)
    end

    if type(value) ~= "table" then
        return false,
            "Archive file did not return a table"
    end

    return true,
        value
end

local function safeText(value)
    return tostring(value or "")
end

local function formatBytes(value)
    value = tonumber(value)

    if not value then
        return "UNKNOWN"
    end

    if value < 1024 then
        return tostring(
            math.floor(value)
        ) .. " B"
    end

    if value < 1024 * 1024 then
        return string.format(
            "%.1f KB",
            value / 1024
        )
    end

    return string.format(
        "%.2f MB",
        value / (1024 * 1024)
    )
end

local function trimText(value, maximum)
    local text = safeText(value)
    maximum = math.max(
        0,
        tonumber(maximum) or #text
    )

    if #text <= maximum then
        return text
    end

    if maximum <= 3 then
        return string.sub(
            text,
            1,
            maximum
        )
    end

    return string.sub(
        text,
        1,
        maximum - 3
    ) .. "..."
end

local function formatDayTime(day, time)
    return "Day "
        .. tostring(day or 0)
        .. "  "
        .. tostring(time or 0)
end

local function normaliseArchive(value)
    value =
        type(value) == "table"
        and value
        or {}

    value.messages =
        type(value.messages) == "table"
        and value.messages
        or {}

    value.events =
        type(value.events) == "table"
        and value.events
        or {}

    value.devices =
        type(value.devices) == "table"
        and value.devices
        or {}

    value.towers =
        type(value.towers) == "table"
        and value.towers
        or {}

    value.manifest =
        type(value.manifest) == "table"
        and value.manifest
        or nil

    return value
end

local function countTable(value)
    local count = 0

    if type(value) == "table" then
        for _ in pairs(value) do
            count = count + 1
        end
    end

    return count
end

local function archiveCounts(archive)
    archive =
        type(archive) == "table"
        and archive
        or {}

    return {
        messages =
            countTable(
                archive.messages
            ),

        events =
            #(archive.events or {}),

        devices =
            countTable(
                archive.devices
            ),

        towers =
            countTable(
                archive.towers
            )
    }
end

local function verifyManifest(
    archivePath,
    metadata,
    manifest
)
    if type(manifest) ~= "table" then
        return true, "LEGACY"
    end

    if manifest.complete ~= true
        or manifest.verified ~= true then

        return false,
            "Archive manifest is incomplete"
    end

    if tostring(manifest.archiveId or "")
        ~= tostring(metadata.archiveId or "") then

        return false,
            "Archive manifest ID does not match metadata"
    end

    if tonumber(manifest.archiveFormat or 0)
        ~= tonumber(metadata.format or 0) then

        return false,
            "Archive format does not match manifest"
    end

    for _, entry in ipairs(
        manifest.files or {}
    ) do
        local path =
            combine(
                archivePath,
                entry.name
            )

        if not fs.exists(path)
            or fs.isDir(path) then

            return false,
                "Manifest file is missing: "
                .. safeText(entry.name)
        end

        if tonumber(entry.bytes) then
            local actualBytes =
                tonumber(
                    fs.getSize(path)
                )

            if actualBytes
                ~= tonumber(entry.bytes) then

                return false,
                    "Manifest size mismatch: "
                    .. safeText(entry.name)
            end
        end
    end

    return true, "VERIFIED"
end

local function sortedValues(map, sorter)
    local result = {}

    for _, value in pairs(map or {}) do
        result[#result + 1] =
            value
    end

    table.sort(
        result,
        sorter
    )

    return result
end

local function getDisplayName(entry)
    if type(entry) ~= "table" then
        return "UNKNOWN"
    end

    if entry.friendlyName
        and entry.friendlyName ~= "" then

        return entry.friendlyName
    end

    if entry.systemName
        and entry.systemName ~= "" then

        return entry.systemName
    end

    return entry.address
        or entry.id
        or "UNKNOWN"
end

function application.run(context)
    local ui = context.ui
    local menu = context.menu
    local deviceModule = context.deviceModule
    local appManager = context.appManager

    local archive = nil
    local archiveError = nil
    local mountPath = nil
    local archivePath = nil

    local function getDevice()
        return deviceModule.load(
            nil,
            context.version,
            context.protocol
        )
    end

    local function systemConsole()
        local child = {}

        for key, value in pairs(context) do
            child[key] = value
        end

        child.fromRole = true

        local ok, reason =
            appManager.run(
                appManager.getSystemConsolePath(),
                child
            )

        if not ok then
            ui.drawHeader(
                "System console error",
                getDevice(),
                context.version
            )

            print("")
            print(tostring(reason))
            ui.pause()
        end
    end

    local function detectDisk()
        archive = nil
        archiveError = nil
        mountPath = nil
        archivePath = nil

        if not peripheral
            or not peripheral.getType then

            archiveError =
                "Peripheral API is unavailable"

            return false
        end

        if peripheral.getType(DRIVE_SIDE)
            ~= "drive" then

            archiveError =
                "No disk drive is attached below this computer"

            return false
        end

        if not disk
            or not disk.isPresent
            or not disk.getMountPath then

            archiveError =
                "Disk API is unavailable"

            return false
        end

        local presentOkay,
            present =
            pcall(
                disk.isPresent,
                DRIVE_SIDE
            )

        if not presentOkay
            or not present then

            archiveError =
                "Insert an MCNet archive disk"

            return false
        end

        local mountOkay,
            mounted =
            pcall(
                disk.getMountPath,
                DRIVE_SIDE
            )

        if not mountOkay
            or type(mounted) ~= "string"
            or mounted == "" then

            archiveError =
                "The inserted disk is not mounted"

            return false
        end

        mountPath = mounted
        archivePath =
            combine(
                mountPath,
                ARCHIVE_FOLDER
            )

        if not fs.exists(archivePath)
            or not fs.isDir(archivePath) then

            archiveError =
                "This disk does not contain an MCNet archive"

            return false
        end

        local metadataOkay,
            metadata =
            readLuaFile(
                combine(
                    archivePath,
                    "archive.lua"
                )
            )

        if not metadataOkay then
            archiveError =
                "Archive metadata could not be read: "
                .. tostring(metadata)

            return false
        end

        if metadata.complete ~= true
            or metadata.verified ~= true then

            archiveError =
                "Archive is incomplete or unverified"

            return false
        end

        local manifest = nil
        local manifestPath =
            combine(
                archivePath,
                "manifest.lua"
            )

        if fs.exists(manifestPath)
            and not fs.isDir(manifestPath) then

            local manifestOkay,
                loadedManifest =
                readLuaFile(manifestPath)

            if not manifestOkay then
                archiveError =
                    "Archive manifest could not be read: "
                    .. tostring(loadedManifest)

                return false
            end

            manifest =
                loadedManifest

            local manifestValid,
                manifestReason =
                verifyManifest(
                    archivePath,
                    metadata,
                    manifest
                )

            if not manifestValid then
                archiveError =
                    tostring(manifestReason)

                return false
            end
        end

        local messagesOkay,
            messages =
            readLuaFile(
                combine(
                    archivePath,
                    "messages.lua"
                )
            )

        if not messagesOkay then
            archiveError =
                "Messages file could not be read: "
                .. tostring(messages)

            return false
        end

        local eventsOkay,
            events =
            readLuaFile(
                combine(
                    archivePath,
                    "events.lua"
                )
            )

        if not eventsOkay then
            archiveError =
                "Events file could not be read: "
                .. tostring(events)

            return false
        end

        local devicesOkay,
            devices =
            readLuaFile(
                combine(
                    archivePath,
                    "directory.lua"
                )
            )

        if not devicesOkay then
            archiveError =
                "Directory file could not be read: "
                .. tostring(devices)

            return false
        end

        local towersOkay,
            towers =
            readLuaFile(
                combine(
                    archivePath,
                    "towers.lua"
                )
            )

        if not towersOkay then
            archiveError =
                "Tower file could not be read: "
                .. tostring(towers)

            return false
        end

        archive =
            normaliseArchive({
                metadata = metadata,
                manifest = manifest,
                messages = messages,
                events = events,
                devices = devices,
                towers = towers
            })

        return true
    end

    local function ensureArchive()
        if archive then
            return true
        end

        return detectDisk()
    end

    local function archiveInformation()
        if not ensureArchive() then
            ui.drawHeader(
                "Archive unavailable",
                getDevice(),
                context.version
            )

            print("")
            print(tostring(archiveError))
            ui.pause()
            return
        end

        local metadata =
            archive.metadata or {}

        local start =
            ui.drawHeader(
                "Archive information",
                getDevice(),
                context.version
            )

        ui.printField(
            "Archive",
            metadata.archiveId
                or "UNKNOWN",
            start
        )

        ui.printField(
            "Server",
            metadata.server
                or "UNKNOWN",
            start + 1
        )

        ui.printField(
            "Created",
            formatDayTime(
                metadata.createdDay,
                metadata.createdTime
            ),
            start + 2
        )

        ui.printField(
            "First record",
            formatDayTime(
                metadata.firstRecordDay,
                metadata.firstRecordTime
            ),
            start + 3
        )

        ui.printField(
            "Last record",
            formatDayTime(
                metadata.lastRecordDay,
                metadata.lastRecordTime
            ),
            start + 4
        )

        ui.printField(
            "Messages",
            metadata.messageCount
                or countTable(
                    archive.messages
                ),
            start + 5
        )

        ui.printField(
            "Events",
            metadata.eventCount
                or #archive.events,
            start + 6
        )

        ui.printField(
            "Devices",
            metadata.deviceCount
                or countTable(
                    archive.devices
                ),
            start + 7
        )

        ui.printField(
            "Towers",
            metadata.towerCount
                or countTable(
                    archive.towers
                ),
            start + 8
        )

        ui.printField(
            "MCNet version",
            metadata.mcnetVersion
                or "LEGACY",
            start + 9
        )

        ui.printField(
            "Protocol",
            metadata.protocol
                or "UNKNOWN",
            start + 10
        )

        local manifest =
            archive.manifest

        ui.printField(
            "Manifest",
            manifest
                and "VERIFIED"
                or "LEGACY / NONE",
            start + 11
        )

        ui.printField(
            "Archive size",
            manifest
                and formatBytes(
                    manifest.totalBytes
                )
                or "UNKNOWN",
            start + 12
        )

        ui.printField(
            "Verified",
            metadata.verified
                and "YES"
                or "NO",
            start + 13
        )

        ui.pause()
    end

    local function messageDetails(item)
        ui.drawHeader(
            "Archived message",
            getDevice(),
            context.version
        )

        print("")

        print(
            "ID: "
            .. safeText(item.id)
        )

        print(
            "From: "
            .. safeText(
                item.from
                or item.originalSource
            )
        )

        print(
            "To: "
            .. safeText(item.to)
        )

        print(
            "Sent: "
            .. formatDayTime(
                item.day
                    or item.sentDay,
                item.time
                    or item.sentTime
            )
        )

        if item.deliveredDay then
            print(
                "Delivered: "
                .. formatDayTime(
                    item.deliveredDay,
                    item.deliveredTime
                )
            )
        end

        print("")
        print(
            safeText(item.text)
        )

        ui.pause()
    end

    local function messageArray()
        local result = {}

        for messageId, item in pairs(
            archive.messages or {}
        ) do
            local copy =
                deepCopy(item)

            copy.id =
                copy.id
                or messageId

            result[#result + 1] =
                copy
        end

        table.sort(
            result,
            function(left, right)
                local leftDay =
                    tonumber(
                        left.day
                        or left.sentDay
                        or left.createdDay
                    ) or 0

                local rightDay =
                    tonumber(
                        right.day
                        or right.sentDay
                        or right.createdDay
                    ) or 0

                if leftDay == rightDay then
                    local leftTime =
                        tonumber(
                            left.time
                            or left.sentTime
                            or left.createdTime
                        ) or 0

                    local rightTime =
                        tonumber(
                            right.time
                            or right.sentTime
                            or right.createdTime
                        ) or 0

                    return leftTime
                        > rightTime
                end

                return leftDay
                    > rightDay
            end
        )

        return result
    end

    local function browseMessages()
        if not ensureArchive() then
            return
        end

        while true do
            local options = {}

            for _, item in ipairs(
                messageArray()
            ) do
                local message = item

                table.insert(
                    options,
                    {
                        label =
                            safeText(
                                message.from
                            )
                            .. " -> "
                            .. safeText(
                                message.to
                            )
                            .. "  "
                            .. trimText(
                                message.text,
                                28
                            ),

                        compactLabel =
                            safeText(
                                message.from
                            )
                            .. " "
                            .. trimText(
                                message.text,
                                13
                            ),

                        description =
                            formatDayTime(
                                message.day
                                    or message.sentDay,
                                message.time
                                    or message.sentTime
                            ),

                        action = function()
                            messageDetails(
                                message
                            )
                        end
                    }
                )
            end

            if #options == 0 then
                table.insert(
                    options,
                    {
                        label =
                            "No archived messages",
                        disabled = true,
                        description =
                            "This disk is a snapshot archive; no messages were old enough to archive."
                    }
                )
            end

            table.insert(
                options,
                {
                    label = "Back",
                    back = true
                }
            )

            local selected =
                menu.choose(
                    ui,
                    "Archived messages",
                    options,
                    getDevice(),
                    context.version
                )

            if selected.back then
                return
            end

            if selected.action then
                selected.action()
            end
        end
    end

    local function eventDetails(item)
        ui.drawHeader(
            "Archived event",
            getDevice(),
            context.version
        )

        print("")
        print(
            "Type: "
            .. safeText(item.kind)
        )

        print(
            "Source: "
            .. safeText(
                item.source
                or "LOCAL"
            )
        )

        print(
            "Time: "
            .. formatDayTime(
                item.day,
                item.time
            )
        )

        print("")
        print(
            safeText(item.message)
        )

        ui.pause()
    end

    local function browseEvents()
        if not ensureArchive() then
            return
        end

        while true do
            local options = {}

            for index = #archive.events,
                1,
                -1 do

                local item =
                    archive.events[index]

                table.insert(
                    options,
                    {
                        label =
                            safeText(item.kind)
                            .. "  "
                            .. trimText(
                                item.message,
                                35
                            ),

                        compactLabel =
                            safeText(item.kind)
                            .. " "
                            .. trimText(
                                item.source,
                                12
                            ),

                        description =
                            formatDayTime(
                                item.day,
                                item.time
                            ),

                        action = function()
                            eventDetails(item)
                        end
                    }
                )
            end

            if #options == 0 then
                table.insert(
                    options,
                    {
                        label =
                            "No archived events",
                        disabled = true,
                        description =
                            "This disk is a snapshot archive; no events were old enough to archive."
                    }
                )
            end

            table.insert(
                options,
                {
                    label = "Back",
                    back = true
                }
            )

            local selected =
                menu.choose(
                    ui,
                    "Archived events",
                    options,
                    getDevice(),
                    context.version
                )

            if selected.back then
                return
            end

            if selected.action then
                selected.action()
            end
        end
    end

    local function deviceDetails(item)
        ui.drawHeader(
            "Archived device",
            getDevice(),
            context.version
        )

        print("")
        print(
            "Name: "
            .. getDisplayName(item)
        )

        print(
            "Address: "
            .. safeText(item.address)
        )

        print(
            "Type: "
            .. safeText(item.type)
        )

        print(
            "Region: "
            .. safeText(item.region)
        )

        print(
            "Owner: "
            .. safeText(item.owner)
        )

        print(
            "Status: "
            .. safeText(item.status)
        )

        print(
            "Last seen: "
            .. formatDayTime(
                item.lastSeenDay,
                item.lastSeenTime
            )
        )

        ui.pause()
    end

    local function browseDirectory()
        if not ensureArchive() then
            return
        end

        local entries =
            sortedValues(
                archive.devices,
                function(left, right)
                    return safeText(
                        left.address
                    )
                        < safeText(
                            right.address
                        )
                end
            )

        while true do
            local options = {}

            for _, item in ipairs(entries) do
                local entry = item

                table.insert(
                    options,
                    {
                        label =
                            getDisplayName(entry)
                            .. "  "
                            .. safeText(
                                entry.address
                            ),

                        compactLabel =
                            getDisplayName(entry),

                        description =
                            safeText(
                                entry.type
                            )
                            .. " | "
                            .. safeText(
                                entry.region
                            ),

                        action = function()
                            deviceDetails(entry)
                        end
                    }
                )
            end

            if #options == 0 then
                table.insert(
                    options,
                    {
                        label =
                            "No archived devices",
                        disabled = true
                    }
                )
            end

            table.insert(
                options,
                {
                    label = "Back",
                    back = true
                }
            )

            local selected =
                menu.choose(
                    ui,
                    "Archived directory",
                    options,
                    getDevice(),
                    context.version
                )

            if selected.back then
                return
            end

            if selected.action then
                selected.action()
            end
        end
    end

    local function towerDetails(item)
        ui.drawHeader(
            "Archived tower",
            getDevice(),
            context.version
        )

        local network =
            item.network or {}

        print("")
        print(
            "Name: "
            .. getDisplayName(item)
        )

        print(
            "Address: "
            .. safeText(item.address)
        )

        print(
            "Status: "
            .. safeText(item.status)
        )

        print(
            "Region: "
            .. safeText(item.region)
        )

        print(
            "Endpoints: "
            .. tostring(
                network.localEndpoints
                or 0
            )
        )

        print(
            "Neighbours: "
            .. tostring(
                network.neighbours
                or 0
            )
        )

        print(
            "Forwarded: "
            .. tostring(
                network.counters
                and network
                    .counters
                    .framesForwarded
                or 0
            )
        )

        print(
            "Last seen: "
            .. formatDayTime(
                item.lastSeenDay,
                item.lastSeenTime
            )
        )

        ui.pause()
    end

    local function browseTowers()
        if not ensureArchive() then
            return
        end

        local entries =
            sortedValues(
                archive.towers,
                function(left, right)
                    return safeText(
                        left.address
                    )
                        < safeText(
                            right.address
                        )
                end
            )

        while true do
            local options = {}

            for _, item in ipairs(entries) do
                local entry = item

                table.insert(
                    options,
                    {
                        label =
                            getDisplayName(entry)
                            .. "  "
                            .. safeText(
                                entry.status
                            ),

                        compactLabel =
                            safeText(
                                entry.address
                            ),

                        description =
                            safeText(
                                entry.region
                            ),

                        action = function()
                            towerDetails(entry)
                        end
                    }
                )
            end

            if #options == 0 then
                table.insert(
                    options,
                    {
                        label =
                            "No archived towers",
                        disabled = true
                    }
                )
            end

            table.insert(
                options,
                {
                    label = "Back",
                    back = true
                }
            )

            local selected =
                menu.choose(
                    ui,
                    "Archived towers",
                    options,
                    getDevice(),
                    context.version
                )

            if selected.back then
                return
            end

            if selected.action then
                selected.action()
            end
        end
    end

    local function searchArchive()
        if not ensureArchive() then
            return
        end

        ui.restoreNative()
        term.clear()
        term.setCursorPos(1, 1)

        print("MCNet Archive Search")
        print("====================")
        print("")
        write("Search text: ")

        if term.setCursorBlink then
            term.setCursorBlink(true)
        end

        local query =
            string.lower(
                tostring(
                    read()
                    or ""
                )
            )

        if term.setCursorBlink then
            term.setCursorBlink(false)
        end

        ui.configure(
            context.settings
        )

        if query == "" then
            return
        end

        local results = {}

        local function matches(value)
            return string.find(
                string.lower(
                    safeText(value)
                ),
                query,
                1,
                true
            ) ~= nil
        end

        for _, item in ipairs(
            messageArray()
        ) do
            if matches(item.id)
                or matches(item.from)
                or matches(item.to)
                or matches(item.text) then

                local message = item

                results[#results + 1] = {
                    label =
                        "MESSAGE  "
                        .. trimText(
                            message.text,
                            28
                        ),

                    compactLabel =
                        "MSG "
                        .. trimText(
                            message.text,
                            14
                        ),

                    description =
                        safeText(message.from)
                        .. " -> "
                        .. safeText(message.to),

                    action = function()
                        messageDetails(message)
                    end
                }
            end
        end

        for _, item in ipairs(
            archive.events or {}
        ) do
            if matches(item.kind)
                or matches(item.source)
                or matches(item.message) then

                local event = item

                results[#results + 1] = {
                    label =
                        "EVENT  "
                        .. trimText(
                            event.message,
                            30
                        ),

                    compactLabel =
                        "EVT "
                        .. trimText(
                            event.kind,
                            12
                        ),

                    description =
                        safeText(event.source),

                    action = function()
                        eventDetails(event)
                    end
                }
            end
        end

        for _, item in pairs(
            archive.devices or {}
        ) do
            if matches(item.address)
                or matches(item.friendlyName)
                or matches(item.systemName)
                or matches(item.owner)
                or matches(item.region) then

                local entry = item

                results[#results + 1] = {
                    label =
                        "DEVICE  "
                        .. getDisplayName(entry),

                    compactLabel =
                        "DEV "
                        .. safeText(
                            entry.address
                        ),

                    description =
                        safeText(
                            entry.type
                        ),

                    action = function()
                        deviceDetails(entry)
                    end
                }
            end
        end

        if #results == 0 then
            results[#results + 1] = {
                label =
                    "No matching records",
                disabled = true
            }
        end

        results[#results + 1] = {
            label = "Back",
            back = true
        }

        while true do
            local selected =
                menu.choose(
                    ui,
                    "Archive search",
                    results,
                    getDevice(),
                    context.version
                )

            if selected.back then
                return
            end

            if selected.action then
                selected.action()
            end
        end
    end

    local function archiveSummary()
        if not ensureArchive() then
            ui.drawHeader(
                "Archive unavailable",
                getDevice(),
                context.version
            )

            print("")
            print(tostring(archiveError))
            ui.pause()
            return
        end

        local counts =
            archiveCounts(archive)

        local metadata =
            archive.metadata or {}

        local start =
            ui.drawHeader(
                "Archive summary",
                getDevice(),
                context.version
            )

        ui.printField(
            "Archive",
            metadata.archiveId
                or "UNKNOWN",
            start
        )

        ui.printField(
            "Messages",
            counts.messages,
            start + 1
        )

        ui.printField(
            "Events",
            counts.events,
            start + 2
        )

        ui.printField(
            "Devices",
            counts.devices,
            start + 3
        )

        ui.printField(
            "Towers",
            counts.towers,
            start + 4
        )

        local manifest =
            archive.manifest

        ui.printField(
            "Archive size",
            manifest
                and formatBytes(
                    manifest.totalBytes
                )
                or "UNKNOWN",
            start + 5
        )

        ui.printField(
            "Manifest",
            manifest
                and "VERIFIED"
                or "LEGACY / NONE",
            start + 6
        )

        print("")

        if counts.messages == 0
            and counts.events == 0 then

            print(
                "Snapshot archive:"
            )

            print(
                "no historical messages or events"
            )

            print(
                "were old enough to archive."
            )
        else
            print(
                "Historical records are available."
            )
        end

        ui.pause()
    end

    local function ejectDisk()
        ui.drawHeader(
            "Eject archive disk",
            getDevice(),
            context.version
        )

        print("")

        if not disk
            or not disk.isPresent
            or not disk.eject then

            print(
                "Disk eject API is unavailable."
            )
            ui.pause()
            return
        end

        if not disk.isPresent(
            DRIVE_SIDE
        ) then
            print(
                "No disk is inserted."
            )
            ui.pause()
            return
        end

        if not ui.askYesNo(
            "Eject archive disk?"
        ) then
            return
        end

        local success, reason =
            pcall(
                disk.eject,
                DRIVE_SIDE
            )

        archive = nil
        archiveError = nil
        mountPath = nil
        archivePath = nil

        print("")

        if success then
            print(
                "Archive disk ejected."
            )
        else
            print(
                "Could not eject disk:"
            )
            print(tostring(reason))
        end

        ui.pause()
    end

    while true do
        detectDisk()

        local counts =
            archiveCounts(archive)

        local diskDescription =
            archive
            and (
                "Verified "
                .. safeText(
                    archive.metadata
                    and archive
                        .metadata
                        .archiveId
                    or "archive"
                )
                .. " | "
                .. tostring(counts.messages)
                .. " messages | "
                .. tostring(counts.events)
                .. " events"
                .. (
                    archive.manifest
                    and (
                        " | "
                        .. formatBytes(
                            archive.manifest.totalBytes
                        )
                    )
                    or " | legacy"
                )
            )
            or tostring(
                archiveError
                or "No archive loaded"
            )

        local options = {
            {
                label =
                    "Archive information",

                description =
                    diskDescription,

                action =
                    archiveInformation
            },

            {
                label =
                    "Archive summary",

                description =
                    archive
                    and (
                        tostring(counts.messages)
                        .. " messages, "
                        .. tostring(counts.events)
                        .. " events, "
                        .. tostring(counts.devices)
                        .. " devices, "
                        .. tostring(counts.towers)
                        .. " towers"
                        .. (
                            archive.manifest
                            and (
                                ", "
                                .. formatBytes(
                                    archive.manifest.totalBytes
                                )
                                .. ", manifest verified."
                            )
                            or ", legacy archive."
                        )
                    )
                    or "Insert an MCNet archive disk.",

                disabled =
                    archive == nil,

                action =
                    archiveSummary
            },

            {
                label =
                    "Browse messages ("
                    .. tostring(counts.messages)
                    .. ")",

                description =
                    counts.messages > 0
                    and "Read archived mailbox records."
                    or "No archived messages on this snapshot disk.",

                disabled =
                    archive == nil,

                action =
                    browseMessages
            },

            {
                label =
                    "Browse events ("
                    .. tostring(counts.events)
                    .. ")",

                description =
                    counts.events > 0
                    and "Read archived Core Server events."
                    or "No archived events on this snapshot disk.",

                disabled =
                    archive == nil,

                action =
                    browseEvents
            },

            {
                label =
                    "Browse device history ("
                    .. tostring(counts.devices)
                    .. ")",

                description =
                    "Read the archived device directory.",

                disabled =
                    archive == nil,

                action =
                    browseDirectory
            },

            {
                label =
                    "Browse tower history ("
                    .. tostring(counts.towers)
                    .. ")",

                description =
                    "Read archived tower reports.",

                disabled =
                    archive == nil,

                action =
                    browseTowers
            },

            {
                label = "Search archive",

                description =
                    "Search messages, events and devices.",

                disabled =
                    archive == nil,

                action =
                    searchArchive
            },

            {
                label =
                    "Refresh disk",

                description =
                    "Reload the archive disk below this computer.",

                action = function()
                    detectDisk()
                end
            },

            {
                label =
                    "Eject disk",

                description =
                    "Safely eject the inserted archive disk.",

                action =
                    ejectDisk
            },

            {
                label =
                    "Open system console",

                description =
                    "Open installation and diagnostics.",

                action =
                    systemConsole
            },

            {
                label =
                    "Shut down reader",

                description =
                    "Power off the archive-reader computer.",

                action = function()
                    ui.drawHeader(
                        "Shut down",
                        getDevice(),
                        context.version
                    )

                    print("")

                    if ui.askYesNo(
                        "Shut down archive reader?"
                    ) then
                        ui.restoreNative()
                        os.shutdown()
                    end
                end
            }
        }

        local selected =
            menu.choose(
                ui,
                "MCNet Archive Reader",
                options,
                getDevice(),
                context.version
            )

        if selected.action then
            selected.action()
        end
    end
end

return application