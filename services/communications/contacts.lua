-- MCNet local contact book
-- Version 0.9.0

local module = {}
local PATH = ".mcnet/contacts.lua"
local MAX_CONTACTS = 100

local function cleanAddress(value)
    value = string.upper(tostring(value or ""))
    value = string.gsub(value, "%s+", "-")
    value = string.gsub(value, "[^A-Z0-9%-_]", "")
    return value
end

local function copy(item)
    return { name = item.name, address = item.address }
end

local function normalise(value)
    local result = { contacts = {} }
    local source = type(value) == "table" and value.contacts or nil
    if type(source) ~= "table" then source = type(value) == "table" and value or {} end

    for _, item in ipairs(source) do
        if type(item) == "table" then
            local address = cleanAddress(item.address)
            local name = tostring(item.name or "")
            if address ~= "" and name ~= "" then
                result.contacts[#result.contacts + 1] = { name = name, address = address }
            end
        end
    end
    return result
end

local function save(store, path)
    local directory = fs.getDir(path)
    if directory ~= "" and not fs.exists(directory) then fs.makeDir(directory) end
    local temporary = path .. ".tmp"
    if fs.exists(temporary) then fs.delete(temporary) end
    local file = fs.open(temporary, "w")
    if not file then return false, "Could not write contacts" end
    file.write("return ")
    file.write(textutils.serialize(store))
    file.write("\n")
    file.close()
    if fs.exists(path) then fs.delete(path) end
    fs.move(temporary, path)
    return true
end

function module.new(path)
    path = path or PATH
    local loaded = {}
    if fs.exists(path) then
        local ok, value = pcall(dofile, path)
        if ok then loaded = value end
    end
    local store = normalise(loaded)
    local contacts = {}

    function contacts.getAll()
        local result = {}
        for _, item in ipairs(store.contacts) do result[#result + 1] = copy(item) end
        table.sort(result, function(a, b)
            return string.lower(a.name) < string.lower(b.name)
        end)
        return result
    end

    function contacts.get(address)
        address = cleanAddress(address)
        for _, item in ipairs(store.contacts) do
            if item.address == address then return copy(item) end
        end
        return nil
    end

    function contacts.add(name, address)
        name = tostring(name or "")
        address = cleanAddress(address)
        if name == "" then return false, "Contact name is required" end
        if address == "" then return false, "Contact address is required" end

        for _, item in ipairs(store.contacts) do
            if item.address == address then
                item.name = name
                return save(store, path)
            end
        end

        if #store.contacts >= MAX_CONTACTS then return false, "Contact book is full" end
        store.contacts[#store.contacts + 1] = { name = name, address = address }
        return save(store, path)
    end

    function contacts.remove(address)
        address = cleanAddress(address)
        for index, item in ipairs(store.contacts) do
            if item.address == address then
                table.remove(store.contacts, index)
                return save(store, path)
            end
        end
        return false, "Contact was not found"
    end

    function contacts.resolve(address)
        local item = contacts.get(address)
        return item and item.name or nil
    end

    function contacts.getPath()
        return path
    end

    return contacts
end

return module
