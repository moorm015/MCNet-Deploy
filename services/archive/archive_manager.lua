-- MCNet archive manager
-- Version 0.9.1
--
-- Detects a disk drive, monitors internal storage and writes verified,
-- self-contained archive disks.
--
-- This module never deletes live Core Server records. Safe pruning will be
-- connected separately after archive writing and verification are tested.

local module = {}

local DEFAULT_STATE_PATH = ".mcnet/archive_state.lua"
local DEFAULT_DRIVE_SIDE = "bottom"
local DEFAULT_ARCHIVE_FOLDER = "mcnet-archive"

local DEFAULT_WARNING_LEVEL = 0.80
local DEFAULT_REQUIRED_LEVEL = 0.90
local DEFAULT_ARCHIVE_LEVEL = 0.95

local ARCHIVE_FORMAT = 1

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

local function ensureDirectory(path)
    if not path or path == "" then
        return true
    end

    if fs.exists(path) then
        return fs.isDir(path)
    end

    local parent = fs.getDir(path)

    if parent ~= ""
        and parent ~= path
        and not fs.exists(parent) then

        local madeParent = ensureDirectory(parent)

        if not madeParent then
            return false
        end
    end

    fs.makeDir(path)
    return fs.exists(path) and fs.isDir(path)
end

local function readLuaFile(path)
    if type(path) ~= "string"
        or path == ""
        or not fs.exists(path)
        or fs.isDir(path) then

        return false, "File is unavailable"
    end

    local loaded, value = pcall(dofile, path)

    if not loaded then
        return false, tostring(value)
    end

    return true, value
end

local function serialiseValue(value)
    return "return "
        .. textutils.serialize(value)
        .. "\n"
end

local function writeTextFile(path, contents)
    local directory = fs.getDir(path)

    if directory ~= ""
        and not ensureDirectory(directory) then

        return false, "Could not create directory: "
            .. tostring(directory)
    end

    local file = fs.open(path, "w")

    if not file then
        return false, "Could not open file for writing: "
            .. tostring(path)
    end

    file.write(contents)
    file.close()

    return true
end

local function writeLuaFile(path, value)
    return writeTextFile(
        path,
        serialiseValue(value)
    )
end

local function writeAtomicLuaFile(path, value)
    local temporary = path .. ".tmp"

    if fs.exists(temporary) then
        fs.delete(temporary)
    end

    local written, reason =
        writeLuaFile(temporary, value)

    if not written then
        return false, reason
    end

    local verified, loaded =
        readLuaFile(temporary)

    if not verified
        or type(loaded) ~= type(value) then

        if fs.exists(temporary) then
            fs.delete(temporary)
        end

        return false,
            "Could not verify temporary file"
    end

    if fs.exists(path) then
        fs.delete(path)
    end

    fs.move(temporary, path)

    if not fs.exists(path) then
        return false,
            "Final file was not created"
    end

    return true
end

local function normaliseState(value)
    value = type(value) == "table"
        and value
        or {}

    if type(value.nextArchiveNumber) ~= "number"
        or value.nextArchiveNumber < 1 then

        value.nextArchiveNumber = 1
    end

    value.nextArchiveNumber =
        math.floor(value.nextArchiveNumber)

    if type(value.completedArchives) ~= "number"
        or value.completedArchives < 0 then

        value.completedArchives = 0
    end

    if type(value.lastArchive) ~= "table" then
        value.lastArchive = nil
    end

    return value
end

local function loadState(path)
    local loaded, value = readLuaFile(path)

    if not loaded then
        return normaliseState({})
    end

    return normaliseState(value)
end

local function formatArchiveID(number)
    number = math.max(
        1,
        math.floor(tonumber(number) or 1)
    )

    return string.format(
        "ARC-%04d",
        number
    )
end

local function getTimestamp()
    return {
        day = os.day and os.day() or 0,
        time = os.time and os.time() or 0,
        clock = os.clock and os.clock() or 0
    }
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

local function countArray(value)
    if type(value) ~= "table" then
        return 0
    end

    return #value
end

