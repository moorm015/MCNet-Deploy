-- MCNet railway station banner service
-- Version 0.9.3
--
-- Provides rotating station messages for railway display computers.
--
-- Categories:
--   EMERGENCY  - reserved for live overrides later
--   SERVICE    - operational/service information
--   SAFETY     - passenger safety notices
--   NEWS       - network/world development notices
--   ADVICE     - general passenger information
--   JOKE       - low-priority flavour messages
--
-- v0.9.3:
--   * Greatly expanded default message library.
--   * Banner selection is now weighted/random rather than a fixed loop.
--   * Rare and very-rare messages occasionally appear as surprises.
--   * Immediate repeats are avoided.
--   * Existing public API remains compatible with v0.9.2.
--
-- Live station-specific warnings and service disruption messages will later
-- be injected by the station/rail-control services.

local module = {}

local messages = {
    -- =====================================================================
    -- Safety
    -- =====================================================================
    {
        id = "SAFETY-001",
        category = "SAFETY",
        priority = 30,
        weight = 10,
        text = "Please stand behind the yellow line."
    },
    {
        id = "SAFETY-002",
        category = "SAFETY",
        priority = 30,
        weight = 10,
        text = "Mind the gap between the train and the platform."
    },
    {
        id = "SAFETY-003",
        category = "SAFETY",
        priority = 30,
        weight = 9,
        text = "Please let passengers leave the train before boarding."
    },
    {
        id = "SAFETY-004",
        category = "SAFETY",
        priority = 30,
        weight = 9,
        text = "Keep platform entrances and exits clear."
    },
    {
        id = "SAFETY-005",
        category = "SAFETY",
        priority = 30,
        weight = 8,
        text = "Do not enter railway tunnels without authorisation."
    },
    {
        id = "SAFETY-006",
        category = "SAFETY",
        priority = 30,
        weight = 7,
        text = "Report damaged track or railway equipment to station control."
    },
    {
        id = "SAFETY-007",
        category = "SAFETY",
        priority = 30,
        weight = 7,
        text = "Keep tools, loose items and luggage away from the track."
    },
    {
        id = "SAFETY-008",
        category = "SAFETY",
        priority = 30,
        weight = 7,
        text = "Use the station crossing or underpass. Do not walk across live track."
    },
    {
        id = "SAFETY-009",
        category = "SAFETY",
        priority = 30,
        weight = 7,
        text = "In an emergency, follow instructions from MCNet Rail staff."
    },
    {
        id = "SAFETY-010",
        category = "SAFETY",
        priority = 30,
        weight = 8,
        text = "Keep back from the platform edge when a non-stop train is approaching."
    },
    {
        id = "SAFETY-011",
        category = "SAFETY",
        priority = 30,
        weight = 7,
        text = "Please keep minecarts, animals and loose blocks away from the platform edge."
    },
    {
        id = "SAFETY-012",
        category = "SAFETY",
        priority = 30,
        weight = 7,
        text = "Do not obstruct locking tracks, detectors or railway signals."
    },
    {
        id = "SAFETY-013",
        category = "SAFETY",
        priority = 30,
        weight = 6,
        text = "Passengers should remain clear of engineering trains and maintenance vehicles."
    },
    {
        id = "SAFETY-014",
        category = "SAFETY",
        priority = 30,
        weight = 6,
        text = "If you drop an item onto the track, contact station control. Do not retrieve it yourself."
    },
    {
        id = "SAFETY-015",
        category = "SAFETY",
        priority = 30,
        weight = 6,
        text = "Keep redstone equipment clear of station walkways."
    },
    {
        id = "SAFETY-016",
        category = "SAFETY",
        priority = 30,
        weight = 5,
        text = "Do not board a train once the departure sequence has started."
    },
    {
        id = "SAFETY-017",
        category = "SAFETY",
        priority = 30,
        weight = 5,
        text = "Please supervise villagers, pets and small slimes while on the platform."
    },
    {
        id = "SAFETY-018",
        category = "SAFETY",
        priority = 30,
        weight = 5,
        text = "Keep clear of points and junction equipment. Routes may change without warning."
    },
    {
        id = "SAFETY-019",
        category = "SAFETY",
        priority = 30,
        weight = 5,
        text = "Never place blocks, torches or decorative items on operational track."
    },
    {
        id = "SAFETY-020",
        category = "SAFETY",
        priority = 30,
        weight = 4,
        text = "If a train is held unexpectedly, remain on board unless instructed otherwise."
    },

    -- =====================================================================
    -- Service information
    -- =====================================================================
    {
        id = "SERVICE-001",
        category = "SERVICE",
        priority = 20,
        weight = 9,
        text = "MCNet Rail services are operating normally."
    },
    {
        id = "SERVICE-002",
        category = "SERVICE",
        priority = 20,
        weight = 9,
        text = "Check the departure board for live platform and service information."
    },
    {
        id = "SERVICE-003",
        category = "SERVICE",
        priority = 20,
        weight = 8,
        text = "Some journeys may require a change at Central Station."
    },
    {
        id = "SERVICE-004",
        category = "SERVICE",
        priority = 20,
        weight = 8,
        text = "Express trains may pass through this station without stopping."
    },
    {
        id = "SERVICE-005",
        category = "SERVICE",
        priority = 20,
        weight = 7,
        text = "Platform assignments may change at short notice."
    },
    {
        id = "SERVICE-006",
        category = "SERVICE",
        priority = 20,
        weight = 6,
        text = "Maintenance and depot movements may operate between passenger services."
    },
    {
        id = "SERVICE-007",
        category = "SERVICE",
        priority = 20,
        weight = 6,
        text = "Allow extra journey time during severe weather."
    },
    {
        id = "SERVICE-008",
        category = "SERVICE",
        priority = 20,
        weight = 6,
        text = "MCNet communications may operate at reduced range during storms."
    },
    {
        id = "SERVICE-009",
        category = "SERVICE",
        priority = 20,
        weight = 5,
        text = "Delayed trains may be held to protect junctions and occupied track sections."
    },
    {
        id = "SERVICE-010",
        category = "SERVICE",
        priority = 20,
        weight = 5,
        text = "A cancelled stop may be used to recover a seriously delayed service."
    },
    {
        id = "SERVICE-011",
        category = "SERVICE",
        priority = 20,
        weight = 7,
        text = "Circle Line trains operate in both clockwise and anticlockwise directions."
    },
    {
        id = "SERVICE-012",
        category = "SERVICE",
        priority = 20,
        weight = 6,
        text = "The Honey Line provides a shortcut between Bee Gardens and Laboratories."
    },
    {
        id = "SERVICE-013",
        category = "SERVICE",
        priority = 20,
        weight = 6,
        text = "Little Mexico Express services connect with the Eastern Line at Eastern Village."
    },
    {
        id = "SERVICE-014",
        category = "SERVICE",
        priority = 20,
        weight = 5,
        text = "Central Line services run north from Central Station towards The Spa and New Egypt."
    },
    {
        id = "SERVICE-015",
        category = "SERVICE",
        priority = 20,
        weight = 5,
        text = "Eastern Line services connect Central Station, Half Wall and Eastern Village."
    },
    {
        id = "SERVICE-016",
        category = "SERVICE",
        priority = 20,
        weight = 5,
        text = "ACME Electric Line services are subject to commissioning and construction progress."
    },
    {
        id = "SERVICE-017",
        category = "SERVICE",
        priority = 20,
        weight = 4,
        text = "A held train may be waiting for a clear platform, junction or track section."
    },
    {
        id = "SERVICE-018",
        category = "SERVICE",
        priority = 20,
        weight = 4,
        text = "Passenger information is generated by MCNet. Please report obviously impossible destinations."
    },
    {
        id = "SERVICE-019",
        category = "SERVICE",
        priority = 20,
        weight = 4,
        text = "Timetable information is provisional while the network remains under development."
    },
    {
        id = "SERVICE-020",
        category = "SERVICE",
        priority = 20,
        weight = 4,
        text = "Network expansion works may result in temporary route changes."
    },
    {
        id = "SERVICE-021",
        category = "SERVICE",
        priority = 20,
        weight = 4,
        text = "Trains may be held briefly while a route is proved clear."
    },
    {
        id = "SERVICE-022",
        category = "SERVICE",
        priority = 20,
        weight = 4,
        text = "Please check line and destination information before joining an express service."
    },
    {
        id = "SERVICE-023",
        category = "SERVICE",
        priority = 20,
        weight = 3,
        text = "Some engineering trains are not shown on passenger departure boards."
    },
    {
        id = "SERVICE-024",
        category = "SERVICE",
        priority = 20,
        weight = 3,
        text = "Short notice alterations may occur while signalling equipment is being commissioned."
    },
    {
        id = "SERVICE-025",
        category = "SERVICE",
        priority = 20,
        weight = 3,
        text = "MCNet Rail control prioritises a safe route over an ambitious timetable."
    },

    -- =====================================================================
    -- Passenger advice
    -- =====================================================================
    {
        id = "ADVICE-001",
        category = "ADVICE",
        priority = 10,
        weight = 8,
        text = "Thank you for travelling with MCNet Rail."
    },
    {
        id = "ADVICE-002",
        category = "ADVICE",
        priority = 10,
        weight = 8,
        text = "Please take all belongings with you when leaving the train."
    },
    {
        id = "ADVICE-003",
        category = "ADVICE",
        priority = 10,
        weight = 6,
        text = "Keep your PDA charged before beginning a long journey."
    },
    {
        id = "ADVICE-004",
        category = "ADVICE",
        priority = 10,
        weight = 6,
        text = "Lost property should be reported to station control."
    },
    {
        id = "ADVICE-005",
        category = "ADVICE",
        priority = 10,
        weight = 7,
        text = "Maps and service information are available on station displays."
    },
    {
        id = "ADVICE-006",
        category = "ADVICE",
        priority = 10,
        weight = 7,
        text = "Please check your destination before boarding."
    },
    {
        id = "ADVICE-007",
        category = "ADVICE",
        priority = 10,
        weight = 5,
        text = "Changing lines is usually easier at a marked interchange station."
    },
    {
        id = "ADVICE-008",
        category = "ADVICE",
        priority = 10,
        weight = 5,
        text = "Freight and engineering trains may use the network outside normal service."
    },
    {
        id = "ADVICE-009",
        category = "ADVICE",
        priority = 10,
        weight = 5,
        text = "For the shortest route, check the network map before setting out."
    },
    {
        id = "ADVICE-010",
        category = "ADVICE",
        priority = 10,
        weight = 5,
        text = "If you miss your train, another one will probably exist eventually."
    },
    {
        id = "ADVICE-011",
        category = "ADVICE",
        priority = 10,
        weight = 4,
        text = "Please move along the platform to make boarding easier."
    },
    {
        id = "ADVICE-012",
        category = "ADVICE",
        priority = 10,
        weight = 4,
        text = "Allow passengers to clear doorways before attempting to board."
    },
    {
        id = "ADVICE-013",
        category = "ADVICE",
        priority = 10,
        weight = 4,
        text = "Check whether your train is clockwise, anticlockwise, inbound or outbound."
    },
    {
        id = "ADVICE-014",
        category = "ADVICE",
        priority = 10,
        weight = 4,
        text = "If travelling to Little Mexico, change at Eastern Village."
    },
    {
        id = "ADVICE-015",
        category = "ADVICE",
        priority = 10,
        weight = 4,
        text = "For Bee Gardens and Laboratories, the Honey Line may save time."
    },
    {
        id = "ADVICE-016",
        category = "ADVICE",
        priority = 10,
        weight = 3,
        text = "Keep food, drinks and suspicious potions securely contained while travelling."
    },
    {
        id = "ADVICE-017",
        category = "ADVICE",
        priority = 10,
        weight = 3,
        text = "Please leave station machinery, computers and redstone alone."
    },
    {
        id = "ADVICE-018",
        category = "ADVICE",
        priority = 10,
        weight = 3,
        text = "If the map says you are here, MCNet is reasonably confident that you are."
    },
    {
        id = "ADVICE-019",
        category = "ADVICE",
        priority = 10,
        weight = 3,
        text = "Please remember that minecarts are transport, not additional luggage storage."
    },
    {
        id = "ADVICE-020",
        category = "ADVICE",
        priority = 10,
        weight = 3,
        text = "Passengers carrying bees are requested to keep them securely contained."
    },

    -- =====================================================================
    -- Network news / world flavour
    -- =====================================================================
    {
        id = "NEWS-001",
        category = "NEWS",
        priority = 10,
        weight = 5,
        text = "Construction of the ACME Electric Line is now under way."
    },
    {
        id = "NEWS-002",
        category = "NEWS",
        priority = 10,
        weight = 4,
        text = "ACME ESC will become the network's first purpose-built electric destination."
    },
    {
        id = "NEWS-003",
        category = "NEWS",
        priority = 10,
        weight = 5,
        text = "The Honey Line provides a direct service between Bee Gardens and Laboratories."
    },
    {
        id = "NEWS-004",
        category = "NEWS",
        priority = 10,
        weight = 4,
        text = "Little Mexico Express operates over a controlled single-track route."
    },
    {
        id = "NEWS-005",
        category = "NEWS",
        priority = 10,
        weight = 4,
        text = "New Egypt services connect the northern development to Central Station."
    },
    {
        id = "NEWS-006",
        category = "NEWS",
        priority = 10,
        weight = 4,
        text = "Depot trials are in progress. Expect occasional shunting movements."
    },
    {
        id = "NEWS-007",
        category = "NEWS",
        priority = 10,
        weight = 4,
        text = "MCNet Rail is expanding. New stations and routes will appear on network maps."
    },
    {
        id = "NEWS-008",
        category = "NEWS",
        priority = 10,
        weight = 4,
        text = "Bee Gardens continues its Forestry programme and tree-pollination work."
    },
    {
        id = "NEWS-009",
        category = "NEWS",
        priority = 10,
        weight = 4,
        text = "Atoll Reef improvement works are continuing around the harbour and village."
    },
    {
        id = "NEWS-010",
        category = "NEWS",
        priority = 10,
        weight = 4,
        text = "Laboratories remains the network centre for advanced bee-genetics research."
    },
    {
        id = "NEWS-011",
        category = "NEWS",
        priority = 10,
        weight = 3,
        text = "Half Wall station now offers connections towards Eastern Village."
    },
    {
        id = "NEWS-012",
        category = "NEWS",
        priority = 10,
        weight = 3,
        text = "Central Station redevelopment continues as the network grows."
    },
    {
        id = "NEWS-013",
        category = "NEWS",
        priority = 10,
        weight = 3,
        text = "New signalling equipment is being trialled across the MCNet Rail network."
    },
    {
        id = "NEWS-014",
        category = "NEWS",
        priority = 10,
        weight = 3,
        text = "Additional passenger displays are being installed at stations across the network."
    },
    {
        id = "NEWS-015",
        category = "NEWS",
        priority = 10,
        weight = 3,
        text = "Work continues on automatic train detection and platform protection."
    },
    {
        id = "NEWS-016",
        category = "NEWS",
        priority = 10,
        weight = 3,
        text = "The railway control programme is currently being expanded one computer at a time."
    },
    {
        id = "NEWS-017",
        category = "NEWS",
        priority = 10,
        weight = 2,
        text = "Engineers are measuring stopping distances before automatic block control enters service."
    },
    {
        id = "NEWS-018",
        category = "NEWS",
        priority = 10,
        weight = 2,
        text = "Grand Central's future control room will provide a live view of the whole railway."
    },
    {
        id = "NEWS-019",
        category = "NEWS",
        priority = 10,
        weight = 2,
        text = "A sixth platform remains available for future development at Central Station."
    },
    {
        id = "NEWS-020",
        category = "NEWS",
        priority = 10,
        weight = 2,
        text = "MCNet Rail engineers report that excessive planning remains within acceptable limits."
    },

    -- =====================================================================
    -- Jokes / flavour
    --
    -- Most have a lower weight than normal notices. The rare/very-rare lines
    -- are deliberately difficult to encounter so the boards can still
    -- surprise someone after many hours of play.
    -- =====================================================================
    {
        id = "JOKE-001",
        category = "JOKE",
        priority = 0,
        weight = 5,
        text = "The train is not late. The timetable is merely ambitious."
    },
    {
        id = "JOKE-002",
        category = "JOKE",
        priority = 0,
        weight = 5,
        text = "MCNet Rail: considerably safer than walking through the Nether."
    },
    {
        id = "JOKE-003",
        category = "JOKE",
        priority = 0,
        weight = 5,
        text = "Delays caused by creepers are outside the timetable guarantee."
    },
    {
        id = "JOKE-004",
        category = "JOKE",
        priority = 0,
        weight = 5,
        text = "Unattended villagers may be promoted to station staff."
    },
    {
        id = "JOKE-005",
        category = "JOKE",
        priority = 0,
        weight = 5,
        text = "Our trains run on steam, redstone and excessive planning."
    },
    {
        id = "JOKE-006",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Please do not ask the locomotive whether we are there yet."
    },
    {
        id = "JOKE-007",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Next stop: probably the one printed on the departure board."
    },
    {
        id = "JOKE-008",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Bee Gardens passengers are reminded to mind the buzz."
    },
    {
        id = "JOKE-009",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "ACME employees must declare rocket launchers before boarding."
    },
    {
        id = "JOKE-010",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "If you can see the Lair on the public map, please report a software fault."
    },
    {
        id = "JOKE-011",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Rail replacement pig service is not currently available."
    },
    {
        id = "JOKE-012",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Please refrain from testing explosives inside station buildings."
    },
    {
        id = "JOKE-013",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Passengers are reminded that punching the train will not make it arrive faster."
    },
    {
        id = "JOKE-014",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "The signal is red because the railway has trust issues."
    },
    {
        id = "JOKE-015",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Please keep arms, legs and pickaxes inside the train at all times."
    },
    {
        id = "JOKE-016",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "A watched departure board never makes the train arrive sooner."
    },
    {
        id = "JOKE-017",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "MCNet Rail accepts no responsibility for sudden urges to build another station."
    },
    {
        id = "JOKE-018",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Please do not feed the locomotives. Engineering says they have had enough coal."
    },
    {
        id = "JOKE-019",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "If your train has become a boat, please check whether you boarded at Atoll Reef."
    },
    {
        id = "JOKE-020",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Central Station apologises for being in the middle of everything."
    },
    {
        id = "JOKE-021",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "The Honey Line: now with approximately zero actual honey on the track."
    },
    {
        id = "JOKE-022",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Little Mexico Express: little station, disproportionately serious railway."
    },
    {
        id = "JOKE-023",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Half Wall would like to confirm that the other half remains a planning matter."
    },
    {
        id = "JOKE-024",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "The Spa reminds passengers that the railway is not included in the treatment package."
    },
    {
        id = "JOKE-025",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "New Egypt services are pyramid-scheme free."
    },
    {
        id = "JOKE-026",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Atoll Reef requests that passengers leave the coral where they found it."
    },
    {
        id = "JOKE-027",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Laboratories denies all knowledge of unusually intelligent bees."
    },
    {
        id = "JOKE-028",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Eastern Village: definitely east of something."
    },
    {
        id = "JOKE-029",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "ACME ESC: where the safety briefing is longer than the journey."
    },
    {
        id = "JOKE-030",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "If the departure board says ON TIME, please take a screenshot for the archives."
    },
    {
        id = "JOKE-031",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Please do not lick the electrified railway equipment."
    },
    {
        id = "JOKE-032",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "The railway is fully automated, except for all the bits currently being built by hand."
    },
    {
        id = "JOKE-033",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Passengers travelling with thirty-seven stacks of cobblestone should use both hands."
    },
    {
        id = "JOKE-034",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "Your connection is being held. Somewhere, a computer is feeling very important."
    },
    {
        id = "JOKE-035",
        category = "JOKE",
        priority = 0,
        weight = 4,
        text = "MCNet Rail has checked the route. Probably more than once."
    },
    {
        id = "JOKE-036",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "Passengers are reminded that redstone dust is not a complimentary snack."
    },
    {
        id = "JOKE-037",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "There is no secret station. Please stop asking about the secret station."
    },
    {
        id = "JOKE-038",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "Any resemblance between the timetable and actual events is entirely intentional."
    },
    {
        id = "JOKE-039",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "If this message is scrolling, congratulations: the display computer is still alive."
    },
    {
        id = "JOKE-040",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "Please report suspicious minecarts. Normal minecarts may continue being suspicious quietly."
    },
    {
        id = "JOKE-041",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "The railway was cheaper before somebody discovered signalling."
    },
    {
        id = "JOKE-042",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "Today's service is brought to you by bundled cable and unreasonable optimism."
    },
    {
        id = "JOKE-043",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "Platform alterations are announced shortly after everyone reaches the wrong platform."
    },
    {
        id = "JOKE-044",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "The depot contains exactly as many trains as engineering remembers parking there."
    },
    {
        id = "JOKE-045",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "MCNet Rail: connecting places that were previously only a mildly inconvenient walk apart."
    },
    {
        id = "JOKE-046",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "A delay of one Minecraft day is not considered an overnight service."
    },
    {
        id = "JOKE-047",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "Please mind the gap. Engineering has measured it and become emotionally attached."
    },
    {
        id = "JOKE-048",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "If you hear hissing on the platform, please determine whether it is steam before panicking."
    },
    {
        id = "JOKE-049",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "Station staff have been advised that 'because redstone' is not a complete incident report."
    },
    {
        id = "JOKE-050",
        category = "JOKE",
        priority = 0,
        weight = 3,
        text = "Please do not test the emergency hold just to see what happens."
    },

    -- ---------------------------------------------------------------------
    -- Rare messages
    -- ---------------------------------------------------------------------
    {
        id = "JOKE-R001",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "Congratulations. You have found one of the less common station messages."
    },
    {
        id = "JOKE-R002",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "The station announcer would like a pay rise. The station announcer is a Lua table."
    },
    {
        id = "JOKE-R003",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "Somewhere beneath the network, a detector has just changed state. Exciting, isn't it?"
    },
    {
        id = "JOKE-R004",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "Please ignore any tunnel labelled 'definitely not the Lair'."
    },
    {
        id = "JOKE-R005",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "ACME would like to clarify that the crater was part of a controlled test."
    },
    {
        id = "JOKE-R006",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "Bee Gardens reports that all bees have been counted. The number remains classified."
    },
    {
        id = "JOKE-R007",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "The timetable department has requested that clocks stop being so judgemental."
    },
    {
        id = "JOKE-R008",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "This message has no operational significance whatsoever."
    },
    {
        id = "JOKE-R009",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "A railway without unnecessary complexity is merely transport."
    },
    {
        id = "JOKE-R010",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "RARE",
        text = "If you are reading every banner message, station control has noticed."
    },

    -- ---------------------------------------------------------------------
    -- Very rare messages
    -- getNext() gives these an additional rarity roll before they can enter
    -- the weighted pool.
    -- ---------------------------------------------------------------------
    {
        id = "JOKE-VR001",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "VERY_RARE",
        text = "You weren't supposed to see this one."
    },
    {
        id = "JOKE-VR002",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "VERY_RARE",
        text = "THE LAIR DOES NOT EXIST. Have a pleasant journey."
    },
    {
        id = "JOKE-VR003",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "VERY_RARE",
        text = "MCNet Rail achievement unlocked: stared at station furniture for too long."
    },
    {
        id = "JOKE-VR004",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "VERY_RARE",
        text = "A mysterious voice whispers: add another branch line."
    },
    {
        id = "JOKE-VR005",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "VERY_RARE",
        text = "This message is statistically inconvenient."
    },
    {
        id = "JOKE-VR006",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "VERY_RARE",
        text = "Please remain calm. The computer has become self-aware enough to complain about timetables."
    },
    {
        id = "JOKE-VR007",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "VERY_RARE",
        text = "Somewhere, an unused chest still contains the item you have been looking for all evening."
    },
    {
        id = "JOKE-VR008",
        category = "JOKE",
        priority = 0,
        weight = 1,
        rarity = "VERY_RARE",
        text = "If this train terminates unexpectedly, please blame the person who built the junction."
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

local function eligibleForRandom(item)
    local rarity =
        string.upper(
            tostring(
                item.rarity
                or "COMMON"
            )
        )

    if rarity == "VERY_RARE" then
        -- Roughly one opportunity in 35 selections before weighting.
        return math.random(1, 35) == 1
    end

    if rarity == "RARE" then
        -- Roughly one opportunity in 8 selections before weighting.
        return math.random(1, 8) == 1
    end

    return true
end

local function weightedRandom(source)
    local candidates = {}
    local totalWeight = 0

    for _, item in ipairs(source or {}) do
        if item.id ~= lastMessageId
            and eligibleForRandom(item) then

            local weight =
                math.max(
                    1,
                    math.floor(
                        tonumber(
                            item.weight
                        )
                        or 1
                    )
                )

            candidates[#candidates + 1] = {
                item = item,
                weight = weight
            }

            totalWeight =
                totalWeight + weight
        end
    end

    -- A tiny/filtered set can leave no candidate after rarity filtering.
    -- Fall back to any non-repeating message, then finally the first entry.
    if #candidates == 0 then
        for _, item in ipairs(source or {}) do
            if item.id ~= lastMessageId then
                candidates[#candidates + 1] = {
                    item = item,
                    weight = 1
                }
                totalWeight =
                    totalWeight + 1
            end
        end
    end

    if #candidates == 0 then
        if source and source[1] then
            return source[1]
        end

        return nil
    end

    local roll =
        math.random(
            1,
            totalWeight
        )

    local running = 0

    for _, candidate in ipairs(candidates) do
        running =
            running
            + candidate.weight

        if roll <= running then
            return candidate.item
        end
    end

    return candidates[#candidates].item
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

    local item =
        weightedRandom(
            source
        )

    if not item then
        return nil
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

function module.getRarity(id)
    local item =
        module.getById(id)

    if not item then
        return nil
    end

    return tostring(
        item.rarity
        or "COMMON"
    )
end

function module.reset()
    currentIndex = 0
    lastMessageId = nil
end

return module
