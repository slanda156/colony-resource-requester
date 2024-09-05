logging = require("src/logging")
Button = require("src/widgets").Button
Group = require("src/widgets").Group

function insertAt (str, char, i)
    return str:sub(1, i) .. char .. str:sub(i + 1)
end

function getIndexes (str, pattern)
    local indexes = {}
    local i = 0
    while true do
        i = string.find(str, pattern, i + 1)
        table.insert(indexes, i)
        if i == nil then
            break
        end
    end
    return indexes
end

function prettyJSON (json)
    local j = json
    local locations = {}
    locations = getIndexes(j, "{")
    for i = 1, #locations do
        j = insertAt(j, "\n", locations[i] + i - 1)
    end
    locations = getIndexes(j, "}")
    for i = 1, #locations do
        j = insertAt(j, "\n", locations[i] + i - 2)
    end
    locations = getIndexes(j, ",")
    for i = 1, #locations do
        j = insertAt(j, "\n", locations[i] + i - 1)
    end
    return j
end

function mergeTable (t, newT)
    local merged = {}
    for key, value in pairs(t) do
        if newT[key] ~= nil then
            if type(value) == "table" then
                merged[key] = mergeTable(value, newT[key])
            else
                merged[key] = newT[key]
            end
        end
    end
    return merged
end

function compareTable (t1, t2)
    for key, value in pairs(t1) do
        if t2[key] == nil then
            return false
        elseif type(value) ~= type(t2[key]) then
            return false
        end
        if type(value) == "table" then
            if not compareTable(value, t2[key]) then
                return false
            end
        end
    end
    return true
end

function validateConfig (config)
    if config == nil then -- Invalid config
        logging:DEBUG("Config is nil")
        return -1
    end
    if config.version == nil then -- Invalid version
        logging:DEBUG("Config version is nil")
        return -1
    end
    if config.version ~= VERSION then -- Outdated version
        logging:DEBUG("Config version is outdated")
        return 0
    end
    local modelConfig = createConfig()
    for key, value in pairs(modelConfig) do
        if config[key] == nil then
            logging:DEBUG("Config key missing: " .. key)
            return -1
        end
        if type(value) == "table" then
            if not compareTable(value, config[key]) then
                logging:DEBUG("Config key invalid: " .. key)
                return -1
            end
        end
    end
    return 1
end

function createConfig ()
    local config = {}
    config.version = VERSION
    config.updateInterval = 15
    config.forceHeadless = false
    config.lastTab = 0
    config.logging = {}
    config.logging.logFile = "config.log"
    config.logging.logMode = "a"
    config.logging.logLevel = "INFO"
    config.logging.logTimeSource = "local"
    config.logging.logTimeFormat = true
    config.allowedRequests = {}
    config.allowedRequests.enabled = false
    config.allowedRequests.builder = true
    config.wifi = {}
    config.wifi.wifiEnable = false
    config.wifi.sendChannel = 600
    config.wifi.receiveChannel = 601
    return config
end

function loadConfig ()
    local config = {}
    if not fs.exists("config.json") then
        logging:INFO("No config file found, creating default config")
        config = createConfig()
        saveConfig(config)
    else
        local file = fs.open("config.json", "r")
        if file then
            local data = file.readAll()
            file.close()
            local status, err = pcall(function () config = textutils.unserializeJSON(data) end)
            if not status then
                logging:ERROR("Couldn't parse config file, using default config")
                logging:DEBUG("Error: " .. err)
                shell.run("rename", "config.json", "config.json.bak")
                config = createConfig()
                saveConfig(config)
            else
                local validResult = validateConfig(config)
                -- 1: Valid, 0: Outdated, -1: Invalid
                if validResult == 1 then
                    logging:INFO("Config loaded")
                elseif validResult == 0 then
                    logging:WARNING("Config is outdated, updating")
                    logging:DEBUG("Old config version: " .. config.version)
                    shell.run("rename", "config.json", "config.json.bak")
                    local newConfig = createConfig()
                    for key, value in pairs(config) do
                        -- Insert here when config keys are renamed
                        if newConfig[key] == nil then
                            loegging.log("WARNING", "Removing outdated config key: " .. key)
                        elseif key ~= "version" then
                            if type(value) == "table" then
                                newConfig[key] = mergeTable(newConfig[key], value)
                            else
                                newConfig[key] = value
                            end
                        end
                    end
                    config = newConfig
                    saveConfig(config)
                elseif validResult == -1 then
                    logging:ERROR("Invalid config, using default config")
                    shell.run("rename", "config.json", "config.json.bak")
                    config = createConfig()
                    saveConfig(config)
                end
            end
        else
            logging:ERROR("Couldn't open config file, using default config")
            shell.run("rename", "config.json", "config.json.bak")
            config = createConfig()
            saveConfig(config)
        end
    end
    return config