local function calculateOldestAndNewest(bundle)
    local oldestDay = nil
    local oldestTime = nil
    local newestDay = nil
    local newestTime = nil

    local function inspect(item)
        if type(item) ~= "table" then
            return
        end

        local day =
            tonumber(
                item.day
                or item.createdDay
                or item.deliveredDay
                or item.lastSeenDay
            )

        local time =
            tonumber(
                item.time
                or item.createdTime
                or item.deliveredTime
                or item.lastSeenTime
            ) or 0

        if not day then
            return
        end

        if not oldestDay
            or day < oldestDay
            or (
                day == oldestDay
                and time < oldestTime
            ) then

            oldestDay = day
            oldestTime = time
        end

        if not newestDay
            or day > newestDay
            or (
                day == newestDay
                and time > newestTime
            ) then

            newestDay = day
            newestTime = time
        end
    end

    for _, item in pairs(bundle.messages or {}) do
        inspect(item)
    end

    for _, item in pairs(bundle.events or {}) do
        inspect(item)
    end

    for _, item in pairs(bundle.devices or {}) do
        inspect(item)
    end

    for _, item in pairs(bundle.towers or {}) do
        inspect(item)
    end

    return {
        firstDay = oldestDay,
        firstTime = oldestTime,
        lastDay = newestDay,
        lastTime = newestTime
    }
end

local function directorySize(path, exclusions)
    if type(path) ~= "string"
        or not fs.exists(path) then

        return 0
    end

    exclusions = exclusions or {}

    local function isExcluded(currentPath)
        local normalised =
            tostring(currentPath or "")

        for _, excluded in ipairs(exclusions) do
            local excludedText =
                tostring(excluded or "")

            if excludedText ~= ""
                and (
                    normalised == excludedText
                    or string.sub(
                        normalised,
                        1,
                        #excludedText + 1
                    ) == excludedText .. "/"
                ) then

                return true
            end
        end

        return false
    end

    local function measure(currentPath)
        if isExcluded(currentPath) then
            return 0
        end

        if fs.isDir(currentPath) then
            local total = 0

            for _, name in ipairs(
                fs.list(currentPath)
            ) do
                total = total + measure(
                    combine(currentPath, name)
                )
            end

            return total
        end

        return tonumber(
            fs.getSize(currentPath)
        ) or 0
    end

    return measure(path)
end

local function storageStatus(
    used,
    total,
    warningLevel,
    requiredLevel,
    archiveLevel
)
    if not total or total <= 0 then
        return {
            used = used or 0,
            free = nil,
            total = nil,
            fraction = 0,
            percent = 0,
            level = "UNKNOWN",
            archiveRecommended = false,
            archiveRequired = false,
            archiveNow = false
        }
    end

    local fraction =
        math.max(
            0,
            math.min(
                1,
                (used or 0) / total
            )
        )

    local level = "NORMAL"

    if fraction >= archiveLevel then
        level = "CRITICAL"
    elseif fraction >= requiredLevel then
        level = "REQUIRED"
    elseif fraction >= warningLevel then
        level = "WARNING"
    end

    return {
        used = used or 0,
        free = math.max(
            0,
            total - (used or 0)
        ),
        total = total,
        fraction = fraction,
        percent = math.floor(
            fraction * 100
        ),
        level = level,
        archiveRecommended =
            fraction >= warningLevel,
        archiveRequired =
            fraction >= requiredLevel,
        archiveNow =
            fraction >= archiveLevel
    }
end

