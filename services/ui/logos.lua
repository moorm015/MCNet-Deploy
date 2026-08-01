-- MCNet hostile-mob terminal artwork
-- Add more entries to this file at any time. The rest of the UI does not
-- need changing; random mode automatically includes every name in order.

local logos = {
    creeper = {
        label = "CREEPER",
        compact = {
            " ####### ",
            " ## # ## ",
            " ####### ",
            " ### ### ",
            " ##   ## "
        },
        full = {
            "  ########  ",
            " ########## ",
            " ##  ##  ## ",
            " ##  ##  ## ",
            " ########## ",
            " ####  #### ",
            " ###    ### ",
            " ### ## ### "
        }
    },
    skeleton = {
        label = "SKELETON",
        compact = {
            "  #####  ",
            " # O O # ",
            " #  ^  # ",
            " # === # ",
            "  #####  "
        },
        full = {
            "   #######   ",
            "  #########  ",
            " ##  O O  ## ",
            " ##   ^   ## ",
            " ##  ===  ## ",
            "  ## === ##  ",
            "   #######   ",
            "    | | |    "
        }
    },
    zombie = {
        label = "ZOMBIE",
        compact = {
            " ####### ",
            " # O O # ",
            " #  -  # ",
            " ####### ",
            "  /| |\\  "
        },
        full = {
            "  #########  ",
            " ########### ",
            " ##  O O  ## ",
            " ##   -   ## ",
            " ########### ",
            "   /|   |\\   ",
            "  / |   | \\  ",
            "    |   |    "
        }
    },
    spider = {
        label = "SPIDER",
        compact = {
            "\\  ###  /",
            " \\#####/ ",
            "###O#O###",
            " /#####\\ ",
            "/  ###  \\"
        },
        full = {
            "\\      ###      /",
            " \\   #######   / ",
            "  \\######### /  ",
            "###  O ### O  ###",
            "  /#########\\  ",
            " /   #######  \\ ",
            "/      ###     \\"
        }
    },
    enderman = {
        label = "ENDERMAN",
        compact = {
            "   ####   ",
            "  #    #  ",
            "  # -- #  ",
            "   ####   ",
            "   |  |   "
        },
        full = {
            "    ########    ",
            "   ##########   ",
            "   ## -- --##   ",
            "   ##########   ",
            "      |  |      ",
            "      |  |      ",
            "     /    \\     ",
            "    /      \\    "
        }
    },
    blaze = {
        label = "BLAZE",
        compact = {
            " \\ | | / ",
            "  #####  ",
            " # O O # ",
            "  #####  ",
            " / | | \\ "
        },
        full = {
            "  \\   | |   /  ",
            "   \\ ##### /   ",
            "    #######    ",
            "   ## O O ##   ",
            "    #######    ",
            "   / ##### \\   ",
            "  /   | |   \\  ",
            " /    | |    \\ "
        }
    }
}

local order = { "creeper", "skeleton", "zombie", "spider", "enderman", "blaze" }
local module = {}

function module.choose(name, compact)
    if name == "off" then
        return nil
    end

    if name == "random" or not logos[name] then
        name = order[math.random(1, #order)]
    end

    local logo = logos[name]
    return {
        name = name,
        label = logo.label,
        lines = compact and logo.compact or logo.full
    }
end

function module.getNames()
    local result = { "random" }
    for _, name in ipairs(order) do
        table.insert(result, name)
    end
    table.insert(result, "off")
    return result
end

return module
