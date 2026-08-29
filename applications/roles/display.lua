-- MCNet configurable multi-monitor display-wall application

-- Version 0.9.6
-- Banner word-wrap + station line-map + large network-map revision: 2026-08-29

--

-- One DISPLAY computer can drive several attached monitors.

-- Each monitor may independently show communications or railway information.

--

-- Railway data is loaded from services/trains when available.

-- Missing future services degrade to placeholders instead of crashing.

local application = {}

function application.run(context)

    local ui, menu = context.ui, context.menu

    local deviceModule, appManager = context.deviceModule, context.appManager

    local displayConfigModule = context.displayConfigModule

    local coreClient = context.coreClient

    local config = displayConfigModule.load()

    -- Be defensive with older, blank or partially-created display profiles.

    -- The modular installer deliberately preserves .mcnet/display.lua when a

    -- computer changes role, so the display application must tolerate a saved

    -- configuration that predates the current "screens" table.

    if type(config) ~= "table" then

        config = {}

    end

    if type(config.screens) ~= "table" then

        config.screens = {}

    end

    if type(config.refreshInterval) ~= "number" then

        config.refreshInterval = 2

    end

    local function loadOptional(path)

        if not fs.exists(path) then

            return nil

        end

        local ok, value = pcall(dofile, path)

        if ok and type(value) == "table" then

            return value

        end

        return nil

    end

    local railConfig =

        context.railConfig

        or loadOptional("services/trains/rail_config.lua")

    local railBanner =

        context.railBanner

        or loadOptional("services/trains/banner.lua")

    local railTimetable =

        context.railTimetable

        or loadOptional("services/trains/timetable.lua")

    -- Optional graphical tube-map renderer. If this file is absent (for
    -- example during a staged rollout), the older text-line rail map below
    -- remains available as a safe fallback.
    local networkMap =

        context.networkMap

        or loadOptional("services/trains/network_map.lua")

    local lineMap =

        context.lineMap

        or loadOptional("services/trains/line_map.lua")

    local fallbackBannerMessages = {

        "Please stand behind the yellow line.",

        "Mind the gap between train and platform.",

        "Thank you for travelling with MCNet Rail.",

        "Express trains may pass without stopping.",

        "Check departure boards before boarding.",

        "Please let passengers leave before boarding.",

        "Keep platform entrances clear.",

        "Report damaged railway equipment to station control.",

        "MCNet Rail: safer than walking through the Nether.",

        "Delays caused by creepers are outside the timetable guarantee.",

        "Unattended villagers may be promoted to station staff.",

        "Our trains run on steam, redstone and excessive planning."

    }

    -- Banner timing is deliberately independent from the display-wall refresh.
    -- A station sign may redraw every couple of seconds without selecting a
    -- new message every time it redraws.
    --
    -- Station-name boards use word wrapping rather than marquee scrolling:
    -- passengers should be able to glance at the board and read the complete
    -- notice without waiting for missing text to move into view.
    local BANNER_HOLD_SECONDS = 18

    -- One state per station means multiple signs for the same station remain
    -- synchronised while different stations can be at different points in the
    -- message sequence.
    local bannerStates = {}
    local fallbackBannerIndex = 0

    local function getDevice()

        return deviceModule.load(

            nil,

            context.version,

            context.protocol

        )

    end

    local function monitorNames()

        local result = {}

        if peripheral

            and peripheral.getNames then

            for _, name in ipairs(

                peripheral.getNames()

            ) do

                if peripheral.getType(name)

                    == "monitor" then

                    result[#result + 1] =

                        name

                end

            end

        end

        table.sort(result)

        return result

    end

    local function dashboardLabel(id)

        if displayConfigModule.getLabel then

            local ok, value =

                pcall(

                    displayConfigModule.getLabel,

                    id

                )

            if ok and value ~= nil then

                return tostring(value)

            end

        end

        if displayConfigModule.getDashboard then

            local ok, info =

                pcall(

                    displayConfigModule.getDashboard,

                    id

                )

            if ok and type(info) == "table" then

                if info.label ~= nil then

                    return tostring(info.label)

                end

                if info.name ~= nil then

                    return tostring(info.name)

                end

            end

        end

        return tostring(

            id

            or "UNASSIGNED"

        )

    end

    local function saveConfig()

        local saved, reason =

            displayConfigModule.save(

                config

            )

        if not saved then

            ui.drawHeader(

                "Display error",

                getDevice(),

                context.version

            )

            print("")

            print(tostring(reason))

            ui.pause()

        end

    end

    local function chooseDashboard()

        local categoryOptions = {}

        for _, value in ipairs(

            displayConfigModule.getCategories()

        ) do

            local category = value

            table.insert(

                categoryOptions,

                {

                    label = category,

                    compactLabel = category,

                    description =

                        "Choose a "

                        .. string.lower(category)

                        .. " dashboard.",

                    category = category

                }

            )

        end

        table.insert(

            categoryOptions,

            {

                label = "Cancel",

                back = true

            }

        )

        local selectedCategory =

            menu.choose(

                ui,

                "Display category",

                categoryOptions,

                getDevice(),

                context.version

            )

        if selectedCategory.back then

            return nil

        end

        local dashboardOptions = {}

        for _, item in ipairs(

            displayConfigModule.getDashboards(

                selectedCategory.category

            )

        ) do

            local entry = item

            table.insert(

                dashboardOptions,

                {

                    label = entry.label,

                    compactLabel =

                        entry.label,

                    description =

                        entry.description

                        or entry.id,

                    id = entry.id

                }

            )

        end

        table.insert(

            dashboardOptions,

            {

                label = "Back",

                back = true

            }

        )

        local selectedDashboard =

            menu.choose(

                ui,

                selectedCategory.category

                    .. " displays",

                dashboardOptions,

                getDevice(),

                context.version

            )

        if selectedDashboard.back then

            return nil

        end

        return selectedDashboard.id

    end

    local function chooseScale(current)

        local options = {}

        for _, value in ipairs(

            {

                0.5,

                1,

                1.5,

                2,

                2.5,

                3,

                4,

                5

            }

        ) do

            local scale = value

            table.insert(

                options,

                {

                    label =

                        tostring(scale),

                    value = scale

                }

            )

        end

        table.insert(

            options,

            {

                label = "Cancel",

                back = true

            }

        )

        local selected =

            menu.choose(

                ui,

                "Monitor text scale",

                options,

                getDevice(),

                context.version

            )

        return selected.back

            and current

            or selected.value

    end

    local function chooseStation(current)

        if not railConfig

            or not railConfig.getStations then

            ui.drawHeader(

                "Rail display",

                getDevice(),

                context.version

            )

            print("")

            print(

                "services/trains/rail_config.lua"

            )

            print("is not installed.")

            ui.pause()

            return current

        end

        local options = {}

        for _, station in ipairs(

            railConfig.getStations(false)

        ) do

            local item = station

            table.insert(

                options,

                {

                    label = item.name,

                    compactLabel =

                        item.shortName

                        or item.name,

                    description =

                        item.id,

                    id = item.id

                }

            )

        end

        table.insert(

            options,

            {

                label = "Cancel",

                back = true

            }

        )

        local selected =

            menu.choose(

                ui,

                "Select station",

                options,

                getDevice(),

                context.version

            )

        return selected.back

            and current

            or selected.id

    end

    local function choosePlatform(current)

        local options = {}

        -- Grand Central currently plans for six platforms.

        -- Smaller stations simply use the subset they physically have.

        for index = 1, 6 do

            local id =

                "P" .. tostring(index)

            table.insert(

                options,

                {

                    label =

                        "Platform "

                        .. tostring(index),

                    compactLabel = id,

                    id = id

                }

            )

        end

        table.insert(

            options,

            {

                label = "Cancel",

                back = true

            }

        )

        local selected =

            menu.choose(

                ui,

                "Select platform",

                options,

                getDevice(),

                context.version

            )

        return selected.back

            and current

            or selected.id

    end

    local function configureScreen(name)

        while true do

            local profile =

                config.screens[name]

            if not profile then

                if displayConfigModule.defaultProfile then

                    profile =

                        displayConfigModule.defaultProfile()

                else

                    profile = {

                        dashboard =

                            "communications.overview",

                        textScale = 0.5,

                        station = "CENTRAL",

                        platform = "P1"

                    }

                end

                config.screens[name] =

                    profile

            end

            local dashboardInfo =

                displayConfigModule.getDashboard

                and displayConfigModule.getDashboard(

                    profile.dashboard

                )

                or nil

            local needsStation =

                displayConfigModule.needsStation

                and displayConfigModule.needsStation(

                    profile.dashboard

                )

                or false

            local needsPlatform =

                displayConfigModule.needsPlatform

                and displayConfigModule.needsPlatform(

                    profile.dashboard

                )

                or false

            local options = {

                {

                    label =

                        "Dashboard: "

                        .. dashboardLabel(

                            profile.dashboard

                        ),

                    compactLabel = "Dashboard",

                    description =

                        dashboardInfo

                        and dashboardInfo.description

                        or profile.dashboard,

                    action = function()

                        local id =

                            chooseDashboard()

                        if id then

                            profile.dashboard = id

                            if displayConfigModule.needsStation

                                and displayConfigModule.needsStation(

                                    id

                                ) then

                                profile.station =

                                    chooseStation(

                                        profile.station

                                        or "CENTRAL"

                                    )

                            end

                            if displayConfigModule.needsPlatform

                                and displayConfigModule.needsPlatform(

                                    id

                                ) then

                                profile.platform =

                                    choosePlatform(

                                        profile.platform

                                        or "P1"

                                    )

                            end

                            config.screens[name] =

                                profile

                            saveConfig()

                        end

                    end

                }

            }

            if needsStation then

                local stationName =

                    profile.station

                    or "CENTRAL"

                if railConfig

                    and railConfig.getStationName then

                    stationName =

                        railConfig.getStationName(

                            profile.station

                            or "CENTRAL"

                        )

                end

                table.insert(

                    options,

                    {

                        label =

                            "Station: "

                            .. tostring(

                                stationName

                            ),

                        compactLabel = "Station",

                        description =

                            tostring(

                                profile.station

                                or "CENTRAL"

                            ),

                        action = function()

                            profile.station =

                                chooseStation(

                                    profile.station

                                    or "CENTRAL"

                                )

                            config.screens[name] =

                                profile

                            saveConfig()

                        end

                    }

                )

            end

            if needsPlatform then

                table.insert(

                    options,

                    {

                        label =

                            "Platform: "

                            .. tostring(

                                profile.platform

                                or "P1"

                            ),

                        compactLabel = "Platform",

                        description =

                            "Choose which platform this monitor belongs to.",

                        action = function()

                            profile.platform =

                                choosePlatform(

                                    profile.platform

                                    or "P1"

                                )

                            config.screens[name] =

                                profile

                            saveConfig()

                        end

                    }

                )

            end

            table.insert(

                options,

                {

                    label =

                        "Text scale: "

                        .. tostring(

                            profile.textScale

                        ),

                    compactLabel = "Scale",

                    action = function()

                        profile.textScale =

                            chooseScale(

                                profile.textScale

                            )

                        config.screens[name] =

                            profile

                        saveConfig()

                    end

                }

            )

            table.insert(

                options,

                {

                    label =

                        "Remove this screen",

                    compactLabel = "Remove",

                    action = function()

                        config.screens[name] =

                            nil

                        saveConfig()

                        return "removed"

                    end

                }

            )

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

                    "Screen " .. name,

                    options,

                    getDevice(),

                    context.version

                )

            if selected.back then

                return

            end

            local result =

                selected.action()

            if result == "removed" then

                return

            end

        end

    end

    local function configureScreens()

        while true do

            local options = {}

            for _, name in ipairs(

                monitorNames()

            ) do

                local profile =

                    config.screens[name]

                table.insert(

                    options,

                    {

                        label =

                            name

                            .. "  "

                            .. (

                                profile

                                and dashboardLabel(

                                    profile.dashboard

                                )

                                or "UNASSIGNED"

                            ),

                        compactLabel = name,

                        description =

                            profile

                            and profile.dashboard

                            or "Select a dashboard.",

                        name = name

                    }

                )

            end

            if #options == 0 then

                table.insert(

                    options,

                    {

                        label =

                            "No attached monitors",

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

                    "Configure screens",

                    options,

                    getDevice(),

                    context.version

                )

            if selected.back then

                return

            end

            configureScreen(

                selected.name

            )

        end

    end

    local function setColour(

        method,

        value

    )

        if term[method] then

            term[method](value)

        end

    end

    local function clearMonitor(title)

        setColour(

            "setBackgroundColor",

            colors.black

        )

        setColour(

            "setTextColor",

            colors.white

        )

        term.clear()

        local width =

            term.getSize()

        setColour(

            "setBackgroundColor",

            colors.green

        )

        setColour(

            "setTextColor",

            colors.black

        )

        term.setCursorPos(

            1,

            1

        )

        write(

            string.rep(

                " ",

                width

            )

        )

        term.setCursorPos(

            2,

            1

        )

        write(

            string.sub(

                "MCNet | "

                    .. tostring(

                        title

                        or "Display"

                    ),

                1,

                math.max(

                    0,

                    width - 2

                )

            )

        )

        setColour(

            "setBackgroundColor",

            colors.black

        )

        setColour(

            "setTextColor",

            colors.white

        )

    end

    local function line(

        y,

        left,

        right,

        rightColour

    )

        local width, height =

            term.getSize()

        if y > height then

            return

        end

        term.setCursorPos(

            2,

            y

        )

        setColour(

            "setTextColor",

            colors.lightGray

        )

        write(

            string.sub(

                tostring(

                    left or ""

                ),

                1,

                math.max(

                    0,

                    width - 3

                )

            )

        )

        if right ~= nil then

            local text =

                tostring(right)

            term.setCursorPos(

                math.max(

                    2,

                    width - #text

                ),

                y

            )

            setColour(

                "setTextColor",

                rightColour

                    or colors.white

            )

            write(text)

        end

    end

    local function centre(

        y,

        text,

        colour

    )

        local width, height =

            term.getSize()

        if y < 1

            or y > height then

            return

        end

        text =

            tostring(

                text or ""

            )

        if #text > width then

            text =

                string.sub(

                    text,

                    1,

                    width

                )

        end

        term.setCursorPos(

            math.max(

                1,

                math.floor(

                    (width - #text)

                    / 2

                ) + 1

            ),

            y

        )

        setColour(

            "setTextColor",

            colour or colors.white

        )

        write(text)

    end

    local function drawOverview(data)

        clearMonitor(

            "Communications Overview"

        )

        local totals =

            data.totals or {}

        local mailbox =

            data.mailbox or {}

        local stats =

            data.stats or {}

        line(

            3,

            "Core server",

            data.coreOnline

                and "ONLINE"

                or "OFFLINE",

            data.coreOnline

                and colors.lime

                or colors.red

        )

        line(

            5,

            "Towers",

            tostring(

                totals.towersOnline or 0

            )

                .. "/"

                .. tostring(

                    totals.towers or 0

                ),

            colors.lime

        )

        line(

            6,

            "Devices",

            tostring(

                totals.devicesOnline or 0

            )

                .. "/"

                .. tostring(

                    totals.devices or 0

                ),

            colors.lime

        )

        line(

            8,

            "Mailbox pending",

            mailbox.pending or 0,

            colors.yellow

        )

        line(

            9,

            "Mailbox delivered",

            stats.mailboxDelivered or 0,

            colors.cyan

        )

        line(

            11,

            "Heartbeats",

            stats.heartbeats or 0

        )

        line(

            12,

            "Snapshots",

            stats.snapshots or 0

        )

    end

    local function drawTowers(data)

        clearMonitor(

            "Tower Network"

        )

        local y = 3

        for _, tower in ipairs(

            data.towers or {}

        ) do

            local network =

                tower.network or {}

            local name =

                tower.friendlyName ~= ""

                and tower.friendlyName

                or tower.address

            line(

                y,

                name,

                tower.online

                    and "ONLINE"

                    or "OFFLINE",

                tower.online

                    and colors.lime

                    or colors.red

            )

            y = y + 1

            line(

                y,

                "  "

                    .. tostring(

                        tower.address

                    )

                    .. "  E:"

                    .. tostring(

                        network.localEndpoints

                        or 0

                    )

                    .. " N:"

                    .. tostring(

                        network.neighbours

                        or 0

                    )

            )

            y = y + 1

            local _, height =

                term.getSize()

            if y > height then

                break

            end

        end

    end

    local function drawDevices(data)

        clearMonitor(

            "Device Directory"

        )

        local y = 3

        for _, item in ipairs(

            data.devices or {}

        ) do

            local name =

                item.friendlyName ~= ""

                and item.friendlyName

                or item.address

            line(

                y,

                name

                    .. " ["

                    .. tostring(

                        item.type

                        or "DEVICE"

                    )

                    .. "]",

                item.online

                    and "ON"

                    or "OFF",

                item.online

                    and colors.lime

                    or colors.red

            )

            y = y + 1

            local _, height =

                term.getSize()

            if y > height then

                break

            end

        end

    end

    local function drawMailbox(data)

        clearMonitor(

            "Mailbox Service"

        )

        local mailbox =

            data.mailbox or {}

        local stats =

            data.stats or {}

        line(

            3,

            "Pending",

            mailbox.pending or 0,

            colors.yellow

        )

        line(

            4,

            "In transit",

            mailbox.sent or 0,

            colors.orange

        )

        line(

            5,

            "Delivered recently",

            mailbox.deliveredRecent or 0,

            colors.lime

        )

        line(

            7,

            "Stored total",

            stats.mailboxStored or 0

        )

        line(

            8,

            "Delivered total",

            stats.mailboxDelivered or 0

        )

        line(

            9,

            "Delivery attempts",

            stats.mailboxAttempts or 0

        )

    end

    local function drawFuture(

        title,

        description

    )

        clearMonitor(title)

        line(

            4,

            description,

            nil,

            colors.yellow

        )

        line(

            6,

            "The display profile is saved and will activate"

        )

        line(

            7,

            "when that MCNet service is installed."

        )

    end

    local function nextBannerMessage()
        if railBanner then
            if railBanner.getNext then
                local ok, item =
                    pcall(
                        railBanner.getNext
                    )

                if ok then
                    if type(item) == "table" then
                        local value =
                            tostring(
                                item.text or ""
                            )

                        if value ~= "" then
                            return value
                        end
                    elseif item ~= nil then
                        local value =
                            tostring(item)

                        if value ~= "" then
                            return value
                        end
                    end
                end
            end

            if railBanner.get then
                local ok, item =
                    pcall(
                        railBanner.get,
                        1
                    )

                if ok and item then
                    if type(item) == "table" then
                        local value =
                            tostring(
                                item.text or ""
                            )

                        if value ~= "" then
                            return value
                        end
                    else
                        local value =
                            tostring(item)

                        if value ~= "" then
                            return value
                        end
                    end
                end
            end

            if railBanner.text then
                local ok, value =
                    pcall(
                        railBanner.text,
                        1
                    )

                if ok
                    and value ~= nil
                    and tostring(value) ~= "" then

                    return tostring(value)
                end
            end
        end

        fallbackBannerIndex =
            fallbackBannerIndex + 1

        if fallbackBannerIndex
            > #fallbackBannerMessages then

            fallbackBannerIndex = 1
        end

        return fallbackBannerMessages[
            fallbackBannerIndex
        ]
    end

    local function getBannerMessage(profile)
        local stationKey =
            tostring(
                profile
                and profile.station
                or "CENTRAL"
            )

        local now =
            os.clock()

        local state =
            bannerStates[
                stationKey
            ]

        if not state
            or now >= state.expiresAt then

            state = {
                message =
                    nextBannerMessage(),

                expiresAt =
                    now
                    + BANNER_HOLD_SECONDS
            }

            bannerStates[
                stationKey
            ] = state
        end

        return tostring(
            state.message
            or ""
        )
    end

    local function splitLongWord(
        word,
        width
    )
        local parts = {}

        word =
            tostring(
                word or ""
            )

        width =
            math.max(
                1,
                math.floor(
                    tonumber(width)
                    or 1
                )
            )

        while #word > width do
            parts[#parts + 1] =
                string.sub(
                    word,
                    1,
                    width
                )

            word =
                string.sub(
                    word,
                    width + 1
                )
        end

        if word ~= "" then
            parts[#parts + 1] =
                word
        end

        return parts
    end

    local function wrapBannerMessage(
        message,
        width,
        maxLines
    )
        message =
            tostring(
                message or ""
            )

        message =
            string.gsub(
                message,
                "%s+",
                " "
            )

        message =
            string.gsub(
                message,
                "^%s+",
                ""
            )

        message =
            string.gsub(
                message,
                "%s+$",
                ""
            )

        width =
            math.max(
                1,
                math.floor(
                    tonumber(width)
                    or 1
                )
            )

        maxLines =
            math.max(
                1,
                math.floor(
                    tonumber(maxLines)
                    or 1
                )
            )

        if message == "" then
            return {
                ""
            }
        end

        local words = {}

        for word in string.gmatch(
            message,
            "%S+"
        ) do
            if #word <= width then
                words[#words + 1] =
                    word
            else
                local parts =
                    splitLongWord(
                        word,
                        width
                    )

                for _, part in ipairs(parts) do
                    words[#words + 1] =
                        part
                end
            end
        end

        local lines = {}
        local current = ""

        for _, word in ipairs(words) do
            local candidate =
                current == ""
                and word
                or (
                    current
                    .. " "
                    .. word
                )

            if #candidate <= width then
                current =
                    candidate
            else
                if current ~= "" then
                    lines[#lines + 1] =
                        current
                end

                current =
                    word
            end
        end

        if current ~= "" then
            lines[#lines + 1] =
                current
        end

        if #lines <= maxLines then
            return lines
        end

        -- The normal banner library is deliberately written to fit two lines
        -- on our station monitors. If a future live notice is exceptionally
        -- long, keep as much readable text as possible and mark truncation
        -- rather than reverting to a fast horizontal marquee.
        local result = {}

        for index = 1, maxLines do
            result[index] =
                lines[index]
                or ""
        end

        local final =
            result[maxLines]
            or ""

        if width >= 4 then
            final =
                string.sub(
                    final,
                    1,
                    math.max(
                        1,
                        width - 3
                    )
                )
                .. "..."
        else
            final =
                string.sub(
                    final,
                    1,
                    width
                )
        end

        result[maxLines] =
            final

        return result
    end

    local function drawStationSign(

        profile

    )

        if not railConfig then

            drawFuture(

                "Station Sign",

                "Rail configuration is not installed."

            )

            return

        end

        local station =

            railConfig.getStation(

                profile.station

                or "CENTRAL"

            )

        if not station then

            drawFuture(

                "Station Sign",

                "Unknown station: "

                    .. tostring(

                        profile.station

                    )

            )

            return

        end

        clearMonitor(

            "Station"

        )

        local width, height =

            term.getSize()

        centre(

            3,

            station.name,

            colors.white

        )

        local y = 5

        for _, lineInfo in ipairs(

            railConfig.getStationLines(

                station.id

            )

        ) do

            if lineInfo.public ~= false

                and y < height - 3 then

                centre(

                    y,

                    lineInfo.name,

                    lineInfo.colour

                        or colors.white

                )

                y = y + 1

            end

        end

        if height >= 8 then

            local available =

                math.max(

                    1,

                    width - 4

                )

            local message =

                getBannerMessage(

                    profile

                )

            local wrapped =

                wrapBannerMessage(

                    message,

                    available,

                    2

                )

            local firstRow =

                height
                - #wrapped

            for index, bannerLine in ipairs(

                wrapped

            ) do

                centre(

                    firstRow
                    + index
                    - 1,

                    bannerLine,

                    colors.yellow

                )

            end

        end

    end

    local function getDepartures(

        stationId,

        platformId

    )

        if not railTimetable then

            return nil

        end

        if platformId

            and railTimetable.getPlatformDepartures then

            local ok, result =

                pcall(

                    railTimetable.getPlatformDepartures,

                    stationId,

                    platformId

                )

            if ok

                and type(result)

                    == "table" then

                return result

            end

        end

        if railTimetable.getDepartures then

            local ok, result =

                pcall(

                    railTimetable.getDepartures,

                    stationId

                )

            if ok

                and type(result)

                    == "table" then

                return result

            end

        end

        return nil

    end

    local function drawDepartures(

        profile

    )

        if not railConfig then

            drawFuture(

                "Departures",

                "Rail configuration is not installed."

            )

            return

        end

        local station =

            railConfig.getStation(

                profile.station

                or "CENTRAL"

            )

        if not station then

            drawFuture(

                "Departures",

                "Unknown station."

            )

            return

        end

        clearMonitor(

            station.shortName

                or station.name

        )

        line(

            3,

            "Platform  Destination",

            "Due",

            colors.yellow

        )

        local departures =

            getDepartures(

                station.id

            )

        if not departures then

            line(

                5,

                "Timetable service not installed."

            )

            line(

                7,

                "Station:",

                station.name,

                colors.lime

            )

            return

        end

        local _, height =

            term.getSize()

        local y = 5

        for _, departure in ipairs(

            departures

        ) do

            if y > height then

                break

            end

            local due =

                departure.status

                and departure.status

                ~= "ON TIME"

                and departure.status

                or (

                    tostring(

                        departure.minutes

                        or "?"

                    )

                    .. "m"

                )

            local destination =

                tostring(

                    departure.destination

                    or "Unknown"

                )

            local platform =

                tostring(

                    departure.platform

                    or "-"

                )

            line(

                y,

                platform

                    .. "  "

                    .. destination,

                due,

                departure.status

                    == "CANCELLED"

                    and colors.red

                    or colors.lime

            )

            y = y + 1

        end

    end

    local function drawPlatform(

        profile

    )

        if not railConfig then

            drawFuture(

                "Platform",

                "Rail configuration is not installed."

            )

            return

        end

        local station =

            railConfig.getStation(

                profile.station

                or "CENTRAL"

            )

        if not station then

            drawFuture(

                "Platform",

                "Unknown station."

            )

            return

        end

        local platform =

            profile.platform

            or "P1"

        clearMonitor(

            station.shortName

                .. " "

                .. platform

        )

        local departures =

            getDepartures(

                station.id,

                platform

            )

        if not departures

            or #departures == 0 then

            centre(

                4,

                "No train data",

                colors.yellow

            )

            centre(

                6,

                station.name,

                colors.lightGray

            )

            return

        end

        local first =

            departures[1]

        local lineInfo =

            first.line

            and railConfig.getLine(

                first.line

            )

            or nil

        centre(

            3,

            lineInfo

                and lineInfo.name

                or tostring(

                    first.line

                    or "Service"

                ),

            lineInfo

                and lineInfo.colour

                or colors.white

        )

        centre(

            5,

            "to "

                .. tostring(

                    first.destination

                    or "Unknown"

                ),

            colors.white

        )

        local status =

            first.status

            and first.status

                ~= "ON TIME"

            and first.status

            or (

                tostring(

                    first.minutes

                    or "?"

                )

                .. " minutes"

            )

        centre(

            7,

            status,

            first.status

                == "CANCELLED"

                and colors.red

                or colors.yellow

        )

        local _, height =

            term.getSize()

        if first.callingAt

            and height >= 10 then

            line(

                9,

                "Calling at:"

            )

            local y = 10

            for _, stop in ipairs(

                first.callingAt

            ) do

                if y > height then

                    break

                end

                line(

                    y,

                    tostring(stop)

                )

                y = y + 1

            end

        end

    end

    local function plot(

        x,

        y,

        character,

        colour,

        background

    )

        local width, height =

            term.getSize()

        x =

            math.floor(

                tonumber(x) or 1

            )

        y =

            math.floor(

                tonumber(y) or 1

            )

        if x < 1

            or x > width

            or y < 1

            or y > height then

            return

        end

        setColour(

            "setTextColor",

            colour or colors.white

        )

        setColour(

            "setBackgroundColor",

            background or colors.black

        )

        term.setCursorPos(

            x,

            y

        )

        write(

            string.sub(

                tostring(

                    character

                    or " "

                ),

                1,

                1

            )

        )

        setColour(

            "setBackgroundColor",

            colors.black

        )

    end

    local function drawMapLine(

        x1,

        y1,

        x2,

        y2,

        colour

    )

        local dx =

            math.abs(

                x2 - x1

            )

        local dy =

            math.abs(

                y2 - y1

            )

        local sx =

            x1 < x2

            and 1

            or -1

        local sy =

            y1 < y2

            and 1

            or -1

        local err =

            dx - dy

        local x =

            x1

        local y =

            y1

        while true do

            local character = "."

            if x1 == x2 then

                character = "|"

            elseif y1 == y2 then

                character = "-"

            elseif (

                (x2 - x1)

                * (y2 - y1)

                > 0

            ) then

                character = "\\"

            else

                character = "/"

            end

            plot(

                x,

                y,

                character,

                colour

            )

            if x == x2

                and y == y2 then

                break

            end

            local e2 =

                2 * err

            if e2 > -dy then

                err =

                    err - dy

                x =

                    x + sx

            end

            if e2 < dx then

                err =

                    err + dx

                y =

                    y + sy

            end

        end

    end

    local function drawRailLineMap(

        profile

    )

        clearMonitor(

            "Station Line Map"

        )

        if not lineMap
            or not lineMap.draw then

            drawFuture(

                "Station Line Map",

                "Line-map renderer is not installed."

            )

            return

        end

        local ok, drawn =
            pcall(

                lineMap.draw,

                {
                    selectedStation =
                        profile.station
                        or "CENTRAL"
                }

            )

        if not ok
            or drawn == false then

            drawFuture(

                "Station Line Map",

                "Unable to render this line map."

            )

        end

    end

    local function drawRailMap(

        profile

    )

        -- Prefer the new ComputerCraft-native graphical map. It draws routes
        -- as filled colour cells, supports parallel shared corridors and uses
        -- explicit schematic geometry matching the approved network sketch.
        if networkMap
            and networkMap.draw then

            clearMonitor(

                "Rail Network Map"

            )

            local ok, drawn =
                pcall(

                    networkMap.draw,

                    {
                        selectedStation =
                            profile.station
                            or "CENTRAL"
                    }

                )

            if ok
                and drawn ~= false then

                return

            end

            -- If the optional renderer cannot draw on this monitor, retain
            -- the existing map below rather than taking the whole DISPLAY
            -- wall down.
        end

        if not railConfig then

            drawFuture(

                "Rail Network Map",

                "Rail configuration is not installed."

            )

            return

        end

        clearMonitor(

            "Rail Map"

        )

        local width, height =

            term.getSize()

        if width < 20

            or height < 8 then

            centre(

                4,

                "Monitor too small",

                colors.red

            )

            return

        end

        local bounds =

            railConfig.getMapBounds(

                false

            )

        local left = 2

        local right =

            math.max(

                left + 1,

                width - 2

            )

        local top = 3

        local bottom =

            math.max(

                top + 1,

                height - 2

            )

        local rangeX =

            math.max(

                1,

                bounds.maxX

                - bounds.minX

            )

        local rangeY =

            math.max(

                1,

                bounds.maxY

                - bounds.minY

            )

        local function screenPoint(

            mapX,

            mapY

        )

            local x =

                left

                + math.floor(

                    (

                        (

                            mapX

                            - bounds.minX

                        )

                        / rangeX

                    )

                    * (

                        right

                        - left

                    )

                )

            local y =

                top

                + math.floor(

                    (

                        (

                            mapY

                            - bounds.minY

                        )

                        / rangeY

                    )

                    * (

                        bottom

                        - top

                    )

                )

            return x, y

        end

        for _, segment in ipairs(

            railConfig.getMapSegments(

                false

            )

        ) do

            local fromStation =

                railConfig.getStation(

                    segment.from

                )

            local toStation =

                railConfig.getStation(

                    segment.to

                )

            local lineInfo =

                railConfig.getLine(

                    segment.line

                )

            if fromStation

                and toStation

                and lineInfo

                and fromStation.map

                and toStation.map then

                local x1, y1 =

                    screenPoint(

                        fromStation.map.x,

                        fromStation.map.y

                    )

                local x2, y2 =

                    screenPoint(

                        toStation.map.x,

                        toStation.map.y

                    )

                drawMapLine(

                    x1,

                    y1,

                    x2,

                    y2,

                    lineInfo.colour

                        or colors.white

                )

            end

        end

        local selectedStation =

            tostring(

                profile.station

                or "CENTRAL"

            )

        for _, station in ipairs(

            railConfig.getStations(

                false

            )

        ) do

            if station.map then

                local x, y =

                    screenPoint(

                        station.map.x,

                        station.map.y

                    )

                local selected =

                    station.id

                    == selectedStation

                plot(

                    x,

                    y,

                    selected

                        and "@"

                        or (

                            station.interchange

                            and "O"

                            or "o"

                        ),

                    selected

                        and colors.black

                        or colors.white,

                    selected

                        and colors.yellow

                        or colors.black

                )

                -- Label only when enough horizontal room exists.

                if width >= 40 then

                    local label =

                        station.shortName

                        or station.name

                    local available =

                        math.max(

                            0,

                            width - x - 2

                        )

                    if available > 1 then

                        setColour(

                            "setTextColor",

                            selected

                                and colors.yellow

                                or colors.lightGray

                        )

                        term.setCursorPos(

                            math.min(

                                width,

                                x + 2

                            ),

                            y

                        )

                        write(

                            string.sub(

                                label,

                                1,

                                available

                            )

                        )

                    end

                end

            end

        end

        if height >= 5 then

            local station =

                railConfig.getStation(

                    selectedStation

                )

            if station then

                centre(

                    height,

                    "You are here: "

                        .. station.name,

                    colors.yellow

                )

            end

        end

    end

    local function drawRailStatus()

        if not railConfig then

            drawFuture(

                "Rail Network Status",

                "Rail configuration is not installed."

            )

            return

        end

        clearMonitor(

            "Rail Network Status"

        )

        local y = 3

        local _, height =

            term.getSize()

        for _, lineInfo in ipairs(

            railConfig.getLines(

                false

            )

        ) do

            if y > height then

                break

            end

            local status =

                lineInfo.underConstruction

                and "BUILDING"

                or "PLANNED"

            line(

                y,

                lineInfo.name,

                status,

                lineInfo.underConstruction

                    and colors.yellow

                    or lineInfo.colour

            )

            y = y + 1

        end

    end

    local function drawDashboard(

        profile

    )

        local data =

            coreClient

            and coreClient.getSnapshot()

            or {

                coreOnline = false

            }

        if profile.dashboard

            == "communications.overview" then

            drawOverview(data)

        elseif profile.dashboard

            == "communications.towers" then

            drawTowers(data)

        elseif profile.dashboard

            == "communications.devices" then

            drawDevices(data)

        elseif profile.dashboard

            == "communications.mailbox" then

            drawMailbox(data)

        elseif profile.dashboard

            == "trains.station_sign" then

            drawStationSign(profile)

        elseif profile.dashboard

            == "trains.departures" then

            drawDepartures(profile)

        elseif profile.dashboard

            == "trains.platform" then

            drawPlatform(profile)

        elseif profile.dashboard

            == "trains.line_map" then

            drawRailLineMap(profile)

        elseif profile.dashboard

            == "trains.map" then

            drawRailMap(profile)

        elseif profile.dashboard

            == "trains.network_status" then

            drawRailStatus()

        elseif profile.dashboard

            == "trains.operations" then

            drawFuture(

                "Live Rail Operations",

                "Train tracking service is not installed yet."

            )

        elseif profile.dashboard

            == "power.overview" then

            drawFuture(

                "Power Overview",

                "Power telemetry is not installed yet."

            )

        else

            drawFuture(

                "Unknown Display",

                tostring(

                    profile.dashboard

                )

            )

        end

    end

    local function drawAll()

        for name, profile in pairs(

            config.screens or {}

        ) do

            if peripheral.getType(name)

                == "monitor" then

                local monitor =

                    peripheral.wrap(name)

                if monitor then

                    if monitor.setTextScale then

                        pcall(

                            function()

                                monitor.setTextScale(

                                    profile.textScale

                                    or 0.5

                                )

                            end

                        )

                    end

                    term.redirect(

                        monitor

                    )

                    local ok, reason =

                        pcall(

                            drawDashboard,

                            profile

                        )

                    ui.restoreNative()

                    if not ok then

                        -- Keep other monitors running if one renderer fails.

                        -- The failing monitor receives a small error screen.

                        term.redirect(

                            monitor

                        )

                        setColour(

                            "setBackgroundColor",

                            colors.black

                        )

                        setColour(

                            "setTextColor",

                            colors.red

                        )

                        term.clear()

                        term.setCursorPos(

                            1,

                            1

                        )

                        print(

                            "MCNet display error"

                        )

                        setColour(

                            "setTextColor",

                            colors.white

                        )

                        print(

                            tostring(reason)

                        )

                        ui.restoreNative()

                    end

                end

            end

        end

    end

    local function configuredMonitorCount()

        local count = 0

        for name, profile in pairs(

            config.screens or {}

        ) do

            if profile

                and peripheral.getType(name)

                    == "monitor" then

                count =

                    count + 1

            end

        end

        return count

    end

    local function runWall()

        local count =

            configuredMonitorCount()

        if count == 0 then

            ui.drawHeader(

                "Display wall",

                getDevice(),

                context.version

            )

            print("")

            print(

                "No monitor screens are configured."

            )

            print(

                "Use Configure screens first."

            )

            ui.pause()

            return

        end

        ui.restoreNative()

        term.clear()

        term.setCursorPos(

            1,

            1

        )

        print(

            "MCNet display wall running"

        )

        print(

            tostring(count)

                .. " configured screen(s)"

        )

        print("")

        print(

            "Q = return to configuration"

        )

        print(

            "S = shut down"

        )

        drawAll()

        local timer =

            os.startTimer(

                config.refreshInterval

                or 2

            )

        while true do

            local event = {

                os.pullEvent()

            }

            if event[1] == "timer"

                and event[2] == timer then

                drawAll()

                timer =

                    os.startTimer(

                        config.refreshInterval

                        or 2

                    )

            elseif event[1] == "char"

                and string.lower(

                    event[2]

                ) == "q" then

                ui.restoreNative()

                return

            elseif event[1] == "char"

                and string.lower(

                    event[2]

                ) == "s" then

                ui.restoreNative()

                os.shutdown()

            elseif event[1] == "peripheral"

                or event[1]

                    == "peripheral_detach" then

                drawAll()

            end

        end

    end

    local function systemConsole()

        local child = {}

        for key, value in pairs(

            context

        ) do

            child[key] =

                value

        end

        child.fromRole =

            true

        appManager.run(

            appManager.getSystemConsolePath(),

            child

        )

    end

    -- DISPLAY computers are appliances: once at least one attached monitor

    -- has a saved profile, start the wall automatically after MCNet boots.

    --

    -- Press Q while the wall is running to return to this configuration menu.

    -- If no configured monitor is currently attached, open the menu instead.

    if configuredMonitorCount() > 0 then

        runWall()

    end

    while true do

        ui.restoreNative()

        local options = {

            {

                label =

                    "Run display wall",

                description =

                    "Update every configured adjacent monitor.",

                action =

                    runWall

            },

            {

                label =

                    "Configure screens",

                description =

                    "Assign a dashboard, station and platform to each monitor.",

                action =

                    configureScreens

            },

            {

                label =

                    "Refresh interval: "

                    .. tostring(

                        config.refreshInterval

                    )

                    .. "s",

                description =

                    "Change how often live dashboards redraw.",

                action = function()

                    local values = {

                        1,

                        2,

                        3,

                        5,

                        10,

                        20,

                        30

                    }

                    local choices = {}

                    for _, value in ipairs(

                        values

                    ) do

                        local v = value

                        choices[

                            #choices + 1

                        ] = {

                            label =

                                tostring(v)

                                .. " seconds",

                            value = v

                        }

                    end

                    choices[

                        #choices + 1

                    ] = {

                        label = "Cancel",

                        back = true

                    }

                    local selected =

                        menu.choose(

                            ui,

                            "Refresh interval",

                            choices,

                            getDevice(),

                            context.version

                        )

                    if not selected.back then

                        config.refreshInterval =

                            selected.value

                        saveConfig()

                    end

                end

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

                    "Shut down display computer",

                action = function()

                    ui.restoreNative()

                    os.shutdown()

                end

            }

        }

        local selected =

            menu.choose(

                ui,

                "MCNet Display",

                options,

                getDevice(),

                context.version

            )

        selected.action()

    end

end

return application
