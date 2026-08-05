-- MCNet core server application
-- Version 0.9.1
--
-- Core directory, tower registry, mailbox and archive management UI.
-- Archive creation is transactional:
--   1. Core Server prepares a read-only bundle and token.
--   2. Archive Manager writes and verifies the disk.
--   3. Core Server commits the token and prunes only verified records.

local application = {}

local ARCHIVE_MANAGER_PATH =
    "services/archive/archive_manager.lua"

local ARCHIVE_RETAIN_DELIVERED = 50
local ARCHIVE_RETAIN_EVENTS = 200

local function copyTable(source)
    local result = {}

    for key, value in pairs(source or {}) do
        result[key] = value
    end

    return result
end

local function formatBytes(value)
    value = tonumber(value)

    if not value then
        return "UNKNOWN"
    end

    if value < 1024 then
        return tostring(math.floor(value)) .. " B"
    end

    if value < 1024 * 1024 then
        return string.format("%.1f KB", value / 1024)
    end

    return string.format("%.2f MB", value / (1024 * 1024))
end

local function archiveLevelText(level)
    level = tostring(level or "UNKNOWN")

    if level == "NORMAL" then
        return "NORMAL"
    elseif level == "WARNING" then
        return "ARCHIVE RECOMMENDED"
    elseif level == "REQUIRED" then
        return "ARCHIVE REQUIRED"
    elseif level == "CRITICAL" then
        return "ARCHIVE NOW"
    end

    return "UNKNOWN"
end

local function archiveDiskText(diskInfo)
    diskInfo =
        type(diskInfo) == "table"
        and diskInfo
        or {}

    local state =
        tostring(
            diskInfo.archiveState
            or "UNKNOWN"
        )

    if state == "NO_DRIVE" then
        return "NO DRIVE"
    elseif state == "NO_DISK" then
        return "NO DISK"
    elseif state == "UNMOUNTED" then
        return "UNMOUNTED"
    elseif state == "READ_ONLY" then
        return "READ ONLY"
    elseif state == "BLANK" then
        return "BLANK / READY"
    elseif state == "INCOMPLETE" then
        return "INCOMPLETE ARCHIVE"
    elseif state == "INVALID" then
        return "INVALID ARCHIVE"
    elseif state == "COMPLETE_REMOVE" then
        return "COMPLETE - REMOVE"
    end

    return state
end

local function archiveActionText(action)
    action = tostring(action or "NONE")

    if action == "REMOVE_ARCHIVE" then
        return "Remove completed archive disk"
    elseif action == "INSPECT_INCOMPLETE" then
        return "Inspect incomplete archive disk"
    elseif action == "ARCHIVE_NOW" then
        return "Archive immediately"
    elseif action == "INSERT_DISK" then
        return "Insert blank archive disk"
    elseif action == "DISK_READY" then
        return "Archive disk ready"
    elseif action == "PREPARE_DISK" then
        return "Prepare blank archive disk"
    end

    return "No archive action required"
end