end

function saveConfig (config)
    local validConfig = validateConfig(config)
    local file = fs.open("config.json", "w")
    if validConfig == 1 then
        if currentTab == nil then
            currentTab = 0
        end
        config.lastTab = currentTab
        file.write(prettyJSON(textutils.serializeJSON(config)))
    else
        logging:ERROR("Invalid config, saving default config")
        logging:DEBUG("Config status: " .. validConfig)
        file.write(prettyJSON(textutils.serializeJSON(createConfig())))
    end
    logging:INFO("Config saved")
end

function checkIfDirect (per)
    if per == nil then
        logging:ERROR("Peripheral not found")
        return false
    end
    if type(per) == "string" then
        per = peripheral.wrap(per)
    end
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    for _, side in ipairs(sides) do
        if per == side then
            return true
        end
    end
    return false
end

function getPeripherals ()
    if not config.forceHeadless then
        monitor = peripheral.find("monitor")
        displayMode = true
        if not monitor then
            logging:WARNING("Couldn't connect to monitor")
            logging:INFO("Running in headless mode")
            displayMode = false
        else
            monitor.setBackgroundColor(colors.black)
            monitor.setTextColor(colors.white)
            monitor.clear()

            monitor.setTextScale(0.5)
            local width, height = monitor.getSize()
            logging:DEBUG("Monitor size: " .. width .. "x" .. height)
            if width < 57 or height < 24 then
                monitor.setCursorPos(1, 1)
                monitor.write("Monitor too small")
                monitor.setCursorPos(1, 2)
                monitor.write("At least 3x2 required")
                logging:WARNING("Monitor too small, at least 3x2 required")
                logging:INFO("Running in headless mode")
                displayMode = false
            else
                if not monitor.isColor() then
                    displayMode = false
                    logging:WARNING("Monitor must be an Advanced Monitorn, running in headless mode")
                end
            end
        end
    else
        displayMode = false
        logging:INFO("Running in headless mode (forced)")
    end
    local meBridge = peripheral.find("meBridge")
    if meBridge then
        bridge = meBridge
        mode = "ME"
        if not bridge.getEnergyUsage() then
            logging:ERROR("ME Bridge not connected or ME system not working")
        else
            logging:INFO("ME Bridge connected")
        end
    end
    if not mode then
        local rsBridge = peripheral.find("rsBridge")
        if rsBridge then
            bridge = rsBridge
            mode = "RS"
            if not bridge.getEnergyUsage() then
                logging:ERROR("RS Bridge not connected or RS system not working")
            else
                logging:INFO("RS Bridge connected")
            end
        end
    end
    if not mode then
        logging:WARNING("No ME/RS bridge found")
        if not displayMode then
            logging:ERROR("Running in headless mode, stopping")
            startupSuccess = false
            return
        end
        logging:INFO("Running in display only mode")
        mode = "DP"
    end
    colony = peripheral.find("colonyIntegrator")
    if not colony then
        startupSuccess = false
        logging:ERROR("Colony Integrator not found")
    else
        if not colony.isInColony() then
            startupSuccess = false
            logging:ERROR("Colony Integrator not inside a colony")
        else
            logging:INFO("Colony Integrator connected")
        end
    end
    if config.wifi.wifiEnable then
        local modems = peripheral.find("modem")
        if not modems then
            wifi = nil
        else
            local foundWifi = false
            for _, modem in ipairs(modems) do
                if modem.isWireless() then
                    wifi = modem
                    foundWifi = true
                    break
                end
            end
        end
        if wifi == nil then
            logging:WARNING("Wirless modem not found")
        else
            wifi.open(config.wifi.sendChannel)
            logging:INFO("WIFI enabled")
        end
    else
        logging:INFO("WIFI disabled")
    end

    if mode ~= "DP" then
        local peripherals = peripheral.getNames()
        local found = false
        for _, p in ipairs(peripherals) do
            for _, method in ipairs(peripheral.getMethods(p)) do
                if method == "pushItems" then
                    found = true
                    outputInventory = p
                    logging:INFO("Output inventory found")
                    logging:DEBUG("Output inventory: " .. p)
                    break
                end
            end
        end
        if not found then
            mode = "NI"
            logging:ERROR("No output inventory found")
        else
            local bridgeConnectionType = checkIfDirect(bridge)
            if not checkIfDirect(outputInventory) == bridgeConnectionType then
                logging:ERROR("Output inventory not connected to the same network as the ME/RS bridge")
                mode = "NI"
            end
        end
    end
end

