-- MCNet railway station banner service
-- Version 0.9.2
--
-- Provides rotating station messages for railway display computers.
--
-- Categories:
--   EMERGENCY  - highest priority, intended for live overrides later
--   SERVICE    - operational/service information
--   SAFETY     - passenger safety notices
--   NEWS       - network/world development notices
--   ADVICE     - general passenger information
--   JOKE       - low-priority flavour messages
--
-- This file contains the default message library only.
-- Live station-specific warnings and service disruption messages will later
-- be injected by the station/rail-control services.

local module = {}

local messages = {
    -- ---------------------------------------------------------------------
    -- Safety
    -- ---------------------------------------------------------------------
    {
        id = "SAFETY-001",
        category = "SAFETY",
        priority = 30,
        text = "Please stand behind the yellow line."
    },
    {
        id = "SAFETY-002",
        category = "SAFETY",
        priority = 30,
        text = "Mind the gap between the train and the platform."
    },
    {
        id = "SAFETY-003",
        category = "SAFETY",
        priority = 30,
        text = "Please let passengers leave the train before boarding."
    },
    {
        id = "SAFETY-004",
        category = "SAFETY",
        priority = 30,
        text = "Keep platform entrances and exits clear."
    },
    {
        id = "SAFETY-005",
        category = "SAFETY",
        priority = 30,
        text = "Do not enter railway tunnels without authorisation."
    },
    {
        id = "SAFETY-006",
        category = "SAFETY",
        priority = 30,
        text = "Report damaged track or railway equipment to station control."
    },
    {
        id = "SAFETY-007",
        category = "SAFETY",
        priority = 30,
        text = "Keep tools, loose items and luggage away from the track."
    },
    {
        id = "SAFETY-008",
        category = "SAFETY",
        priority = 30,
        text = "Use the station crossing or underpass. Do not walk across live track."
    },
    {
        id = "SAFETY-009",
        category = "SAFETY",
        priority = 30,
        text = "In an emergency, follow instructions from MCNet Rail staff."
    },
    {
        id = "SAFETY-010",
        category = "SAFETY",
        priority = 30,
        text = "Keep back from the platform edge when a non-stop train is approaching."
    },

    -- ---------------------------------------------------------------------
    -- Service information
    -- ---------------------------------------------------------------------
    {
        id = "SERVICE-001",
        category = "SERVICE",
        priority = 20,
        text = "MCNet Rail services are operating normally."
    },
    {
        id = "SERVICE-002",
        category = "SERVICE",
        priority = 20,
        text = "Check the departure board for live platform and service information."
    },
    {
        id = "SERVICE-003",
        category = "SERVICE",
        priority = 20,
        text = "Some journeys may require a change at Central Station."
    },
    {
        id = "SERVICE-004",
        category = "SERVICE",
        priority = 20,
        text = "Express trains may pass through this station without stopping."
    },
    {
        id = "SERVICE-005",
        category = "SERVICE",
        priority = 20,
        text = "Platform assignments may change at short notice."
    },
    {
        id = "SERVICE-006",
        category = "SERVICE",
        priority = 20,
        text = "Maintenance and depot movements may operate between passenger services."
    },
    {
        id = "SERVICE-007",
        category = "SERVICE",
        priority = 20,
        text = "Allow extra journey time during severe weather."
    },
    {
        id = "SERVICE-008",
        category = "SERVICE",
        priority = 20,
        text = "MCNet communications may operate at reduced range during storms."
    },
    {
        id = "SERVICE-009",
        category = "SERVICE",
        priority = 20,
        text = "Delayed trains may be held to protect junctions and occupied track sections."
    },
    {
        id = "SERVICE-010",
        category = "SERVICE",
        priority = 20,
        text = "A cancelled stop may be used to recover a seriously delayed service."
    },

    -- ---------------------------------------------------------------------
    -- Passenger advice
    -- ---------------------------------------------------------------------
    {
        id = "ADVICE-001",
        category = "ADVICE",
        priority = 10,
        text = "Thank you for travelling with MCNet Rail."
    },
    {
        id = "ADVICE-002",
        category = "ADVICE",
        priority = 10,
        text = "Please take all belongings with you when leaving the train."
    },
    {
        id = "ADVICE-003",
        category = "ADVICE",
        priority = 10,
        text = "Keep your PDA charged before beginning a long journey."
    },
    {
        id = "ADVICE-004",
        category = "ADVICE",
        priority = 10,
        text = "Lost property should be reported to station control."
    },
    {
        id = "ADVICE-005",
        category = "ADVICE",
        priority = 10,
        text = "Maps and service information are available on station displays."
    },
    {
        id = "ADVICE-006",
        category = "ADVICE",
        priority = 10,
        text = "Please check your destination before boarding."
    },
    {
        id = "ADVICE-007",
        category = "ADVICE",
        priority = 10,
        text = "Changing lines is usually easier at a marked interchange station."
    },
    {
        id = "ADVICE-008",
        category = "ADVICE",
        priority = 10,
        text = "Freight and engineering trains may use the network outside normal service."
    },

    -- ---------------------------------------------------------------------
    -- Network news / world flavour
    -- ---------------------------------------------------------------------
    {
        id = "NEWS-001",
        category = "NEWS",
        priority = 10,
        text = "Construction of the ACME Electric Line is now under way."
    },
    {
        id = "NEWS-002",
        category = "NEWS",
        priority = 10,
        text = "ACME ESC will become the network's first purpose-built electric destination."
    },
    {
        id = "NEWS-003",
        category = "NEWS",
        priority = 10,
        text = "The Honey Line provides a direct service between Bee Gardens and Laboratories."
    },
    {
        id = "NEWS-004",
        category = "NEWS",
        priority = 10,
        text = "Little Mexico Express operates over a controlled single-track route."
    },
    {
        id = "NEWS-005",
        category = "NEWS",
        priority = 10,
        text = "New Egypt services connect the northern development to Central Station."
    },
    {
        id = "NEWS-006",
        category = "NEWS",
        priority = 10,
        text = "Depot trials are in progress. Expect occasional shunting movements."
    },
    {
        id = "NEWS-007",
        category = "NEWS",
        priority = 10,
        text = "MCNet Rail is expanding. New stations and routes will appear on network maps."
    },
    {
        id = "NEWS-008",
        category = "NEWS",
        priority = 10,
        text = "Bee Gardens continues its Forestry programme and tree-pollination work."
    },
    {
        id = "NEWS-009",
        category = "NEWS",
        priority = 10,
        text = "Atoll Reef improvement works are continuing around the harbour and village."
    },
    {
        id = "NEWS-010",
        category = "NEWS",
        priority = 10,
        text = "Laboratories remains the network centre for advanced bee-genetics research."
    },

    -- ---------------------------------------------------------------------
    -- Jokes / flavour
    -- ---------------------------------------------------------------------
    {
        id = "JOKE-001",
        category = "JOKE",
        priority = 0,
        text = "The train is not late. The timetable is merely ambitious."
    },
    {
        id = "JOKE-002",
        category = "JOKE",
        priority = 0,
        text = "MCNet Rail: considerably safer than walking through the Nether."
    },
    {
        id = "JOKE-003",
        category = "JOKE",
        priority = 0,
        text = "Delays caused by creepers are outside the timetable guarantee."
    },
    {
        id = "JOKE-004",
        category = "JOKE",
        priority = 0,
        text = "Unattended villagers may be promoted to station staff."
    },
    {
        id = "JOKE-005",
        category = "JOKE",
        priority = 0,
        text = "Our trains run on steam, redstone and excessive planning."
    },
    {
        id = "JOKE-006",
        category = "JOKE",
        priority = 0,
        text = "Please do not ask the locomotive whether we are there yet."
    },
    {
        id = "JOKE-007",
        category = "JOKE",
        priority = 0,
        text = "Next stop: probably the one printed on the departure board."
    },
    {
        id = "JOKE-008",
        category = "JOKE",
        priority = 0,
        text = "Bee Gardens passengers are reminded to mind the buzz."
    },
    {
        id = "JOKE-009",
        category = "JOKE",
        priority = 0,
        text = "ACME employees must declare rocket launchers before boarding."
    },
    {
        id = "JOKE-010",
        category = "JOKE",
        priority = 0,
        text = "If you can see the Lair on the public map, please report a software fault."
    },
    {
        id = "JOKE-011",
        category = "JOKE",
        priority = 0,
        text = "Rail replacement pig service is not currently available."
    },
    {
        id = "JOKE-012",
        category = "JOKE",
        priority = 0,
        text = "Please refrain from testing explosives inside station buildings."
    }
}

