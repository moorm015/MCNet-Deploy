-- MCNet PDA directory, contacts and offline messaging application
-- Version 0.9.0

local application = {}

function application.run(context)
    local ui = context.ui
    local menu = context.menu
    local deviceModule = context.deviceModule
    local appManager = context.appManager
    local network = context.network
    local messaging = context.messaging
    local coreClient = context.coreClient
    local contacts = context.contacts

    local function getDevice()
        return deviceModule.load(nil, context.version, context.protocol)
    end

    local function resolveName(address)
        local localName = contacts and contacts.resolve(address) or nil
        if localName then return localName end
        if coreClient then return coreClient.resolve(address) end
        return tostring(address or "UNKNOWN")
    end

    local function displayAddress(address)
        local name = resolveName(address)
        if name ~= address then return name .. " (" .. tostring(address) .. ")" end
        return tostring(address)
    end

    local function showNotice(title, message)
        local start = ui.drawHeader(title, getDevice(), context.version)
        ui.writeAt(ui.getLayout().left, start, tostring(message), ui.getPalette().foreground)
        ui.pause()
    end

    local function systemConsole()
        local child = {}
        for key, value in pairs(context) do child[key] = value end
        child.fromRole = true
        local completed, reason = appManager.run(appManager.getSystemConsolePath(), child)
        if not completed then showNotice("System console error", tostring(reason)) end
    end

    local function directoryRecipient()
        if not coreClient then
            showNotice("Directory", "The directory service is unavailable.")
            return nil
        end

        local options = {}
        local ownAddress = getDevice().address
        for _, entry in ipairs(coreClient.getDirectory()) do
            if entry.address ~= ownAddress then
                local item = entry
                local name = item.friendlyName ~= "" and item.friendlyName or item.address
                table.insert(options, {
                    label = name .. "  " .. (item.online and "ONLINE" or "OFFLINE"),
                    compactLabel = name,
                    description = item.address .. " | " .. tostring(item.type or "DEVICE"),
                    address = item.address
                })
            end
        end

        if #options == 0 then
            table.insert(options, { label = "No directory entries", disabled = true })
        end
        table.insert(options, { label = "Cancel", compactLabel = "Cancel", back = true })
        local selected = menu.choose(ui, "MCNet directory", options, getDevice(), context.version)
        if selected.back then return nil end
        return selected.address
    end

    local function selectRecipient()
        while true do
            local options = {}
            if contacts then
                for _, contact in ipairs(contacts.getAll()) do
                    local item = contact
                    local directory = coreClient and coreClient.getDevice(item.address) or nil
                    local state = directory and (directory.online and "ONLINE" or "OFFLINE") or "SAVED"
                    table.insert(options, {
                        label = item.name .. "  " .. state,
                        compactLabel = item.name,
                        description = item.address,
                        address = item.address
                    })
                end
            end

            table.insert(options, {
                label = "Browse network directory",
                compactLabel = "Directory",
                description = "Choose a named MCNet device.",
                action = "directory"
            })
            table.insert(options, {
                label = "Enter address manually",
                compactLabel = "Manual address",
                description = "Enter an address such as PDA-040.",
                action = "manual"
            })
            table.insert(options, { label = "Cancel", compactLabel = "Cancel", back = true })

            local selected = menu.choose(ui, "Choose recipient", options, getDevice(), context.version)
            if selected.back then return nil end
            if selected.address then return selected.address end
            if selected.action == "directory" then
                local address = directoryRecipient()
                if address then return address end
            elseif selected.action == "manual" then
                ui.restoreNative()
                ui.drawHeader("Manual recipient", getDevice(), context.version)
                print("")
                print("Leave blank to cancel.")
                print("")
                local address = ui.readDefault("Address", "")
                ui.configure(context.settings)
                address = string.upper(tostring(address or ""))
                if address ~= "" then return address end
            end
        end
    end

    local function composeMessage(destination)
        destination = destination or selectRecipient()
        if not destination then return end

        ui.restoreNative()
        ui.drawHeader("New message", getDevice(), context.version)
        print("")
        print("To: " .. displayAddress(destination))
        print("Leave the message blank to cancel.")
        print("")
        local text = ui.readDefault("Message", "")
        if tostring(text or "") == "" then
            print("")
            print("Message cancelled.")
            ui.pause()
            ui.configure(context.settings)
            return
        end

        local sent, reason = messaging.send(destination, text)
        print("")
        if sent then
            print("Message queued. MCNet will store it if the recipient is offline.")
        else
            print("Message could not be queued:")
            print(tostring(reason))
        end
        ui.pause()
        ui.configure(context.settings)
    end

    local function showMessage(item)
        messaging.markRead(item.id)
        local start = ui.drawHeader("Message", getDevice(), context.version)
        ui.printField("From", displayAddress(item.from), start)
        ui.printField("Day", item.day, start + 1)
        ui.printField("Time", item.time, start + 2)
        print("")
        print(item.text)
        print("")
        if ui.askYesNo("Reply?") then
            composeMessage(item.from)
        end
    end

    local function inbox()
        while true do
            local messages = messaging.getInbox()
            local options = {
                {
                    label = "Compose new message",
                    compactLabel = "New message",
                    description = "Choose a contact or directory entry.",
                    action = function() composeMessage(nil) end
                }
            }
            for _, message in ipairs(messages) do
                local item = message
                local marker = item.unread and "* " or "  "
                table.insert(options, {
                    label = marker .. resolveName(item.from) .. ": " .. ui.clip(item.text, 28),
                    compactLabel = marker .. resolveName(item.from),
                    description = ui.clip(item.text, 50),
                    action = function() showMessage(item) end
                })
            end
            if #messages == 0 then table.insert(options, { label = "Inbox is empty", disabled = true }) end
            table.insert(options, { label = "Return to PDA", compactLabel = "Back", back = true })
            local selected = menu.choose(ui, "Inbox", options, getDevice(), context.version)
            if selected.back then return end
            selected.action()
        end
    end

    local function sentMessages()
        while true do
            local messages = messaging.getOutbox()
            local options = {}
            for _, message in ipairs(messages) do
                local item = message
                table.insert(options, {
                    label = tostring(item.status or "QUEUED") .. "  " .. resolveName(item.to) .. ": " .. ui.clip(item.text, 24),
                    compactLabel = tostring(item.status or "QUEUED") .. " " .. resolveName(item.to),
                    description = ui.clip(item.text, 50),
                    action = function()
                        local start = ui.drawHeader("Sent message", getDevice(), context.version)
                        ui.printField("To", displayAddress(item.to), start)
                        ui.printField("Status", item.status or "QUEUED", start + 1)
                        ui.printField("Route", item.route or "CORE", start + 2)
                        ui.printField("Reason", item.reason or "None", start + 3)
                        print("")
                        print(item.text)
                        print("")
                        if item.status == "FAILED" and ui.askYesNo("Retry?") then
                            local retried, reason = messaging.retry(item.id)
                            print("")
                            if retried then print("Message queued again.") else print(tostring(reason)) end
                        end
                        ui.pause()
                    end
                })
            end
            if #messages == 0 then table.insert(options, { label = "No sent messages", disabled = true }) end
            table.insert(options, { label = "Return to PDA", compactLabel = "Back", back = true })
            local selected = menu.choose(ui, "Sent messages", options, getDevice(), context.version)
            if selected.back then return end
            selected.action()
        end
    end

    local function contactsMenu()
        while true do
            local options = {
                {
                    label = "Add contact",
                    compactLabel = "Add contact",
                    action = function()
                        local address = directoryRecipient()
                        if not address then
                            ui.restoreNative()
                            ui.drawHeader("Add contact", getDevice(), context.version)
                            print("")
                            address = ui.readDefault("Address", "")
                        end
                        if not address or address == "" then ui.configure(context.settings); return end
                        ui.restoreNative()
                        ui.drawHeader("Add contact", getDevice(), context.version)
                        print("")
                        print("Address: " .. tostring(address))
                        local defaultName = coreClient and coreClient.resolve(address) or ""
                        local name = ui.readDefault("Name", defaultName)
                        if name and name ~= "" then
                            local saved, reason = contacts.add(name, address)
                            print("")
                            print(saved and "Contact saved." or tostring(reason))
                            ui.pause()
                        end
                        ui.configure(context.settings)
                    end
                }
            }
            for _, contact in ipairs(contacts.getAll()) do
                local item = contact
                table.insert(options, {
                    label = item.name .. "  " .. item.address,
                    compactLabel = item.name,
                    description = "Open or remove this contact.",
                    action = function()
                        local choices = {
                            { label = "Message " .. item.name, action = "message" },
                            { label = "Remove contact", action = "remove" },
                            { label = "Back", back = true }
                        }
                        local chosen = menu.choose(ui, item.name, choices, getDevice(), context.version)
                        if chosen.action == "message" then composeMessage(item.address)
                        elseif chosen.action == "remove" then contacts.remove(item.address) end
                    end
                })
            end
            table.insert(options, { label = "Return to PDA", compactLabel = "Back", back = true })
            local selected = menu.choose(ui, "Contacts", options, getDevice(), context.version)
            if selected.back then return end
            selected.action()
        end
    end

    local function networkStatus()
        local status = network.getStatus()
        local core = coreClient and coreClient.getStatus() or { online = false, coreAddress = "NONE", devices = 0, towers = 0 }
        local start = ui.drawHeader("Network status", getDevice(), context.version)
        ui.printField("Modem", status.modemReady and "READY" or "UNAVAILABLE", start)
        ui.printField("Tower", status.selectedTower or "NONE", start + 1)
        ui.printField("Core server", core.online and "ONLINE" or "OFFLINE", start + 2)
        ui.printField("Core address", core.coreAddress, start + 3)
        ui.printField("Directory devices", core.devices, start + 4)
        ui.printField("Known towers", core.towers, start + 5)
        ui.printField("Pending packets", status.pending, start + 6)
        ui.pause()
    end

    while true do
        local device = getDevice()
        local unread = messaging.getUnreadCount()
        local messageLabel = unread > 0 and "Messages (" .. tostring(unread) .. " new)" or "Messages"
        local options = {
            { label = messageLabel, compactLabel = messageLabel, description = "Read, write and reply to MCNet messages.", action = inbox },
            { label = "Compose message", compactLabel = "New message", description = "Choose a contact, directory entry or address.", action = function() composeMessage(nil) end },
            { label = "Contacts", compactLabel = "Contacts", description = "Save friendly names for regular recipients.", action = contactsMenu },
            { label = "Sent messages", compactLabel = "Sent", description = "Review stored, delivered and failed messages.", action = sentMessages },
            { label = "Network status", compactLabel = "Network", description = "Show tower, core server and directory status.", action = networkStatus },
            { label = "Open system console", compactLabel = "System console", description = "Open installation, settings and diagnostics.", action = systemConsole },
            {
                label = "Shut down PDA",
                compactLabel = "Shut down",
                description = "Turn off now. Offline messages are collected next boot.",
                action = function()
                    ui.drawHeader("Shut down", device, context.version)
                    print("")
                    if ui.askYesNo("Shut down this PDA?") then ui.restoreNative(); os.shutdown() end
                end
            }
        }
        local selected = menu.choose(ui, "MCNet PDA", options, device, context.version)
        selected.action()
    end
end

return application