function callbackRefresh ()
    logging:DEBUG("Refresh callback")
    getInputs()
    local success = true
    if widgets.autoButton.active then
        success = moveItems()
        if success == false then
            mode = "NI"
        end
    end
    os.cancelTimer(timerUpdate)
    os.cancelTimer(timerIntervall)
    timerUpdate = os.startTimer(1)
    timerIntervall = os.startTimer(config.updateInterval)
end

function callbackScroll (direction)
    logging:DEBUG("Scroll callback")
    if direction then
        lineOffset = lineOffset + 1
    else
        lineOffset = lineOffset - 1
    end
    if lineOffset < 0 then
        lineOffset = 0
    end
end

function callbackTab (tab)
    local maxTabs = 7
    logging:DEBUG("Tab callback")
    if tab then
        currentTab = currentTab - 1
    else
        currentTab = currentTab + 1
    end
    if currentTab < 0 then
        currentTab = maxTabs
    elseif currentTab > maxTabs then
        currentTab = 0
    end
    logging:DEBUG("New tab: " .. currentTab)
    lineOffset = 0
end

function callbackSettings ()
    config.allowedRequests.enabled = widgets.filterRequests.active
    config.allowedRequests.builder = widgets.filterBuilders.active
    config.wifi.wifiEnable = widgets.wifiSettings.active
end

function resetDisplay(mon)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.setTextScale(0.5)
    mon.clear()
end

