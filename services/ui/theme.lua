-- MCNet UI colour themes

local palettes = {
    green = {
        name = "MCNet Green",
        background = colors.black,
        foreground = colors.white,
        muted = colors.lightGray,
        title = colors.lime,
        accent = colors.green,
        accent2 = colors.lime,
        selectedText = colors.black,
        success = colors.lime,
        warning = colors.orange,
        error = colors.red,
        border = colors.green,
        panel = colors.gray,
        emptyBar = colors.gray
    },
    amber = {
        name = "Amber Terminal",
        background = colors.black,
        foreground = colors.white,
        muted = colors.lightGray,
        title = colors.yellow,
        accent = colors.orange,
        accent2 = colors.yellow,
        selectedText = colors.black,
        success = colors.lime,
        warning = colors.orange,
        error = colors.red,
        border = colors.orange,
        panel = colors.gray,
        emptyBar = colors.gray
    },
    ice = {
        name = "Ice Blue",
        background = colors.black,
        foreground = colors.white,
        muted = colors.lightGray,
        title = colors.cyan,
        accent = colors.lightBlue,
        accent2 = colors.cyan,
        selectedText = colors.black,
        success = colors.lime,
        warning = colors.orange,
        error = colors.red,
        border = colors.blue,
        panel = colors.gray,
        emptyBar = colors.gray
    },
    redstone = {
        name = "Redstone",
        background = colors.black,
        foreground = colors.white,
        muted = colors.lightGray,
        title = colors.red,
        accent = colors.orange,
        accent2 = colors.red,
        selectedText = colors.black,
        success = colors.lime,
        warning = colors.orange,
        error = colors.red,
        border = colors.red,
        panel = colors.gray,
        emptyBar = colors.gray
    },
    monochrome = {
        name = "Monochrome",
        background = colors.black,
        foreground = colors.white,
        muted = colors.lightGray,
        title = colors.white,
        accent = colors.white,
        accent2 = colors.lightGray,
        selectedText = colors.black,
        success = colors.white,
        warning = colors.white,
        error = colors.white,
        border = colors.white,
        panel = colors.gray,
        emptyBar = colors.gray
    }
}

local order = { "green", "amber", "ice", "redstone", "monochrome" }

local module = {}

function module.get(name)
    return palettes[name] or palettes.green
end

function module.getNames()
    local result = {}
    for _, name in ipairs(order) do
        table.insert(result, name)
    end
    return result
end

function module.getDisplayName(name)
    return module.get(name).name
end

return module