function module.new(config)
    config = type(config) == "table"
        and config
        or {}

    local manager = {}

    local driveSide =
        tostring(
            config.driveSide
            or DEFAULT_DRIVE_SIDE
        )

    local statePath =
        tostring(
            config.statePath
            or DEFAULT_STATE_PATH
        )

    local archiveFolder =
        tostring(
            config.archiveFolder
            or DEFAULT_ARCHIVE_FOLDER
        )

    local warningLevel =
        tonumber(config.warningLevel)
        or DEFAULT_WARNING_LEVEL

    local requiredLevel =
        tonumber(config.requiredLevel)
        or DEFAULT_REQUIRED_LEVEL

    local archiveLevel =
        tonumber(config.archiveLevel)
        or DEFAULT_ARCHIVE_LEVEL

    local serverAddress =
        tostring(
            config.serverAddress
            or "SRV-001"
        )

    local state = loadState(statePath)
    local lastStatus = nil

    local function saveState()
        return writeAtomicLuaFile(
            statePath,
            state
        )
    end

    local function detectDisk()
        local result = {
            side = driveSide,
            drivePresent = false,
            diskPresent = false,
            mountPath = nil,
            label = nil,
            archivePath = nil,
            archiveState = "NO_DRIVE",
            archiveMetadata = nil,
            writable = false,
            freeSpace = nil,
            reason = nil
        }

        if not peripheral
            or not peripheral.getType then

            result.reason =
                "Peripheral API is unavailable"

            return result
        end

        local peripheralType =
            peripheral.getType(driveSide)

        if peripheralType ~= "drive" then
            result.reason =
                "No disk drive on "
                .. driveSide

            return result
        end

        result.drivePresent = true
        result.archiveState = "NO_DISK"

        if not disk or not disk.isPresent then
            result.reason =
                "Disk API is unavailable"

            return result
        end

        local presentSuccess, present =
            pcall(
                disk.isPresent,
                driveSide
            )

        if not presentSuccess or not present then
            result.reason =
                "No disk inserted"

            return result
        end

        result.diskPresent = true

        if disk.getLabel then
            local labelSuccess, label =
                pcall(
                    disk.getLabel,
                    driveSide
                )

            if labelSuccess then
                result.label = label
            end
        end

        if not disk.getMountPath then
            result.archiveState = "UNMOUNTED"
            result.reason =
                "Disk mount API is unavailable"

            return result
        end

        local mountSuccess, mountPath =
            pcall(
                disk.getMountPath,
                driveSide
            )

        if not mountSuccess
            or type(mountPath) ~= "string"
            or mountPath == "" then

            result.archiveState = "UNMOUNTED"
            result.reason =
                "Disk is not mounted"

            return result
        end

        result.mountPath = mountPath
        result.archivePath =
            combine(
                mountPath,
                archiveFolder
            )

        local freeSpace =
            fs.getFreeSpace(mountPath)

        if type(freeSpace) == "number" then
            result.freeSpace = freeSpace
        end

        local testPath =
            combine(
                mountPath,
                ".mcnet-write-test"
            )

        local testFile =
            fs.open(testPath, "w")

        if testFile then
            testFile.write("MCNet")
            testFile.close()
            result.writable = true

            if fs.exists(testPath) then
                fs.delete(testPath)
            end
        else
            result.archiveState = "READ_ONLY"
            result.reason =
                "Disk is not writable"

            return result
        end

        local metadataPath =
            combine(
                result.archivePath,
                "archive.lua"
            )

        if not fs.exists(
            result.archivePath
        ) then
            result.archiveState = "BLANK"
            return result
        end

        if not fs.isDir(
            result.archivePath
        ) then
            result.archiveState = "INVALID"
            result.reason =
                "Archive path is not a directory"

            return result
        end

        if not fs.exists(metadataPath) then
            result.archiveState = "INCOMPLETE"
            result.reason =
                "Archive metadata is missing"

            return result
        end

        local metadataLoaded, metadata =
            readLuaFile(metadataPath)

        if not metadataLoaded
            or type(metadata) ~= "table" then

            result.archiveState = "INVALID"
            result.reason =
                "Archive metadata is invalid"

            return result
        end

        result.archiveMetadata = metadata

        if metadata.complete == true then
            result.archiveState =
                "COMPLETE_REMOVE"
        else
            result.archiveState =
                "INCOMPLETE"
        end

        return result
    end

    local function getInternalStorage()
        local diskInfo = detectDisk()
        local exclusions = { "rom" }

        if diskInfo.mountPath then
            exclusions[#exclusions + 1] =
                diskInfo.mountPath
        end

        local used =
            directorySize("", exclusions)

        local free =
            fs.getFreeSpace("")

        if type(free) ~= "number" then
            return storageStatus(
                used,
                nil,
                warningLevel,
                requiredLevel,
                archiveLevel
            )
        end

        return storageStatus(
            used,
            used + free,
            warningLevel,
            requiredLevel,
            archiveLevel
        )
    end

    local function getSuggestedAction(
        storage,
        diskInfo
    )
        if diskInfo.archiveState ==
            "COMPLETE_REMOVE" then

            return "REMOVE_ARCHIVE"
        end

        if diskInfo.archiveState ==
            "INCOMPLETE" then

            return "INSPECT_INCOMPLETE"
        end

        if storage.archiveNow then
            if diskInfo.archiveState ==
                "BLANK" then

                return "ARCHIVE_NOW"
            end

            return "INSERT_DISK"
        end

        if storage.archiveRequired then
            if diskInfo.archiveState ==
                "BLANK" then

                return "DISK_READY"
            end

            return "INSERT_DISK"
        end

        if storage.archiveRecommended then
            if diskInfo.archiveState ==
                "BLANK" then

                return "DISK_READY"
            end

            return "PREPARE_DISK"
        end

        if diskInfo.archiveState == "BLANK" then
            return "DISK_READY"
        end

        return "NONE"
    end

    function manager.refresh()
        local storage =
            getInternalStorage()

        local diskInfo =
            detectDisk()

        lastStatus = {
            storage = storage,
            disk = diskInfo,
            action = getSuggestedAction(
                storage,
                diskInfo
            ),
            nextArchiveId =
                formatArchiveID(
                    state.nextArchiveNumber
                ),
            completedArchives =
                state.completedArchives,
            lastArchive =
                deepCopy(state.lastArchive)
        }

        return deepCopy(lastStatus)
    end

    function manager.getStatus()
        if not lastStatus then
            manager.refresh()
        end

        return deepCopy(lastStatus)
    end

    function manager.getStorageStatus()
        return deepCopy(
            manager.getStatus().storage
        )
    end

    function manager.getDiskStatus()
        return deepCopy(
            manager.getStatus().disk
        )
    end

    function manager.getNextArchiveID()
        return formatArchiveID(
            state.nextArchiveNumber
        )
    end

    function manager.canArchive()
        local status = manager.refresh()
        local diskInfo = status.disk

        if not diskInfo.drivePresent then
            return false,
                "Archive drive is unavailable"
        end

        if not diskInfo.diskPresent then
            return false,
                "Insert an archive disk"
        end

        if not diskInfo.writable then
            return false,
                diskInfo.reason
                or "Disk is not writable"
        end

        if diskInfo.archiveState ==
            "COMPLETE_REMOVE" then

            return false,
                "Remove the completed archive disk"
        end

        if diskInfo.archiveState ~=
            "BLANK" then

            return false,
                "Disk is not blank: "
                .. tostring(
                    diskInfo.archiveState
                )
        end

        return true
    end

    function manager.createArchive(bundle)
        bundle = type(bundle) == "table"
            and deepCopy(bundle)
            or {}

        local canArchive, reason =
            manager.canArchive()

        if not canArchive then
            return false, reason
        end

        local diskInfo =
            manager.getDiskStatus()

        local archiveId =
            formatArchiveID(
                state.nextArchiveNumber
            )

        local archivePath =
            diskInfo.archivePath

        local stagingPath =
            archivePath .. ".writing"

        if fs.exists(stagingPath) then
            fs.delete(stagingPath)
        end

        if fs.exists(archivePath) then
            fs.delete(archivePath)
        end

        if not ensureDirectory(stagingPath) then
            return false,
                "Could not create archive staging folder"
        end

        local messages =
            type(bundle.messages) == "table"
            and bundle.messages
            or {}

        local events =
            type(bundle.events) == "table"
            and bundle.events
            or {}

        local devices =
            type(bundle.devices) == "table"
            and bundle.devices
            or {}

        local towers =
            type(bundle.towers) == "table"
            and bundle.towers
            or {}

        local ranges =
            calculateOldestAndNewest({
                messages = messages,
                events = events,
                devices = devices,
                towers = towers
            })

        local created = getTimestamp()

        local metadata = {
            format = ARCHIVE_FORMAT,
            archiveId = archiveId,
            server = serverAddress,
            createdDay = created.day,
            createdTime = created.time,

            firstRecordDay =
                ranges.firstDay,
            firstRecordTime =
                ranges.firstTime,

            lastRecordDay =
                ranges.lastDay,
            lastRecordTime =
                ranges.lastTime,

            messageCount =
                countTable(messages),

            eventCount =
                countArray(events),

            deviceCount =
                countTable(devices),

            towerCount =
                countTable(towers),

            complete = false,
            verified = false
        }

        local files = {
            {
                name = "archive.lua",
                value = metadata
            },
            {
                name = "messages.lua",
                value = messages
            },
            {
                name = "events.lua",
                value = events
            },
            {
                name = "directory.lua",
                value = devices
            },
            {
                name = "towers.lua",
                value = towers
            }
        }

        local requiredBytes = 0

        for _, entry in ipairs(files) do
            requiredBytes =
                requiredBytes
                + #serialiseValue(entry.value)
        end

        requiredBytes =
            requiredBytes + 4096

        if type(diskInfo.freeSpace) ==
                "number"
            and diskInfo.freeSpace <
                requiredBytes then

            fs.delete(stagingPath)

            return false,
                "Archive disk does not have enough space"
        end

        for _, entry in ipairs(files) do
            local path = combine(
                stagingPath,
                entry.name
            )

            local written, writeReason =
                writeLuaFile(
                    path,
                    entry.value
                )

            if not written then
                fs.delete(stagingPath)

                return false,
                    "Could not write "
                    .. entry.name
                    .. ": "
                    .. tostring(writeReason)
            end
        end

        local requiredFiles = {
            "archive.lua",
            "messages.lua",
            "events.lua",
            "directory.lua",
            "towers.lua"
        }

        for _, name in ipairs(
            requiredFiles
        ) do
            local path =
                combine(stagingPath, name)

            local loaded =
                readLuaFile(path)

            if not loaded then
                fs.delete(stagingPath)

                return false,
                    "Archive verification failed for "
                    .. name
            end
        end

        metadata.complete = true
        metadata.verified = true

        local metadataWritten,
            metadataReason =
            writeAtomicLuaFile(
                combine(
                    stagingPath,
                    "archive.lua"
                ),
                metadata
            )

        if not metadataWritten then
            fs.delete(stagingPath)

            return false,
                "Could not finalise archive metadata: "
                .. tostring(metadataReason)
        end

        fs.move(
            stagingPath,
            archivePath
        )

        local finalMetadataLoaded,
            finalMetadata =
            readLuaFile(
                combine(
                    archivePath,
                    "archive.lua"
                )
            )

        if not finalMetadataLoaded
            or type(finalMetadata) ~= "table"
            or finalMetadata.complete ~= true
            or finalMetadata.archiveId ~=
                archiveId then

            return false,
                "Final archive verification failed"
        end

        if disk and disk.setLabel then
            pcall(
                disk.setLabel,
                driveSide,
                "MCNet " .. archiveId
            )
        end

        state.lastArchive = {
            archiveId = archiveId,
            createdDay = created.day,
            createdTime = created.time,
            messageCount =
                metadata.messageCount,
            eventCount =
                metadata.eventCount
        }

        state.completedArchives =
            state.completedArchives + 1

        state.nextArchiveNumber =
            state.nextArchiveNumber + 1

        local stateSaved, stateReason =
            saveState()

        if not stateSaved then
            return false,
                "Archive was written, but local state could not be saved: "
                .. tostring(stateReason)
        end

        manager.refresh()

        return true,
            deepCopy(finalMetadata)
    end

    function manager.verifyInsertedArchive()
        local diskInfo =
            manager.refresh().disk

        if diskInfo.archiveState ~=
            "COMPLETE_REMOVE" then

            return false,
                "No completed archive disk is inserted"
        end

        local archivePath =
            diskInfo.archivePath

        local requiredFiles = {
            "archive.lua",
            "messages.lua",
            "events.lua",
            "directory.lua",
            "towers.lua"
        }

        for _, name in ipairs(
            requiredFiles
        ) do
            local loaded, value =
                readLuaFile(
                    combine(
                        archivePath,
                        name
                    )
                )

            if not loaded
                or type(value) ~= "table" then

                return false,
                    "Archive file failed verification: "
                    .. name
            end
        end

        return true,
            deepCopy(
                diskInfo.archiveMetadata
            )
    end

    function manager.ejectDisk()
        if not disk or not disk.eject then
            return false,
                "Disk eject API is unavailable"
        end

        local status =
            manager.refresh()

        if not status.disk.drivePresent then
            return false,
                "Archive drive is unavailable"
        end

        local success, reason =
            pcall(
                disk.eject,
                driveSide
            )

        if not success then
            return false,
                tostring(reason)
        end

        manager.refresh()
        return true
    end

    function manager.getDriveSide()
        return driveSide
    end

    function manager.getStatePath()
        return statePath
    end

    return manager
end

return module