local DEFAULT_CATEGORIES = {
    EMERGENCY = true,
    SERVICE = true,
    SAFETY = true,
    NEWS = true,
    ADVICE = true,
    JOKE = true
}

local currentIndex = 0
local lastMessageId = nil

local function copyTable(source)
    local result = {}

    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            result[key] =
                copyTable(value)
        else
            result[key] =
                value
        end
    end

    return result
end

local function makeCategorySet(categories)
    if categories == nil then
        return copyTable(
            DEFAULT_CATEGORIES
        )
    end

    local result = {}

    if type(categories) == "table" then
        for key, value in pairs(categories) do
            if type(key) == "number" then
                result[
                    string.upper(
                        tostring(value)
                    )
                ] = true
            elseif value == true then
                result[
                    string.upper(
                        tostring(key)
                    )
                ] = true
            end
        end
    end

    return result
end

local function filteredMessages(categories)
    local enabled =
        makeCategorySet(
            categories
        )

    local result = {}

    for _, item in ipairs(messages) do
        if enabled[
            string.upper(
                tostring(
                    item.category
                )
            )
        ] then
            result[#result + 1] =
                item
        end
    end

    return result
end

function module.all(categories)
    local source =
        filteredMessages(
            categories
        )

    local result = {}

    for _, item in ipairs(source) do
        result[#result + 1] =
            copyTable(item)
    end

    return result
end

function module.count(categories)
    return #filteredMessages(
        categories
    )
end

function module.get(index, categories)
    local source =
        filteredMessages(
            categories
        )

    if #source == 0 then
        return nil
    end

    index =
        tonumber(index)
        or 1

    index =
        math.floor(index)

    index =
        (
            (index - 1)
            % #source
        ) + 1

    return copyTable(
        source[index]
    )
end

function module.text(index, categories)
    local item =
        module.get(
            index,
            categories
        )

    if not item then
        return ""
    end

    return tostring(
        item.text
        or ""
    )
end

function module.getNext(categories)
    local source =
        filteredMessages(
            categories
        )

    if #source == 0 then
        return nil
    end

    currentIndex =
        currentIndex + 1

    if currentIndex > #source then
        currentIndex = 1
    end

    local item =
        source[currentIndex]

    -- Avoid showing the same message twice in a row if the filtered set
    -- changes while displays are running.
    if #source > 1
        and item.id == lastMessageId then

        currentIndex =
            currentIndex + 1

        if currentIndex > #source then
            currentIndex = 1
        end

        item =
            source[currentIndex]
    end

    lastMessageId =
        item.id

    return copyTable(item)
end

function module.getByCategory(category)
    category =
        string.upper(
            tostring(
                category
                or ""
            )
        )

    return module.all(
        {
            [category] = true
        }
    )
end

function module.getById(id)
    id =
        string.upper(
            tostring(
                id
                or ""
            )
        )

    for _, item in ipairs(messages) do
        if string.upper(
            tostring(
                item.id
            )
        ) == id then

            return copyTable(item)
        end
    end

    return nil
end

function module.getCategories()
    return {
        "EMERGENCY",
        "SERVICE",
        "SAFETY",
        "NEWS",
        "ADVICE",
        "JOKE"
    }
end

function module.reset()
    currentIndex = 0
    lastMessageId = nil
end

return module