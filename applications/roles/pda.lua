-- MCNet PDA home and messaging application
-- Version 0.8.0

local application = {}

function application.run(context)
    local ui = context.ui
    local menu = context.menu
    local deviceModule = context.deviceModule
    local appManager = context.appManager
    local network = context.network
    local messaging = context.messaging

    local function getDevice()
        return deviceModule.load(
            nil,
            context.version,
            context.protocol
        )
    end

    local function showNotice(title, message)
        local start =
            ui.drawHeader(
                title,
                getDevice(),
                context.version
            )

        ui.writeAt(
            ui.getLayout().left,
            start,
            tostring(message),
            ui.getPalette().foreground
        )

        ui.pause()
    end

    local function systemConsole()
        local child = {}

        for key, value in pairs(context) do
            child[key] = value
        end

        child.fromRole = true

        local completed, reason =
            appManager.run(
                appManager.getSystemConsolePath(),
                child
            )

        if not completed then
            showNotice(
                "System console error",
                tostring(reason)
            )
        end
    end

    local function composeMessage()
        ui.restoreNative()

        local device = getDevice()

        ui.drawHeader(
            "New message",
            device,
            context.version
        )

        print("")
        print("Messages are routed through the tower network.")
        print("")

        local destination =
            ui.readDefault(
                "Destination",
                ""
            )

        local text =
            ui.readDefault(
                "Message",
                ""
            )

        local sent, reason =
            messaging.send(
                destination,
                text
            )

        print("")

        if sent then
            print("Message queued for delivery.")
        else
            print("Message could not be queued:")
            print(tostring(reason))
        end

        ui.pause()
        ui.configure(context.settings)
    end

    local function showMessage(item)
        messaging.markRead(item.id)

        local start =
            ui.drawHeader(
                "Message",
                getDevice(),
                context.version
            )

        ui.printField(
            "From",
            item.from,
            start
        )

        ui.printField(
            "Day",
            item.day,
            start + 1
        )

        ui.printField(
            "Time",
            item.time,
            start + 2
        )

        print("")
        print(item.text)
        print("")

        if ui.askYesNo("Reply?") then
            ui.restoreNative()

            ui.drawHeader(
                "Reply",
                getDevice(),
                context.version
            )

            print("")
            print("To: " .. tostring(item.from))
            print("")

            local reply =
                ui.readDefault(
                    "Message",
                    ""
                )

            local sent, reason =
                messaging.send(
                    item.from,
                    reply
                )

            print("")

            if sent then
                print("Reply queued.")
            else
                print(tostring(reason))
            end

            ui.pause()
            ui.configure(context.settings)
        end
    end

    local function inbox()
        while true do
            local messages =
                messaging.getInbox()

            local options = {
                {
                    label = "Compose new message",
                    compactLabel = "New message",
                    description =
                        "Write a message to an MCNet address.",
                    action = composeMessage
                }
            }

            for _, message in ipairs(messages) do
                local item = message
                local marker =
                    item.unread
                    and "* "
                    or "  "

                table.insert(options, {
                    label =
                        marker
                        .. tostring(item.from)
                        .. ": "
                        .. ui.clip(
                            item.text,
                            28
                        ),
                    compactLabel =
                        marker
                        .. tostring(item.from),
                    description =
                        ui.clip(
                            item.text,
                            50
                        ),
                    action = function()
                        showMessage(item)
                    end
                })
            end

            if #messages == 0 then
                table.insert(options, {
                    label = "Inbox is empty",
                    compactLabel = "Inbox empty",
                    disabled = true
                })
            end

            table.insert(options, {
                label = "Return to PDA",
                compactLabel = "Back",
                back = true
            })

            local selected =
                menu.choose(
                    ui,
                    "Inbox",
                    options,
                    getDevice(),
                    context.version
                )

            if selected.back then
                return
            end

            selected.action()
        end
    end

    local function sentMessages()
        while true do
            local messages =
                messaging.getOutbox()

            local options = {}

            for _, message in ipairs(messages) do
                local item = message

                table.insert(options, {
                    label =
                        tostring(item.status or "QUEUED")
                        .. "  "
                        .. tostring(item.to)
                        .. ": "
                        .. ui.clip(
                            item.text,
                            24
                        ),
                    compactLabel =
                        tostring(item.status or "QUEUED")
                        .. " "
                        .. tostring(item.to),
                    description =
                        ui.clip(
                            item.text,
                            50
                        ),
                    action = function()
                        local start =
                            ui.drawHeader(
                                "Sent message",
                                getDevice(),
                                context.version
                            )

                        ui.printField(
                            "To",
                            item.to,
                            start
                        )

                        ui.printField(
                            "Status",
                            item.status or "QUEUED",
                            start + 1
                        )

                        ui.printField(
                            "Reason",
                            item.reason or "None",
                            start + 2
                        )

                        print("")
                        print(item.text)
                        print("")

                        if item.status == "FAILED"
                            and ui.askYesNo("Retry?") then
                            local retried, reason =
                                messaging.retry(
                                    item.id
                                )

                            print("")

                            if retried then
                                print("Message queued again.")
                            else
                                print(tostring(reason))
                            end
                        end

                        ui.pause()
                    end
                })
            end

            if #messages == 0 then
                table.insert(options, {
                    label = "No sent messages",
                    compactLabel = "No messages",
                    disabled = true
                })
            end

            table.insert(options, {
                label = "Return to PDA",
                compactLabel = "Back",
                back = true
            })

            local selected =
                menu.choose(
                    ui,
                    "Sent messages",
                    options,
                    getDevice(),
                    context.version
                )

            if selected.back then
                return
            end

            selected.action()
        end
    end

    local function networkStatus()
        local status =
            network.getStatus()

        local start =
            ui.drawHeader(
                "Network status",
                getDevice(),
                context.version
            )

        ui.printField(
            "Modem",
            status.modemReady
                and "READY"
                or "UNAVAILABLE",
            start
        )

        ui.printField(
            "Tower",
            status.selectedTower
                or "NONE",
            start + 1
        )

        ui.printField(
            "Nearby towers",
            status.nearbyTowers,
            start + 2
        )

        ui.printField(
            "Pending packets",
            status.pending,
            start + 3
        )

        ui.printField(
            "Frames received",
            status.counters.framesReceived,
            start + 4
        )

        ui.printField(
            "Frames sent",
            status.counters.framesSent,
            start + 5
        )

        ui.pause()
    end

    while true do
        local device = getDevice()
        local unread =
            messaging.getUnreadCount()

        local messageLabel = "Messages"

        if unread > 0 then
            messageLabel =
                messageLabel
                .. " ("
                .. tostring(unread)
                .. " new)"
        end

        local options = {
            {
                label = messageLabel,
                compactLabel =
                    unread > 0
                    and "Messages (" .. tostring(unread) .. ")"
                    or "Messages",
                description =
                    "Read, write and reply to routed MCNet messages.",
                action = inbox
            },
            {
                label = "Compose message",
                compactLabel = "New message",
                description =
                    "Send a message through the nearest tower.",
                action = composeMessage
            },
            {
                label = "Sent messages",
                compactLabel = "Sent",
                description =
                    "Review delivery and retry failed messages.",
                action = sentMessages
            },
            {
                label = "Network status",
                compactLabel = "Network",
                description =
                    "Show the selected tower and wireless state.",
                action = networkStatus
            },
            {
                label = "Open system console",
                compactLabel = "System console",
                description =
                    "Open installation, settings and diagnostics.",
                action = systemConsole
            },
            {
                label = "Exit to CraftOS",
                compactLabel = "Exit",
                exit = true
            }
        }

        local selected =
            menu.choose(
                ui,
                "MCNet PDA",
                options,
                device,
                context.version
            )

        if selected.exit then
            return
        end

        selected.action()
    end
end

return application