function application.run(context)
    local ui = context.ui
    local menu = context.menu

    local deviceModule =
        context.deviceModule

    local appManager =
        context.appManager

    local coreServer =
        context.coreServer

    local archiveManager = nil
    local archiveLoadError = nil

    local function getDevice()
        return deviceModule.load(
            nil,
            context.version,
            context.protocol
        )
    end

    local function snapshot()
        if coreServer
            and coreServer.getSnapshot then

            return coreServer.getSnapshot()
        end

        return {
            devices = {},
            towers = {},
            events = {},
            totals = {},
            mailbox = {},
            stats = {}
        }
    end

    local function loadArchiveManager()
        if archiveManager then
            return archiveManager
        end

        if archiveLoadError then
            return nil
        end

        if not fs.exists(
            ARCHIVE_MANAGER_PATH
        ) then
            archiveLoadError =
                "Archive manager is not installed"

            return nil
        end

        local loaded,
            archiveModule =
            pcall(
                dofile,
                ARCHIVE_MANAGER_PATH
            )

        if not loaded then
            archiveLoadError =
                tostring(archiveModule)

            return nil
        end

        if type(archiveModule) ~= "table"
            or type(archiveModule.new)
                ~= "function" then

            archiveLoadError =
                "Archive manager module is invalid"

            return nil
        end

        local device = getDevice()

        local created,
            result =
            pcall(
                archiveModule.new,
                {
                    driveSide = "bottom",
                    serverAddress =
                        device.address
                        or "SRV-001",

                    warningLevel = 0.80,
                    requiredLevel = 0.90,
                    archiveLevel = 0.95,

                    mcnetVersion =
                        context.version,

                    protocol =
                        context.protocol
                }
            )

        if not created then
            archiveLoadError =
                tostring(result)

            return nil
        end

        archiveManager = result
        return archiveManager
    end

    local function getArchiveStatus()
        local manager =
            loadArchiveManager()

        if not manager then
            return nil,
                archiveLoadError
                or "Archive manager unavailable"
        end

        local refreshed,
            status =
            pcall(
                manager.refresh
            )

        if not refreshed then
            return nil,
                tostring(status)
        end

        return status
    end

    local function systemConsole()
        local child = copyTable(context)
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

    local function overview()
        local data = snapshot()
        local archiveStatus =
            getArchiveStatus()

        local start =
            ui.drawHeader(
                "MCNet Core",
                getDevice(),
                context.version
            )

        ui.printField(
            "Server",
            data.server
                and data.server.address
                or "UNKNOWN",
            start
        )

        ui.printField(
            "Devices online",
            tostring(
                data.totals.devicesOnline
                or 0
            )
                .. "/"
                .. tostring(
                    data.totals.devices
                    or 0
                ),
            start + 1
        )

        ui.printField(
            "Towers online",
            tostring(
                data.totals.towersOnline
                or 0
            )
                .. "/"
                .. tostring(
                    data.totals.towers
                    or 0
                ),
            start + 2
        )

        ui.printField(
            "Mailbox pending",
            data.mailbox.pending or 0,
            start + 3
        )

        ui.printField(
            "Mailbox sent",
            data.mailbox.sent or 0,
            start + 4
        )

        ui.printField(
            "Messages delivered",
            data.stats.mailboxDelivered
                or 0,
            start + 5
        )

        ui.printField(
            "Heartbeats",
            data.stats.heartbeats
                or 0,
            start + 6
        )

        ui.printField(
            "Snapshots",
            data.stats.snapshots
                or 0,
            start + 7
        )

        if archiveStatus
            and archiveStatus.storage then

            ui.printField(
                "Storage",
                tostring(
                    archiveStatus.storage.percent
                    or 0
                )
                    .. "% "
                    .. archiveLevelText(
                        archiveStatus.storage.level
                    ),
                start + 8
            )

            ui.printField(
                "Archive disk",
                archiveDiskText(
                    archiveStatus.disk
                ),
                start + 9
            )
        end

        ui.pause()
    end

    local function listPage(
        title,
        entries,
        label,
        detail
    )
        while true do
            local options = {}

            for _, entry in ipairs(
                entries()
            ) do
                local item = entry

                table.insert(
                    options,
                    {
                        label = label(item),

                        compactLabel =
                            item.friendlyName ~= ""
                            and item.friendlyName
                            or item.address,

                        description =
                            detail(item),

                        action = function()
                            ui.drawHeader(
                                title,
                                getDevice(),
                                context.version
                            )

                            print("")
                            print(detail(item))
                            ui.pause()
                        end
                    }
                )
            end

            if #options == 0 then
                table.insert(
                    options,
                    {
                        label = "No entries",
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
                    title,
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

    local function towers()
        listPage(
            "Tower registry",

            function()
                return snapshot().towers
                    or {}
            end,

            function(item)
                return item.address
                    .. "  "
                    .. (
                        item.online
                        and "ONLINE"
                        or "OFFLINE"
                    )
            end,

            function(item)
                local network =
                    item.network or {}

                return tostring(
                    item.friendlyName
                    or item.address
                )
                    .. " | "
                    .. (
                        item.online
                        and "ONLINE"
                        or "OFFLINE"
                    )
                    .. " | endpoints "
                    .. tostring(
                        network.localEndpoints
                        or 0
                    )
                    .. " | neighbours "
                    .. tostring(
                        network.neighbours
                        or 0
                    )
                    .. " | forwarded "
                    .. tostring(
                        network.counters
                        and network.counters.framesForwarded
                        or 0
                    )
            end
        )
    end

    local function devices()
        listPage(
            "Device directory",

            function()
                return snapshot().devices
                    or {}
            end,

            function(item)
                local name =
                    item.friendlyName ~= ""
                    and item.friendlyName
                    or item.address

                return name
                    .. "  "
                    .. (
                        item.online
                        and "ONLINE"
                        or "OFFLINE"
                    )
            end,

            function(item)
                return item.address
                    .. " | "
                    .. tostring(
                        item.type
                        or "DEVICE"
                    )
                    .. " | "
                    .. tostring(
                        item.region
                        or "UNKNOWN"
                    )
                    .. " | tower "
                    .. tostring(
                        item.selectedTower
                        or "NONE"
                    )
            end
        )
    end

    local function events()
        while true do
            local data =
                snapshot().events or {}

            local options = {}

            for index = #data,
                math.max(
                    1,
                    #data - 49
                ),
                -1 do

                local item =
                    data[index]

                table.insert(
                    options,
                    {
                        label =
                            tostring(item.kind)
                            .. "  "
                            .. tostring(
                                item.message
                            ),

                        compactLabel =
                            tostring(item.kind)
                            .. " "
                            .. tostring(
                                item.source
                                or ""
                            ),

                        description =
                            "Day "
                            .. tostring(item.day)
                            .. " time "
                            .. tostring(item.time),

                        action = function()
                            ui.drawHeader(
                                "Network event",
                                getDevice(),
                                context.version
                            )

                            print("")
                            print(
                                tostring(
                                    item.message
                                )
                            )
                            print("")
                            print(
                                "Source: "
                                .. tostring(
                                    item.source
                                    or "LOCAL"
                                )
                            )
                            ui.pause()
                        end
                    }
                )
            end

            if #options == 0 then
                table.insert(
                    options,
                    {
                        label =
                            "No events",
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
                    "Event log",
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

    local function archiveInformation()
        local status, reason =
            getArchiveStatus()

        local start =
            ui.drawHeader(
                "Archive status",
                getDevice(),
                context.version
            )

        if not status then
            print("")
            print(
                "Archive manager unavailable:"
            )
            print(tostring(reason))
            ui.pause()
            return
        end

        local storage =
            status.storage or {}

        local diskInfo =
            status.disk or {}

        ui.printField(
            "Storage used",
            formatBytes(storage.used),
            start
        )

        ui.printField(
            "Storage free",
            formatBytes(storage.free),
            start + 1
        )

        ui.printField(
            "Storage total",
            formatBytes(storage.total),
            start + 2
        )

        ui.printField(
            "Usage",
            tostring(storage.percent or 0)
                .. "%",
            start + 3
        )

        ui.printField(
            "Storage state",
            archiveLevelText(
                storage.level
            ),
            start + 4
        )

        ui.printField(
            "Drive side",
            tostring(
                diskInfo.side
                or "bottom"
            ),
            start + 5
        )

        ui.printField(
            "Disk",
            archiveDiskText(diskInfo),
            start + 6
        )

        ui.printField(
            "Disk free",
            formatBytes(
                diskInfo.freeSpace
            ),
            start + 7
        )

        ui.printField(
            "Next archive",
            tostring(
                status.nextArchiveId
                or "ARC-0001"
            ),
            start + 8
        )

        ui.printField(
            "Completed",
            tostring(
                status.completedArchives
                or 0
            ),
            start + 9
        )

        if type(status.lastArchive)
            == "table" then

            ui.printField(
                "Last archive",
                tostring(
                    status.lastArchive.archiveId
                    or "UNKNOWN"
                ),
                start + 10
            )

            ui.printField(
                "Last size",
                formatBytes(
                    status.lastArchive.totalBytes
                ),
                start + 11
            )
        end

        print("")
        print(
            archiveActionText(
                status.action
            )
        )

        if diskInfo.reason then
            print("")
            print(
                tostring(
                    diskInfo.reason
                )
            )
        end

        ui.pause()
    end

    local function archivePreview()
        local start =
            ui.drawHeader(
                "Archive preview",
                getDevice(),
                context.version
            )

        if not coreServer
            or not coreServer.getArchiveSummary then

            print("")
            print(
                "Core Server archive export is unavailable."
            )
            ui.pause()
            return
        end

        local summary =
            coreServer.getArchiveSummary({
                retainDelivered =
                    ARCHIVE_RETAIN_DELIVERED,

                retainEvents =
                    ARCHIVE_RETAIN_EVENTS
            })

        local deliveredTotal =
            tonumber(summary.deliveredTotal)
            or tonumber(summary.messagesRetained)
            or 0

        local messagesRetained =
            tonumber(summary.messagesRetained)
            or math.max(
                0,
                deliveredTotal
                - (
                    tonumber(summary.messagesEligible)
                    or tonumber(summary.messages)
                    or 0
                )
            )

        local messagesEligible =
            tonumber(summary.messagesEligible)
            or tonumber(summary.messages)
            or 0

        local deliveredLimit =
            tonumber(summary.deliveredRetentionLimit)
            or tonumber(summary.retainDelivered)
            or ARCHIVE_RETAIN_DELIVERED

        local eventsTotal =
            tonumber(summary.eventsTotal)
            or (
                (
                    tonumber(summary.eventsRetained)
                    or 0
                )
                + (
                    tonumber(summary.eventsEligible)
                    or tonumber(summary.events)
                    or 0
                )
            )

        local eventsRetained =
            tonumber(summary.eventsRetained)
            or math.max(
                0,
                eventsTotal
                - (
                    tonumber(summary.eventsEligible)
                    or tonumber(summary.events)
                    or 0
                )
            )

        local eventsEligible =
            tonumber(summary.eventsEligible)
            or tonumber(summary.events)
            or 0

        local eventLimit =
            tonumber(summary.eventRetentionLimit)
            or tonumber(summary.retainEvents)
            or ARCHIVE_RETAIN_EVENTS

        ui.printField(
            "Delivered total",
            deliveredTotal,
            start
        )

        ui.printField(
            "Messages retained",
            tostring(messagesRetained)
                .. "/"
                .. tostring(deliveredLimit),
            start + 1
        )

        ui.printField(
            "Messages ready",
            messagesEligible,
            start + 2
        )

        ui.printField(
            "Mailbox pending",
            tonumber(summary.mailboxPending)
                or 0,
            start + 3
        )

        ui.printField(
            "Mailbox sent",
            tonumber(summary.mailboxSent)
                or 0,
            start + 4
        )

        ui.printField(
            "Events total",
            eventsTotal,
            start + 5
        )

        ui.printField(
            "Events retained",
            tostring(eventsRetained)
                .. "/"
                .. tostring(eventLimit),
            start + 6
        )

        ui.printField(
            "Events ready",
            eventsEligible,
            start + 7
        )

        print("")

        if messagesEligible == 0
            and eventsEligible == 0 then

            print(
                "No old records are ready to archive."
            )
            print(
                "A snapshot archive can still be created."
            )
        else
            print(
                "Old records are ready for archiving."
            )
        end

        ui.pause()
    end

    local function createArchive()
        local manager =
            loadArchiveManager()

        ui.drawHeader(
            "Create archive",
            getDevice(),
            context.version
        )

        print("")

        if not manager then
            print(
                tostring(
                    archiveLoadError
                    or "Archive manager unavailable"
                )
            )
            ui.pause()
            return
        end

        if not coreServer
            or not coreServer.prepareArchive
            or not coreServer.commitArchive then

            print(
                "Core Server archive export is unavailable."
            )
            ui.pause()
            return
        end

        local canArchive, reason =
            manager.canArchive()

        if not canArchive then
            print(
                "Archive cannot start:"
            )
            print(tostring(reason))
            ui.pause()
            return
        end

        local prepared,
            bundle,
            token =
            coreServer.prepareArchive({
                retainDelivered =
                    ARCHIVE_RETAIN_DELIVERED,

                retainEvents =
                    ARCHIVE_RETAIN_EVENTS
            })

        if not prepared then
            print(
                "Could not prepare archive:"
            )
            print(tostring(bundle))
            ui.pause()
            return
        end

        local messageCount = 0

        for _ in pairs(
            bundle.messages or {}
        ) do
            messageCount =
                messageCount + 1
        end

        local eventCount =
            #(bundle.events or {})

        print(
            "Archive: "
            .. manager.getNextArchiveID()
        )

        print(
            "Messages: "
            .. tostring(messageCount)
        )

        print(
            "Events: "
            .. tostring(eventCount)
        )

        print("")

        if messageCount == 0
            and eventCount == 0 then

            print(
                "No old records need archiving."
            )
            print("")
            print(
                "A manual snapshot can still be created, but no live records will be pruned."
            )

            print("")

            if not ui.askYesNo(
                "Create snapshot archive?"
            ) then
                return
            end
        elseif not ui.askYesNo(
            "Write and verify archive?"
        ) then
            return
        end

        print("")
        print("Writing archive disk...")

        local written,
            archiveMetadata =
            manager.createArchive(bundle)

        if not written then
            print("")
            print(
                "Archive write failed:"
            )
            print(
                tostring(
                    archiveMetadata
                )
            )
            ui.pause()
            return
        end

        print(
            "Archive verified: "
            .. tostring(
                archiveMetadata.archiveId
                or "UNKNOWN"
            )
        )

        local manifest =
            type(archiveMetadata.manifest)
                == "table"
            and archiveMetadata.manifest
            or nil

        if manifest then
            print(
                "Manifest: VERIFIED"
            )

            print(
                "Archive size: "
                .. formatBytes(
                    manifest.totalBytes
                )
            )
        else
            print(
                "Manifest: LEGACY / NONE"
            )
        end

        print("")
        print(
            "Committing archived records..."
        )

        local committed,
            commitResult =
            coreServer.commitArchive(
                token,
                archiveMetadata
            )

        if not committed then
            print("")
            print(
                "The disk is safe and verified,"
            )
            print(
                "but live records were not pruned:"
            )
            print(tostring(commitResult))
            print("")
            print(
                "Do not overwrite this disk."
            )
            ui.pause()
            return
        end

        if coreServer.log then
            coreServer.log(
                "ARCHIVE",
                "Archive "
                    .. tostring(
                        archiveMetadata.archiveId
                        or "UNKNOWN"
                    )
                    .. " completed and verified",
                getDevice().address
            )
        end

        print("")
        print("Archive complete.")

        print(
            "MCNet: "
            .. tostring(
                archiveMetadata.mcnetVersion
                or context.version
                or "UNKNOWN"
            )
            .. " protocol "
            .. tostring(
                archiveMetadata.protocol
                or context.protocol
                or "UNKNOWN"
            )
        )

        if manifest then
            print(
                "Size: "
                .. formatBytes(
                    manifest.totalBytes
                )
            )
        end

        print(
            "Messages removed: "
            .. tostring(
                commitResult.messagesRemoved
                or 0
            )
        )
        print(
            "Events removed: "
            .. tostring(
                commitResult.eventsRemoved
                or 0
            )
        )
        print("")
        print(
            "Remove and store the archive disk."
        )

        manager.refresh()
        ui.pause()
    end

    local function ejectArchiveDisk()
        local manager =
            loadArchiveManager()

        if not manager then
            ui.drawHeader(
                "Archive error",
                getDevice(),
                context.version
            )

            print("")
            print(
                tostring(
                    archiveLoadError
                    or "Archive manager unavailable"
                )
            )
            ui.pause()
            return
        end

        local diskStatus =
            manager.refresh().disk

        ui.drawHeader(
            "Eject archive disk",
            getDevice(),
            context.version
        )

        print("")

        if not diskStatus.diskPresent then
            print(
                "No archive disk is inserted."
            )
            ui.pause()
            return
        end

        if diskStatus.archiveState
            ~= "COMPLETE_REMOVE" then

            print(
                "The inserted disk is not a completed archive."
            )
            print("")
            print(
                "Disk state: "
                .. archiveDiskText(
                    diskStatus
                )
            )
            ui.pause()
            return
        end

        print(
            "Archive: "
            .. tostring(
                diskStatus.archiveMetadata
                and diskStatus.archiveMetadata.archiveId
                or "UNKNOWN"
            )
        )

        print("")

        if not ui.askYesNo(
            "Eject completed archive?"
        ) then
            return
        end

        local ejected, reason =
            manager.ejectDisk()

        if ejected then
            print("")
            print(
                "Archive disk ejected."
            )
        else
            print("")
            print(
                "Could not eject disk:"
            )
            print(tostring(reason))
        end

        ui.pause()
    end

    local function archiveManagement()
        while true do
            local status =
                getArchiveStatus()

            local storageText =
                "Archive manager unavailable"

            local diskText =
                "UNKNOWN"

            local canCreate = false

            if status then
                storageText =
                    tostring(
                        status.storage.percent
                        or 0
                    )
                    .. "% - "
                    .. archiveLevelText(
                        status.storage.level
                    )

                diskText =
                    archiveDiskText(
                        status.disk
                    )

                canCreate =
                    status.disk.archiveState
                    == "BLANK"
            end

            local options = {
                {
                    label =
                        "Archive status",

                    description =
                        "Storage "
                        .. storageText
                        .. "; disk "
                        .. diskText
                        .. ".",

                    action =
                        archiveInformation
                },

                {
                    label =
                        "Archive preview",

                    description =
                        "Show how many old records are ready.",

                    action =
                        archivePreview
                },

                {
                    label =
                        "Create archive now",

                    description =
                        canCreate
                        and "Write, verify and safely prune old records."
                        or "Insert a blank writable disk below SRV-001.",

                    disabled =
                        not canCreate,

                    action =
                        createArchive
                },

                {
                    label =
                        "Refresh archive status",

                    description =
                        "Recheck storage and the bottom disk drive.",

                    action = function()
                        local manager =
                            loadArchiveManager()

                        if manager then
                            manager.refresh()
                        end
                    end
                },

                {
                    label =
                        "Eject completed archive",

                    description =
                        "Safely eject a verified completed archive disk.",

                    action =
                        ejectArchiveDisk
                },

                {
                    label = "Back",
                    back = true
                }
            }

            local selected =
                menu.choose(
                    ui,
                    "Archive Management",
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

    while true do
        local archiveStatus =
            getArchiveStatus()

        local archiveDescription =
            "Archive storage and disk management."

        if archiveStatus then
            archiveDescription =
                "Storage "
                .. tostring(
                    archiveStatus.storage.percent
                    or 0
                )
                .. "%; "
                .. archiveActionText(
                    archiveStatus.action
                )
                .. "."
        end

        local options = {
            {
                label =
                    "Core overview",

                description =
                    "Show directory, towers and mailbox totals.",

                action = overview
            },

            {
                label =
                    "Tower registry",

                description =
                    "Show live and offline tower reports.",

                action = towers
            },

            {
                label =
                    "Device directory",

                description =
                    "Show every registered MCNet device.",

                action = devices
            },

            {
                label =
                    "Event log",

                description =
                    "Show online, offline and mailbox activity.",

                action = events
            },

            {
                label =
                    "Archive management",

                description =
                    archiveDescription,

                action =
                    archiveManagement
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
                    "Shut down core server",

                description =
                    "Stop directory and mailbox services.",

                action = function()
                    ui.drawHeader(
                        "Shut down",
                        getDevice(),
                        context.version
                    )

                    print("")

                    if ui.askYesNo(
                        "Shut down SRV-001?"
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
                "MCNet Core Server",
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