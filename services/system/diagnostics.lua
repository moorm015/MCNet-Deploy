-- MCNet reusable diagnostic checks
-- Version 0.8.0

local module = {}

local function add(results, name, passed, detail)
    table.insert(results, {
        name = name,
        passed = passed == true,
        detail = tostring(detail or "")
    })
end

local function peripheralNames()
    if peripheral.getNames then
        return peripheral.getNames()
    end

    if rs and rs.getSides then
        return rs.getSides()
    end

    return {}
end

function module.countModems()
    local count = 0

    for _, name in ipairs(peripheralNames()) do
        if peripheral.getType
            and peripheral.getType(name) == "modem" then
            count = count + 1
        end
    end

    return count
end

function module.run(context)
    local results = {}
    local tempPath = ".mcnet/diagnostic.tmp"
    local directory = fs.getDir(tempPath)

    if directory ~= ""
        and not fs.exists(directory) then
        fs.makeDir(directory)
    end

    local file = fs.open(tempPath, "w")

    if file then
        file.write("MCNET")
        file.close()

        local readFile =
            fs.open(tempPath, "r")

        local contents =
            readFile
            and readFile.readAll()
            or ""

        if readFile then
            readFile.close()
        end

        fs.delete(tempPath)

        add(
            results,
            "Filesystem",
            contents == "MCNET",
            contents == "MCNET"
                and "Read/write OK"
                or "Readback failed"
        )
    else
        add(
            results,
            "Filesystem",
            false,
            "Could not write test file"
        )
    end

    if http and http.get then
        local response, reason =
            http.get(
                context.baseUrl
                .. "mcnet-manifest.lua"
            )

        if response then
            local contents =
                response.readAll()

            response.close()

            add(
                results,
                "Internet",
                contents and #contents > 0,
                "Manifest bytes: "
                    .. tostring(
                        contents
                        and #contents
                        or 0
                    )
            )
        else
            add(
                results,
                "Internet",
                false,
                tostring(reason)
            )
        end
    else
        add(
            results,
            "Internet",
            false,
            "HTTP unavailable"
        )
    end

    local missing = {}

    for _, path in ipairs(
        context.requiredFiles or {}
    ) do
        if not fs.exists(path) then
            table.insert(
                missing,
                path
            )
        end
    end

    add(
        results,
        "Core files",
        #missing == 0,
        #missing == 0
            and "All present"
            or tostring(#missing)
                .. " missing"
    )

    local device =
        context.deviceModule.load(
            nil,
            context.version,
            context.protocol
        )

    local valid, reason =
        context.deviceModule.validate(
            device
        )

    add(
        results,
        "Device config",
        valid,
        valid
            and device.address
            or reason
    )

    local modems =
        module.countModems()

    add(
        results,
        "Modem",
        modems > 0,
        tostring(modems)
            .. " detected"
    )

    local width, height =
        context.ui.getSize()

    add(
        results,
        "Display",
        width >= 18
            and height >= 10,
        tostring(width)
            .. "x"
            .. tostring(height)
            .. " "
            .. context.ui.getLayout().mode
    )

    if context.network then
        local status =
            context.network.getStatus()

        local networkPassed =
            status.enabled
            and status.configured
            and status.modemReady

        local detail =
            tostring(status.role)
            .. " on channel "
            .. tostring(status.channel)

        if status.role == "ENDPOINT" then
            detail =
                detail
                .. " | tower "
                .. tostring(
                    status.selectedTower
                    or "NONE"
                )
        else
            detail =
                detail
                .. " | "
                .. tostring(status.neighbours)
                .. " neighbours | "
                .. tostring(status.localEndpoints)
                .. " endpoints"
        end

        add(
            results,
            "MCNet network",
            networkPassed,
            detail
        )
    end

    return results
end

return module