function setUpDisplay(mon)
    tabWidgets = {}
    -- All tabs
    tabWidgets[-1] = {"autoButton", "exitButton", "scrollUpButton", "scrollDownButton", "tabLeftButton", "tabRightButton"}
    -- Requests
    tabWidgets[0] = {"allGroupRequests"}
    -- Work Orders
    tabWidgets[1] =  {}
    -- Citizens
    tabWidgets[2] = {}
    -- Visitors
    tabWidgets[3] = {}
    -- Buildings
    tabWidgets[4] = {}
    -- Research
    tabWidgets[5] = {}
    -- Stats
    tabWidgets[6] = {}
    -- Settings
    tabWidgets[7] = {"saveSettings", "filterRequests", "filterBuilders", "wifiSettings"}
    resetDisplay(mon)
    if startupSuccess then
        builders, builderCount = getBuilders()
    end
    local width, height = mon.getSize()
    -- UP | DOWN | Requests | Work Orders | Citizens | Visitors | Buildings | Research | Stats
    widgets = {}
    widgets.autoButton = Button.new(width - 15, 1, 6, 1, "Auto", nil, nil, true, mon)
    widgets.autoButton.active = true
    logging:DEBUG("Added button: " .. widgets.autoButton.label)
    widgets.exitButton = Button.new(width - 9, 1, 6, 1, "Exit", function () running = false end, nil, false, mon)
    logging:DEBUG("Added button: " .. widgets.exitButton.label)
    -- Scroll buttons
    widgets.scrollUpButton = Button.new(2, 2, 4, 1, "/\\", callbackScroll, true, false, mon)
    widgets.scrollUpButton.backgroundInactive = colors.gray
    logging:DEBUG("Added button: " .. widgets.scrollUpButton.label)
    widgets.scrollDownButton = Button.new(7, 2, 4, 1, "\\/", callbackScroll, false, false, mon)
    widgets.scrollDownButton.backgroundInactive = colors.gray
    logging:DEBUG("Added button: " .. widgets.scrollDownButton.label)
    -- Tabs
    widgets.tabLeftButton = Button.new(12, 2, 3, 1, "<", callbackTab, true, false, mon)
    widgets.tabLeftButton.backgroundInactive = colors.gray
    logging:DEBUG("Added button: " .. widgets.tabLeftButton.label)
    widgets.tabRightButton = Button.new(18, 2, 3, 1, ">", callbackTab, false, false, mon)
    widgets.tabRightButton.backgroundInactive = colors.gray
    logging:DEBUG("Added button: " .. widgets.tabRightButton.label)
    -- Requests groups
    widgets.allGroupRequests = Group.new(4, "All", mon)
    logging:DEBUG("Added group: " .. widgets.allGroupRequests.label)
    for i, builder in ipairs(builders) do
        local group = Group.new(4 + i, builder.name .. " (lvl" .. builder.lvl .. ")", mon)
        group.collapsed = true
        widgets[builder.name] = group
        tabWidgets[0][#tabWidgets[0] + 1] = builder.name
        logging:DEBUG("Added group: " .. builder.name)
    end
    -- Settings Buttons
    widgets.saveSettings = Button.new(width - 8, 4, 8, 3, "Save", function () saveConfig(config) end, nil, false, mon)
    widgets.saveSettings.backgroundInactive = colors.blue
    logging:DEBUG("Added button: " .. widgets.saveSettings.label)
    widgets.filterRequests = Button.new(2, 4, 17, 1, "Filter Requests", callbackSettings, nil, true, mon)
    widgets.filterRequests.active = config.allowedRequests.enabled
    logging:DEBUG("Added button: " .. widgets.filterRequests.label)
    widgets.filterBuilders = Button.new(2, 6, 17, 1, "Filter Builders", callbackSettings, nil, true, mon)
    widgets.filterBuilders.active = config.allowedRequests.builder
    logging:DEBUG("Added button: " .. widgets.filterBuilders.label)
    widgets.wifiSettings = Button.new(2, 8, 6, 1, "WIFI", callbackSettings, nil, true, mon)
    widgets.wifiSettings.active = config.wifi.wifiEnable
    logging:DEBUG("Added button: " .. widgets.wifiSettings.label)
end

function updateDisplay (mon)
    local width, height = mon.getSize()
    resetDisplay(mon)
    -- Title | Auto Button | Status
    mon.setBackgroundColor(colors.lightGray)
    mon.setTextColor(colors.black)
    mon.setCursorPos(1, 1)
    mon.write("Colony Resource Requester" .. string.rep(" ", width))
    mon.setCursorPos(width - (16 + string.len("v" .. VERSION)), 1)
    mon.write("v" .. VERSION)
    mon.setCursorPos(width - 2, 1)
    mon.write(mode)
    mon.setCursorPos(16, 2)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.write(currentTab)
    mon.setCursorPos(22, 2)
    local tab = ""
    if currentTab == 0 then
        tab = "Requests"
    elseif currentTab == 1 then
        tab = "Work Orders"
    elseif currentTab == 2 then
        tab = "Citizens"
    elseif currentTab == 3 then
        tab = "Visitors"
    elseif currentTab == 4 then
        tab = "Buildings"
    elseif currentTab == 5 then
        tab = "Research"
    elseif currentTab == 6 then
        tab = "Stats"
    elseif currentTab == 7 then
        tab = "Settings"
    end
    mon.write(tab)
    -- Requests | Work Orders | Citizens | Visitors | Buildings | Research | Stats
    if currentTab == 0 then
        -- Item Name | Requested | Available | Missing
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(1, 3)
        mon.write("    " .. "Item Name")
        mon.write(string.rep(" ", (width - 25) - string.len("Item Name")))
        mon.write("|" .. "Req")
        mon.write(string.rep(" ", 6 - string.len("Req")))
        mon.write("|" .. "Avail")
        mon.write(string.rep(" ", 6 - string.len("Avail")))
        mon.write("|" .. "Miss")
        mon.write(string.rep(" ", 6 - string.len("Miss")))
        widgets.allGroupRequests:clear()
        widgets.allGroupRequests.lineOffset = lineOffset
        if allRequests ~= nil and allRequests ~= {} then
            for _, item in ipairs(allRequests) do
                if item then
                    widgets.allGroupRequests:addItem({item.name, item.needed, item.available, item.missing, item.status})
                end
            end
        end
        local i = 0
        local nextLine = widgets.allGroupRequests.line + widgets.allGroupRequests.lines
        local index = ""
        repeat
            index = "Builder " .. i
            for key, widget in pairs(widgets) do
                if widget.type == "group" then
                    if key == index then
                        widget:clear()
                        widget.lineOffset = lineOffset
                        widget:setOrder(builderRequests[i].order)
                        for _, item in ipairs(builderRequests[i].items) do
                            if item ~= nil then
                                widget:addItem({item.name, item.needed, item.available, item.missing, item.status})
                            end
                        end
                        widget.line = nextLine
                        nextLine = widget.line + widget.lines
                        break
                    end
                end
            end
            i = i + 1
        until i == builderCount
        -- Green: Available, Yellow: Requested, Red: Missing, Blue: Blacklisted | Heartbeat
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(1, height)
        mon.setTextColor(colors.green)
        mon.write("Available")
        mon.setTextColor(colors.yellow)
        mon.write(" Requested")
        mon.setTextColor(colors.red)
        mon.write(" Missing")
        mon.setTextColor(colors.blue)
        mon.write(" Blacklisted")
    elseif currentTab == 2 then
        -- Citizens
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        if lineOffset == 0 then
            mon.setCursorPos(1, 3 - lineOffset)
            mon.write(string.rep(" ", width))
            mon.setCursorPos(1, 3 - lineOffset)
            mon.write("Children: ")
        end
        mon.setBackgroundColor(colors.lightGray)
        local maxLines = 0
        for i, child in ipairs(children) do
            if i - lineOffset > height - 4 then
                break
            end
            if i - lineOffset >= 1 then
                mon.setCursorPos(1, 4 + i - lineOffset)
                mon.write(string.rep(" ", width))
                mon.setCursorPos(1, 4 + i - lineOffset)
                mon.write(child.name)
            end
            maxLines = i
        end
        local line = 4 + maxLines - lineOffset
        if 4 + maxLines - lineOffset > 2 then
            mon.setBackgroundColor(colors.gray)
            mon.setCursorPos(1, 4 + maxLines - lineOffset)
            mon.write(string.rep(" ", width))
            mon.setCursorPos(1, 4 + maxLines - lineOffset)
            mon.write("Adults: ")
        end
        for i, citizen in ipairs(citizens) do
            line = 4 + maxLines + i - lineOffset
            if i - lineOffset > height - 4 then
                break
            end
            if line > 2 then
                mon.setBackgroundColor(colors.lightGray)
                mon.setTextColor(colors.black)
                mon.setCursorPos(1, line)
                mon.write(string.rep(" ", width))
                mon.setCursorPos(1, line)
                local g = ""
                if citizen.gender == "female" then
                    g = "F"
                else
                    g = "M"
                end
                if citizen.work ~= nil and citizen.work ~= {} then
                    if citizen.isIdle then
                        mon.setTextColor(colors.yellow)
                    end
                    if citizen.home == nil or citizen.home == {} then
                        mon.setTextColor(colors.blue)
                    end
                    if citizen.health / citizen.maxHealth < 0.5 then
                        mon.setTextColor(colors.red)
                    end
                    mon.write("[" .. g .. "] " .. citizen.name)
                else
                    mon.setTextColor(colors.orange)
                    mon.write("[" .. g .. "] " .. citizen.name)
                end
            end
        end
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.yellow)
        mon.setCursorPos(1, height)
        mon.write("Idle")
        mon.setTextColor(colors.orange)
        mon.write(" Jobless")
        mon.setTextColor(colors.blue)
        mon.write(" Homeless")
        mon.setTextColor(colors.red)
        mon.write(" Health < 50%")
    elseif currentTab == 3 then
        -- Visitors
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        for i, visitor in ipairs(visitors) do
            local line = 4 + i - lineOffset
            if i - lineOffset > height - 3 then
                break
            end
            if line > 2 then
                mon.setCursorPos(1, line)
                mon.write(string.rep(" ", width))
                mon.setCursorPos(1, line)
                mon.write(visitor.name)
            end
            if line + 1 > 2 then
                mon.setCursorPos(1, line + 1)
                mon.setBackgroundColor(colors.lightGray)
                mon.write(string.rep(" ", width))
                mon.setCursorPos(1, line + 1)
                mon.write("Cost: " .. visitor.recruitCost.amount .. " * " .. visitor.recruitCost.displayName)
            end
        end
    elseif currentTab == 5 then
        -- Research
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(1, 4)
        mon.write(string.rep(" ", width))
        mon.setCursorPos(1, 4)
        mon.write("Finished Research:")
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.white)
        mon.setCursorPos(2, 5)
        for i, res in ipairs(completedResearch) do
            if i - lineOffset > height - 5 then
                break
            end
            if i - lineOffset >= 1 then
                mon.write(res.name)
                mon.setCursorPos(2, 5 + i - lineOffset)
            end
        end
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(width / 2, 4)
        mon.write("Current Research:")
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.white)
        mon.setCursorPos(width / 2, 5)
        for i, res in ipairs(currentResearch) do
            if i - lineOffset > height - 5 then
                break
            end
            if i - lineOffset >= 1 then
                mon.write(res.name)
                mon.setCursorPos(width / 2, 5 + i - lineOffset)
            end
        end
    elseif currentTab == 6 then
        -- Stats
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.white)
        mon.setCursorPos(2, 4)
        mon.write("Colony: " .. colonyName)
        mon.setCursorPos(2, 5)
        mon.write("Citizens: " .. #citizens .. "/" .. maxCitizens)
        mon.setCursorPos(2, 6)
        mon.write("Children: " .. #children)
        mon.setCursorPos(2, 7)
        mon.write("Idle Citizens: " .. #idleCitizens)
        mon.setCursorPos(2, 8)
        mon.write("Homeless Citizens: " .. #homlessCitizens)
        mon.setCursorPos(2, 9)
        mon.write("Jobless Citizens: " .. #joblessCitizens)
        mon.setCursorPos(2, 10)
        mon.write("Happiness: " .. (math.floor(happiness * 10)) / 10)
        mon.setCursorPos(2, 11)
        local attackText = ""
        if underAttack then
            mon.setBackgroundColor(colors.red)
            attackText = "Yes"
        else
            mon.setBackgroundColor(colors.green)
            attackText = "No"
        end
        mon.write("Under Attack: " .. attackText)
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(2, 12)
        mon.write("Graves: " .. graves)
        mon.setCursorPos(2, 13)
        mon.write("Buildings: " .. buildingsCount)

    end
    for _, index in ipairs(tabWidgets[-1]) do
        if widgets[index] then
            widgets[index]:render()
        end
    end
    for _, index in ipairs(tabWidgets[currentTab]) do
        if widgets[index] then
            widgets[index]:render()
        end
    end
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.setCursorPos(width - 1, height)
    if Heartbeat then
        mon.setBackgroundColor(colors.black)
    else
        mon.setBackgroundColor(colors.red)
    end
    mon.write("  ")
end

function getBuilders()
    local buildings = colony.getBuildings()
    local builders = {}
    local i = 0
    local orders = {}
    for _, order in ipairs(colony.getWorkOrders()) do
        if order.builder ~= nil then
            local index = tostring(order.builder.x) .. "," .. tostring(order.builder.y) .. "," .. tostring(order.builder.z)
            orders[index] = order
        end
    end
    for _, building in ipairs(buildings) do
        if building.type == "builder" then
            local index = tostring(building.location.x) .. "," .. tostring(building.location.y) .. "," .. tostring(building.location.z)
            table.insert(builders, {name="Builder " .. i, lvl=building.level, pos=building.location, order=orders[index], id=i})
            i = i + 1
        end
    end
    return builders, i
end

function checkResearch(res)
    if type(res) == "table" then
        if res.status == "FINISHED" then
            table.insert(completedResearch, res)
        elseif res.status == "IN_PROGRESS" then
            table.insert(currentResearch, res)
        end
        if res.children ~= nil and res.children ~= {} then
            for _, child in ipairs(res.children) do
                checkResearch(child)
            end
        end
    else
        logging:ERROR("Research is not a table")
    end
end

function getInputs(skip)
    -- Get infos about citizens and visitors
    citizens = colony.getCitizens()
    idleCitizens = {}
    homlessCitizens = {}
    joblessCitizens = {}
    children = {}
    for _, citizen in ipairs(citizens) do
        if citizen.isIdle then
            table.insert(idleCitizens, citizen)
        end
        if citizen.home == nil or citizen.home == {} then
            table.insert(homlessCitizens, citizen)
        end
        if citizen.work == nil or citizen.work == {} then
            table.insert(joblessCitizens, citizen)
        end
        if citizen.age == "child" then
            table.insert(children, citizen)
        end
    end
    buildingsCount = #colony.getBuildings()
    maxCitizens = colony.maxOfCitizens()
    happiness = colony.getHappiness()
    underAttack = colony.isUnderAttack()
    graves = colony.amountOfGraves()
    colonyName = colony.getColonyName()
    visitors = colony.getVisitors()
    completedResearch = {}
    currentResearch = {}
    local research = colony.getResearch()
    for _, res in pairs(research) do
        for _, child in ipairs(res) do
            checkResearch(child)
        end
    end
    -- allRequests -> Holds all items that are requested
    -- builderRequests -> Holds a table for each builder with all items that are requested
    -- item = {name, fingerprint, needed, available, missing, status, [order]} order only with builders

    if mode == "ME" and not skip then
        local cpus = bridge.getCraftingCPUs()
        if not cpus then
            logging:ERROR("No Crafting CPUs found, ME system not working?")
        else
            freeCPUs = 0
            for _, cpu in ipairs(cpus) do
                if cpu.isBusy == false then
                    freeCPUs = freeCPUs + 1
                end
            end
        end
    end

    allRequests = {}
    builderRequests = {}

    for _, builder in ipairs(builders) do
        if not builderRequests[builder.id] then
            builderRequests[builder.id] = {items={}}
        end
        -- Get current build order of each builder
        if builder.order and builder.order ~= {} then
            builderRequests[builder.id].order = builder.order
        end
        local builderResources = colony.getBuilderResources(builder.pos)
        for _, builderRequest in ipairs(builderResources) do
            builderItem = builderRequest.item
            builderItem.needed = builderRequest.needed
            builderItem.available = builderRequest.available
            builderItem.missing = builderRequest.needed - builderRequest.available
            if builderItem.missing < 0 then
                builderItem.missing = 0
            end
            if builderItem.missing > 0 then
                if builderItem.missing <= builderRequest.delivering then
                    builderItem.status = "c"
                else
                    builderItem.status = "m"
                end
            else
                builderItem.status = "a"
            end
            local skipped = false
            if not skipped then
                local item = {
                    name=builderItem.displayName,
                    fingerprint=builderItem.fingerprint,
                    needed=builderItem.needed, available=builderItem.available,
                    missing=builderItem.missing,
                    status=builderItem.status
                }
                table.insert(builderRequests[builder.id].items, item)
            end
        end
    end

    local rawRequests = colony.getRequests()
    for _, request in ipairs(rawRequests) do
        -- check config for allowed requests
        local allowed = false
        if config.allowedRequests.enabled then
            local requestTarget = ""
            local i = 0
            for text in request.target:gmatch("%S+") do
                if i > 0 then
                    requestTarget = requestTarget .. " " .. text
                end
                i = i + 1
            end
            requestTarget = requestTarget:sub(2)
            for _, citizen in ipairs(citizens) do
                if citizen.name == requestTarget then
                    if config.allowedRequests.builder then
                        if citizen.work.type == "builder" then
                            allowed = true
                        end
                    end
                    break
                else
                end
            end
        else
            allowed = true
        end
        if allowed then
            for _, itemRequest in ipairs(request.items) do
                local skipped = false
                for _, existingItem in ipairs(allRequests) do
                    if existingItem.fingerprint == itemRequest.fingerprint then
                        existingItem.needed = existingItem.needed + itemRequest.count
                        skipped = true
                        break
                    end
                end
                if not skipped then
                    local item = {
                        name=itemRequest.displayName,
                        fingerprint=itemRequest.fingerprint,
                        needed=itemRequest.count * request.count
                    }
                    local existingItem = bridge.getItem({fingerprint=item.fingerprint})
                    local status = "m"
                    if existingItem ~= nil and #existingItem > 0 then
                        if item.needed > existingItem.amount then
                            if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                                status = "c"
                            end
                        else
                            status = "a"
                        end
                    else
                        item.status = status
                        item.available = 0
                        item.missing = 0
                    end
                    table.insert(allRequests, item)
                end
            end
        end
    end
end

function moveItems()
    local startTime = os.epoch()
    if mode == "ME" or mode == "RS" or mode == "NI" then
        local empty = true
        if peripheral.call(outputInventory, "list") == nil then
            logging:ERROR("Output Inventory not found")
            return false
        end
        if next(peripheral.call(outputInventory, "list")) ~= nil then
            empty = false
        end
        for _, item in ipairs(allRequests) do
            if item.status == "a" then
                if mode ~= "NI" then
                    if empty then
                        logging:DEBUG("Exporting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.needed)
                        bridge.exportItemToPeripheral({fingerprint=item.fingerprint, count=item.needed}, outputInventory)
                    else
                        logging:WARNING("Ouput Inventory not empty")
                    end
                else
                    logging:DEBUG("Item is available: " .. item.name .. " (" .. item.fingerprint .. "), skipping")
                end
            elseif item.status == "m" then
                if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                    logging:DEBUG("Item is already crafting: " .. item.name .. " (" .. item.fingerprint .. ")")
                else
                    if mode == "RS" then
                        local itenName = ""
                        local status, err = pcall(function () itemName = bridge.getItem({fingerprint=item.fingerprint}).name end)
                        if status then
                            if bridge.isItemCraftable({name=itemName}) then
                                logging:DEBUG("Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                                bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                            else
                                logging:DEBUG("Item not craftable: " .. item.name .. " | " .. itemName .. " (" .. item.fingerprint .. ")")
                            end
                        else
                            logging:DEBUG("Couldn't get item: " .. item.name .. " (" .. item.fingerprint .. ") | Error: " .. err)
                        end
                    elseif mode == "ME" then
                        if freeCPUs > 0 then
                            local itenName = ""
                            local status, err = pcall(function () itemName = bridge.getItem({fingerprint=item.fingerprint}).name end)
                            if status then
                                local itemName = bridge.getItem({fingerprint=item.fingerprint}).name
                                if bridge.isItemCraftable({name=itemName}) then
                                    logging:DEBUG("Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                                    bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                                    freeCPUs = freeCPUs - 1
                                else
                                    if itemName == nil then
                                        logging:DEBUG("Item has no recipe: " .. item.name .. " (" .. item.fingerprint .. ")")
                                    else
                                        logging:DEBUG("Item not craftable: " .. item.name .. " | "  .. itemName .. " (" .. item.fingerprint .. ")")
                                    end
                                end
                            else
                                logging:DEBUG("Couldn't get item: " .. item.name .. " (" .. item.fingerprint .. ") | Error: " .. err)
                            end
                        else
                            logging:DEBUG("No free Crafting CPUs available")
                        end
                    end
                end
            end
        end
    end
    table.insert(timesMoveItems, os.epoch() - startTime)
end

function sendWifi(msg)
    if wifi.isOpen(config.wifi.sendChannel) then
        logging:DEBUG("Sending message on channel: " .. config.wifi.sendChannel)
        logging:DEBUG("Message: " .. msg)
        wifi.transmit(config.wifi.sendChannel, config.wifi.receiveChannel, msg)
    else
        logging:ERROR("WIFI channel closed")
    end
end

function updateWifi()
end

function touchEvent()
    local event, side, x, y = os.pullEvent("monitor_touch")
    if displayMode then
        local hit = false
        for _, index in ipairs(tabWidgets[-1]) do
            if widgets[index]:clicked(x, y) then
                hit = true
                break
            end
        end
        for _, index in ipairs(tabWidgets[currentTab]) do
            if widgets[index]:clicked(x, y) then
                hit = true
                break
            end
        end
        if not hit and currentTab == 0 then
            callbackRefresh()
        end
    end
end

function timerEvent()
    local event, id = os.pullEvent("timer")
    if id == timerUpdate then
        -- Get inputs
        builders, builderCount = getBuilders()
        if mode ~= "DP" and bridge ~= nil and bridge.getEnergyUsage() then
            getInputs(false)
        elseif mode ~= "DP" then
            logging:ERROR("ME/RS system not working")
            logging:INFO("Retrying in 10 seconds")
            timerUpdate = os.startTimer(10)
            return
        elseif mode == "DP" then
            getInputs(true) -- skip the bridge part
        end
        -- Update display
        if displayMode then
            os.queueEvent("display_update")
        end
        Heartbeat = not Heartbeat
        timerUpdate = os.startTimer(1)
    elseif id == timerIntervall then
        local success = true
        if widgets.autoButton.active then
            success = moveItems()
        end
        if success == false then
            mode = "NI"
        end
        timerIntervall = os.startTimer(config.updateInterval)
    end
end

function terminateEvent()
    local event = os.pullEvent("terminate")
    running = false
end

function displayUpdateEvent()
    local event = os.pullEvent("display_update")
    if displayMode then
        updateDisplay(monitor)
    end
end

function monitorResizeEvent()
    local event = os.pullEvent("monitor_resize")
    if displayMode then
        setUpDisplay(monitor)
    end
end

function mainLoop ()
    while running do
        local functions = {
            touchEvent,
            timerEvent,
            terminateEvent,
            displayUpdateEvent,
            monitorResizeEvent
        }
        parallel.waitForAny(table.unpack(functions))
    end
end

-- Clear log file
if logMode == "overwrite" then
    local file = fs.open(logFile, "w")
    file.close()
end
-- Performace tests
testPerformance = true
timesMoveItems = {}
timesGetInputs = {}
timesUpdateDisplay = {}
-- Start up
VERSION = "0.3.0-dev"
logging:INFO("Starting up, v" .. VERSION)
config = loadConfig()
logging:setLogConfig(config.logging)
running = true
timerUpdate = 0
timerIntervall = 0
currentTab = config.lastTab
lineOffset = 0
builders = {}
builderCount = 0
startupSuccess = true
os.setComputerLabel("Colony Resource Requester")
getPeripherals() -- Get all peripherals
if displayMode then
    setUpDisplay(monitor)
end
if not startupSuccess then
    logging:ERROR("Startup failed")
    running = false
else
    logging:INFO("Startup successful")
    timerUpdate = os.startTimer(1)
    timerIntervall = os.startTimer(config.updateInterval)
    mainLoop()
    -- Performance testing
    if testPerformance then
        local timeMoveItems = 0
        local timeGetInputs = 0
        local timeUpdateDisplay = 0
        local maxTimeMoveItems = 0
        local maxTimeGetInputs = 0
        local maxTimeUpdateDisplay = 0
        local i = 0
        for _, t in ipairs(timesMoveItems) do
            timeMoveItems = timeMoveItems + t
            if maxTimeMoveItems < t then
                maxTimeMoveItems = t
            end
        end
        timeMoveItems = timeMoveItems / i
        i = 0
        for _, t in ipairs(timesGetInputs) do
            timeGetInputs = timeGetInputs + t
            if maxTimeGetInputs < t then
                maxTimeGetInputs = t
            end
        end
        timeGetInputs = timeGetInputs / i
        i = 0
        for _, t in ipairs(timesUpdateDisplay) do
            timeUpdateDisplay = timeUpdateDisplay + t
            if maxTimeUpdateDisplay < t then
                maxTimeUpdateDisplay = t
            end
        end
        timeUpdateDisplay = timeUpdateDisplay / i
        i = 0
        logging:INFO("moveItems took: " .. tostring(timeMoveItems) .. "ms avg")
        logging:INFO("moveItems took: " .. tostring(maxTimeMoveItems) .. "ms max")
        logging:INFO("getInputs took: " .. tostring(timeGetInputs) .. "ms avg")
        logging:INFO("getInputs took: " .. tostring(maxTimeGetInputs) .. "ms max")
        logging:INFO("updateDisplay took: " .. tostring(timeUpdateDisplay) .. "ms avg")
        logging:INFO("updateDisplay took: " .. tostring(maxTimeUpdateDisplay) .. "ms max")
    end
end

if wifi then
    wifi.closeAll()
end
if displayMode then
    resetDisplay(monitor)
end
saveConfig(config)
logging:INFO("Stopped")
