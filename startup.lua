Logging = require("src/logging")
Validating = require("src/validation")
Button = require("src/widgets").Button
Group = require("src/widgets").Group
Functions = require("src/function")


function CreateConfig ()
    local config = {}
    config.version = VERSION
    config.updateInterval = 5
    config.forceHeadless = false
    config.testPerformance = false
    config.lastTab = 0
    config.logging = {}
    config.logging.logFile = "crr.log"
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

function LoadConfig ()
    local config = {}
    local newConfig = CreateConfig()
    Logging:setLogConfig(newConfig.logging)
    if not fs.exists("config.json") then
        Logging:INFO("No config file found, creating default config")
        config = newConfig
        SaveConfig(config)
    else
        local file = fs.open("config.json", "r")
        if file then
            local data = file.readAll()
            file.close()
            local status, err = pcall(function () config = textutils.unserializeJSON(data) end)
            if not status then
                Logging:ERROR("Couldn't parse config file, using default config")
                Logging:DEBUG("Error: " .. err)
                shell.run("rename", "config.json", "config.json.bak")
                config = newConfig
                config.logging.logLevel = "DEBUG"
                SaveConfig(config)
            else
                local validResult = Validating.config(config)
                -- 1: Valid, 0: Outdated, -1: Invalid
                if validResult == 1 then
                    Logging:setLogConfig(config.logging)
                    Logging:INFO("Config loaded")
                elseif validResult == 0 then -- ToDo: If updated config version, convert to new version
                    Logging:WARNING("Config is outdated, updating")
                    Logging:DEBUG("Old config version: " .. config.version)
                    shell.run("rename", "config.json", "config.json.bak")
                    local refConfig = CreateConfig()
                    for key, value in pairs(config) do
                        -- Insert here when config keys are renamed
                        if refConfig[key] == nil then
                            Logging:WARNING("Removing outdated config key: " .. key)
                        elseif key ~= "version" then
                            if type(value) == "table" then
                                refConfig[key] = MergeTable(refConfig[key], value)
                            else
                                refConfig[key] = value
                            end
                        end
                    end
                    config = refConfig
                    SaveConfig(config)
                elseif validResult == -1 then
                    Logging:ERROR("Invalid config, using default config")
                    shell.run("rename", "config.json", "config.json.bak")
                    config = newConfig
                    SaveConfig(config)
                end
            end
        else
            Logging:ERROR("Couldn't open config file, using default config")
            shell.run("rename", "config.json", "config.json.bak")
            config = newConfig
            SaveConfig(config)
        end
    end
    return config
end

function SaveConfig (config)
    local validConfig = Validating.config(config)
    local file = fs.open("config.json", "w")
    if validConfig == 1 then
        if currentTab == nil then
            currentTab = 0
        end
        config.lastTab = currentTab
        file.write(PrettyJSON(textutils.serializeJSON(config)))
    else
        Logging:ERROR("Invalid config, saving default config")
        Logging:DEBUG("Config status: " .. validConfig)
        file.write(PrettyJSON(textutils.serializeJSON(CreateConfig())))
    end
end

function IsDirectPeripheral (per)
    if per == nil then
        Logging:ERROR("Peripheral not found")
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

function ScanPeripherals ()
    if not Config.forceHeadless then
        monitor = peripheral.find("monitor")
        displayMode = true
        if not monitor then
            Logging:WARNING("Couldn't connect to monitor")
            Logging:INFO("Running in headless mode")
            displayMode = false
        else
            monitor.setBackgroundColor(colors.black)
            monitor.setTextColor(colors.white)
            monitor.clear()

            monitor.setTextScale(0.5)
            local width, height = monitor.getSize()
            Logging:DEBUG("Monitor size: " .. width .. "x" .. height)
            if width < 57 or height < 24 then
                monitor.setCursorPos(1, 1)
                monitor.write("Monitor too small")
                monitor.setCursorPos(1, 2)
                monitor.write("At least 3x2 required")
                Logging:WARNING("Monitor too small, at least 3x2 required")
                Logging:INFO("Running in headless mode")
                displayMode = false
            else
                if not monitor.isColor() then
                    displayMode = false
                    Logging:WARNING("Monitor must be an Advanced Monitorn, running in headless mode")
                end
            end
        end
    else
        displayMode = false
        Logging:INFO("Running in headless mode (forced)")
    end
    local meBridge = peripheral.find("meBridge")
    if meBridge then
        bridge = meBridge
        ExecutionMode = "ME"
        if not bridge.getEnergyUsage() then
            Logging:ERROR("ME Bridge not connected or ME system not working")
        else
            Logging:INFO("ME Bridge connected")
        end
    end
    if not ExecutionMode then
        local rsBridge = peripheral.find("rsBridge")
        if rsBridge then
            bridge = rsBridge
            ExecutionMode = "RS"
            if not bridge.getEnergyUsage() then
                Logging:ERROR("RS Bridge not connected or RS system not working")
            else
                Logging:INFO("RS Bridge connected")
            end
        end
    end
    if not ExecutionMode then
        Logging:WARNING("No ME/RS bridge found")
        if not displayMode then
            Logging:ERROR("Running in headless mode, stopping")
            startupSuccess = false
            return
        end
        Logging:INFO("Running in display only mode")
        ExecutionMode = "DP"
    end
    colony = peripheral.find("colonyIntegrator")
    if not colony then
        startupSuccess = false
        Logging:ERROR("Colony Integrator not found")
    else
        if not colony.isInColony() then
            startupSuccess = false
            Logging:ERROR("Colony Integrator not inside a colony")
        else
            Logging:INFO("Colony Integrator connected")
        end
    end
    if Config.wifi.wifiEnable then
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
            Logging:WARNING("Wirless modem not found")
        else
            wifi.open(Config.wifi.sendChannel)
            Logging:INFO("WIFI enabled")
        end
    else
        Logging:INFO("WIFI disabled")
    end

    if ExecutionMode ~= "DP" then
        local peripherals = peripheral.getNames()
        local found = false
        for _, p in ipairs(peripherals) do
            for _, method in ipairs(peripheral.getMethods(p)) do
                if method == "pushItems" then
                    found = true
                    outputInventory = p
                    Logging:INFO("Output inventory found")
                    Logging:DEBUG("Output inventory: " .. p)
                    goto outputFound
                end
            end
        end
        ::outputFound::
        if not found then
            ExecutionMode = "NI"
            Logging:ERROR("No output inventory found")
        else
            local bridgeConnectionType = IsDirectPeripheral(bridge)
            if not IsDirectPeripheral(outputInventory) == bridgeConnectionType then
                Logging:ERROR("Output inventory not connected to the same network as the ME/RS bridge")
                ExecutionMode = "NI"
            end
        end
    end
end

function CallbackRefresh ()
    Logging:DEBUG("Refresh callback")
    GetInputs(false)
    if widgets.autoButton.active then
        if not moveItems() then
            ExecutionMode = "NI"
        end
    end
end

function CallbackScroll (direction)
    Logging:DEBUG("Scroll callback")
    if direction then
        LineOffset = LineOffset + 1
    else
        LineOffset = LineOffset - 1
    end
    if LineOffset < 0 then
        LineOffset = 0
    end
end

function CallbackTab (tab)
    local maxTabs = 7
    Logging:DEBUG("Tab callback")
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
    Config.lastTab = currentTab
    SaveConfig(Config)
    Logging:DEBUG("New tab: " .. currentTab)
    LineOffset = 0
end

function CallbackSettingsChange ()
    Config.allowedRequests.enabled = widgets.filterRequests.active
    Config.allowedRequests.builder = widgets.filterBuilders.active
    Config.wifi.wifiEnable = widgets.wifiSettings.active
end

function ResetDisplay(mon)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.setTextScale(0.5)
    mon.clear()
end

function InitializeDisplay(mon)
    Widgets = {}
    -- All tabs
    Widgets[-1] = {"autoButton", "exitButton", "scrollUpButton", "scrollDownButton", "tabLeftButton", "tabRightButton"}
    -- Requests
    Widgets[0] = {"allGroupRequests"}
    -- Work Orders
    Widgets[1] =  {}
    -- Citizens
    Widgets[2] = {}
    -- Visitors
    Widgets[3] = {}
    -- Buildings
    Widgets[4] = {}
    -- Research
    Widgets[5] = {}
    -- Stats
    Widgets[6] = {}
    -- Settings
    Widgets[7] = {"saveSettings", "filterRequests", "filterBuilders", "wifiSettings"}
    ResetDisplay(mon)
    Builders, BuilderCount = getBuilders()
    local width, height = mon.getSize()
    -- UP | DOWN | Requests | Work Orders | Citizens | Visitors | Buildings | Research | Stats
    widgets = {}
    widgets.autoButton = Button.new(width - 15, 1, 6, 1, "Auto", nil, nil, true, mon)
    widgets.autoButton.active = true
    Logging:DEBUG("Added button: " .. widgets.autoButton.label)
    widgets.exitButton = Button.new(width - 9, 1, 6, 1, "Exit", function () Running = false end, nil, false, mon)
    Logging:DEBUG("Added button: " .. widgets.exitButton.label)
    -- Scroll buttons
    widgets.scrollUpButton = Button.new(2, 2, 4, 1, "/\\", CallbackScroll, true, false, mon)
    widgets.scrollUpButton.backgroundInactive = colors.gray
    Logging:DEBUG("Added button: " .. widgets.scrollUpButton.label)
    widgets.scrollDownButton = Button.new(7, 2, 4, 1, "\\/", CallbackScroll, false, false, mon)
    widgets.scrollDownButton.backgroundInactive = colors.gray
    Logging:DEBUG("Added button: " .. widgets.scrollDownButton.label)
    -- Tabs
    widgets.tabLeftButton = Button.new(12, 2, 3, 1, "<", CallbackTab, true, false, mon)
    widgets.tabLeftButton.backgroundInactive = colors.gray
    Logging:DEBUG("Added button: " .. widgets.tabLeftButton.label)
    widgets.tabRightButton = Button.new(18, 2, 3, 1, ">", CallbackTab, false, false, mon)
    widgets.tabRightButton.backgroundInactive = colors.gray
    Logging:DEBUG("Added button: " .. widgets.tabRightButton.label)
    -- Requests groups
    widgets.allGroupRequests = Group.new(4, "All", mon)
    Logging:DEBUG("Added group: " .. widgets.allGroupRequests.label)
    for i, builder in ipairs(Builders) do
        local group = Group.new(4 + i, builder.name .. " (lvl" .. builder.lvl .. ")", mon)
        group.collapsed = true
        widgets[builder.name] = group
        Widgets[0][#Widgets[0] + 1] = builder.name
        Logging:DEBUG("Added group: " .. builder.name)
    end
    -- Settings Buttons
    widgets.saveSettings = Button.new(width - 8, 4, 8, 3, "Save", function () SaveConfig(Config) end, nil, false, mon)
    widgets.saveSettings.backgroundInactive = colors.blue
    Logging:DEBUG("Added button: " .. widgets.saveSettings.label)
    widgets.filterRequests = Button.new(2, 4, 17, 1, "Filter Requests", CallbackSettingsChange, nil, true, mon)
    widgets.filterRequests.active = Config.allowedRequests.enabled
    Logging:DEBUG("Added button: " .. widgets.filterRequests.label)
    widgets.filterBuilders = Button.new(2, 6, 17, 1, "Filter Builders", CallbackSettingsChange, nil, true, mon)
    widgets.filterBuilders.active = Config.allowedRequests.builder
    Logging:DEBUG("Added button: " .. widgets.filterBuilders.label)
    widgets.wifiSettings = Button.new(2, 8, 6, 1, "WIFI", CallbackSettingsChange, nil, true, mon)
    widgets.wifiSettings.active = Config.wifi.wifiEnable
    Logging:DEBUG("Added button: " .. widgets.wifiSettings.label)
end

function RefreshMonitor (mon)
    local width, height = mon.getSize()
    ResetDisplay(mon)
    -- Title | Auto Button | Status
    mon.setBackgroundColor(colors.lightGray)
    mon.setTextColor(colors.black)
    mon.setCursorPos(1, 1)
    mon.write("Colony Resource Requester" .. string.rep(" ", width))
    mon.setCursorPos(width - (16 + string.len("v" .. VERSION)), 1)
    mon.write("v" .. VERSION)
    mon.setCursorPos(width - 2, 1)
    mon.write(ExecutionMode)
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
        widgets.allGroupRequests.LineOffset = LineOffset
        if ColonyRequests ~= nil and ColonyRequests ~= {} then
            for _, item in ipairs(ColonyRequests) do
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
                        widget.LineOffset = LineOffset
                        widget:setOrder(BuilderRequests[i].order)
                        if BuilderRequests[i].items ~= nil then
                            for _, item in ipairs(BuilderRequests[i].items) do
                                if item ~= nil then
                                    widget:addItem({item.name, item.needed, item.available, item.missing, item.status})
                                end
                            end
                        end
                        widget.line = nextLine
                        nextLine = widget.line + widget.lines
                        break
                    end
                end
            end
            i = i + 1
        until i >= BuilderCount
        -- Green: Available, Yellow: Requested, Red: Missing, Blue: Blacklisted | Heartbeat
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(1, height)
        mon.setTextColor(colors.green)
        mon.write("Available")
        mon.setTextColor(colors.yellow)
        mon.write(" Requested")
        mon.setTextColor(colors.red)
        mon.write(" Missing")
        -- ToDo: Uncoment when blacklists are implemented
        -- mon.setTextColor(colors.blue)
        -- mon.write(" Blacklisted")
    elseif currentTab == 1 then
        -- Work Orders
        -- Text color Green: claimed, red: not claimed
        -- no | Type | Building | workOrderType -> level | P
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(1, 3)
        mon.write(string.rep(" ", width))
        mon.setCursorPos(1, 3)
        mon.write("No | Type" .. string.rep(" ", 2) .. "| Building") -- replace no " " with longest type - 5
        local msg = "Work Order | P"
        mon.setCursorPos(width - #msg, 3)
        mon.write(msg)
        mon.setBackgroundColor(colors.lightGray)
        for i, workOrder in ipairs(WorkOrders) do
            local line = 4 + i - 1 - LineOffset
            if i - LineOffset > height - 3 then
                break
            end
            if i - LineOffset >= 1 then
                mon.setCursorPos(1, line)
                mon.write(string.rep(" ", width))
                mon.setCursorPos(1, line)
                local c = colors.black
                if workOrder.claimed == false then
                    c = colors.red
                end
                mon.setTextColor(c)
                local iStr = tostring(i)
                local type = ""
                if workOrder.type == "WorkOrderBuilding" then
                    type = "Builder"
                end
                mon.write(iStr .. string.rep(" ", 4 - #iStr) .. type .. " " .. workOrder.buildingName)
                local msg = ""
                if workOrder.workOrderType == "UPGRADE" then
                    msg = workOrder.workOrderType .. "->" .. workOrder.targetLevel .. " | " .. workOrder.priority
                else
                    msg = workOrder.workOrderType .. " | " .. workOrder.priority
                end
                mon.setCursorPos(width - #msg, line)
                mon.write(msg)
            end
        end
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.green)
        mon.setCursorPos(1, height)
        mon.write("Claimed")
        mon.setTextColor(colors.red)
        mon.write(" Not Claimed")
    elseif currentTab == 2 then
        -- Citizens
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        if LineOffset == 0 then
            mon.setCursorPos(1, 3 - LineOffset)
            mon.write(string.rep(" ", width))
            mon.setCursorPos(1, 3 - LineOffset)
            mon.write("Children: ")
        end
        mon.setBackgroundColor(colors.lightGray)
        local maxLines = 0
        for i, child in ipairs(Children) do
            if i - LineOffset > height - 4 then
                break
            end
            if i - LineOffset >= 1 then
                mon.setCursorPos(1, 4 + i - LineOffset)
                mon.write(string.rep(" ", width))
                mon.setCursorPos(1, 4 + i - LineOffset)
                mon.write(child.name)
            end
            maxLines = i
        end
        local line = 4 + maxLines - LineOffset
        if 4 + maxLines - LineOffset > 2 then
            mon.setBackgroundColor(colors.gray)
            mon.setCursorPos(1, 4 + maxLines - LineOffset)
            mon.write(string.rep(" ", width))
            mon.setCursorPos(1, 4 + maxLines - LineOffset)
            mon.write("Adults: ")
        end
        for i, citizen in ipairs(Citizens) do
            line = 4 + maxLines + i - LineOffset
            if i - LineOffset > height - 4 then
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
        mon.setTextColor(colors.black)
        for i, visitor in ipairs(Visitors) do
            local line = 3 + (i-1) * 2 - LineOffset
            if i - LineOffset > height - 3 then
                break
            end
            mon.setBackgroundColor(colors.gray)
            mon.setCursorPos(1, line)
            mon.write(string.rep(" ", width))
            mon.setCursorPos(1, line)
            mon.write(visitor.name)
            mon.setCursorPos(1, line + 1)
            mon.setBackgroundColor(colors.lightGray)
            mon.write(string.rep(" ", width))
            mon.setCursorPos(1, line + 1)
            mon.write("Cost: " .. visitor.recruitCost.count .. " * " .. visitor.recruitCost.displayName)
        end
    elseif currentTab == 4 then
        -- Buildings
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(1, 3)
        mon.write(string.rep(" ", width))
        mon.setCursorPos(1, 3)
        -- no | style | type | (level|maxLevel) | priority
        mon.write("No | Style" .. string.rep(" ", #Buildings[1].style - 6) .. "| Type")
        local msg = "(Level|MaxLevel) | P"
        mon.setCursorPos(width - #msg, 3)
        mon.write(msg)
        mon.setBackgroundColor(colors.lightGray)
        for i, building in ipairs(Buildings) do
            mon.setTextColor(colors.black)
            local line = 4 + i - 1 - LineOffset
            if i - LineOffset > height - 3 then
                break
            end
            if i - LineOffset >= 1 then
                -- textcolor: green: ok, yellow: upgrading, orange: not guarded, red: not built
                -- style .. " " .. type .. " (" .. level .. "|" .. maxLevel .. ") P: " .. priority
                mon.setCursorPos(1, line)
                mon.write(string.rep(" ", width))
                mon.setCursorPos(1, line)
                local c = colors.green
                if not building.built then
                    c = colors.red
                elseif not building.guarded then
                    c = colors.orange
                elseif building.isWorkingOn then
                    c = colors.yellow
                end
                mon.setTextColor(c)
                local iStr = tostring(i)
                mon.write(iStr .. string.rep(" ", 4 - #iStr) .. building.style .. " " .. building.type:gsub("^%l", string.upper))
                local msg = "(" .. building.level .. "|" .. building.maxLevel .. ") | " .. building.priority
                mon.setCursorPos(width - #msg, line)
                mon.write(msg)
            end
        end
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(1, height)
        mon.setTextColor(colors.green)
        mon.write("OK")
        mon.setTextColor(colors.yellow)
        mon.write(" Upgrading")
        mon.setTextColor(colors.orange)
        mon.write(" Not Guarded")
        mon.setTextColor(colors.red)
        mon.write(" Not Built")
    elseif currentTab == 5 then
        -- Research
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(1, 3)
        mon.write(string.rep(" ", width))
        mon.setCursorPos(1, 3)
        mon.write("Finished Research:")
        mon.setBackgroundColor(colors.lightGray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(2, 4)
        for i, res in ipairs(CompletedResearch) do
            if i - LineOffset > height - 5 then
                break
            end
            if i - LineOffset >= 1 then
                mon.setCursorPos(1, 3 + i - LineOffset)
                mon.write(string.rep(" ", width))
                mon.setCursorPos(2, 3 + i - LineOffset)
                mon.write(res.name)
            end
        end
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(width / 2, 3)
        mon.write("Current Research:")
        mon.setBackgroundColor(colors.lightGray)
        mon.setTextColor(colors.black)
        mon.setCursorPos(width / 2, 4)
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.white)
        mon.setCursorPos(1, 4)
        for i, res in ipairs(CurrentResearch) do
            if i - LineOffset > height - 4 then
                break
            end
            if i - LineOffset >= 1 then
                mon.write(res.name)
                mon.setCursorPos(width / 2, 4 + i - LineOffset)
            end
        end
    elseif currentTab == 6 then
        -- Stats
        mon.setBackgroundColor(colors.lightGray)
        mon.setTextColor(colors.black)
        for i = 1, 10 do
            mon.setCursorPos(1, i + 2)
            mon.write(string.rep(" ", width))
        end
        mon.setCursorPos(2, 3)
        mon.write("Colony: " .. ColonyName)
        mon.setCursorPos(2, 4)
        mon.write("Citizens: " .. CurrentCitizen .. "/" .. MaxCitizens)
        mon.setCursorPos(2, 5)
        mon.write("Children: " .. #Children)
        mon.setCursorPos(2, 6)
        mon.write("Idle Citizens: " .. IdleCitizens)
        mon.setCursorPos(2, 7)
        mon.write("Homeless Citizens: " .. HomlessCitizens)
        mon.setCursorPos(2, 8)
        mon.write("Jobless Citizens: " .. JoblessCitizens)
        mon.setCursorPos(2, 9)
        mon.write("Happiness: " .. (math.floor(Happiness * 10)) / 10)
        mon.setCursorPos(2, 10)
        local attackText = ""
        if UnderAttack then
            mon.setBackgroundColor(colors.red)
            attackText = "Yes"
        else
            mon.setBackgroundColor(colors.green)
            attackText = "No"
        end
        mon.write("Under Attack: " .. attackText)
        mon.setBackgroundColor(colors.lightGray)
        mon.setCursorPos(2, 11)
        mon.write("Graves: " .. Graves)
        mon.setCursorPos(2, 12)
        mon.write("Buildings: " .. BuilderCount)

    end
    for _, index in ipairs(Widgets[-1]) do
        if widgets[index] then
            widgets[index]:render()
        end
    end
    for _, index in ipairs(Widgets[currentTab]) do
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

function CheckResearch(res)
    if type(res) == "table" then
        if res.status == "FINISHED" then
            table.insert(CompletedResearch, res)
        elseif res.status == "IN_PROGRESS" then
            table.insert(CurrentResearch, res)
        end
        if res.children ~= nil then
            for _, child in ipairs(res.children) do
                CheckResearch(child)
            end
        end
    else
        Logging:ERROR("Research is not a table")
    end
end

function GetCraftingCpus()
    local cpus = bridge.getCraftingCPUs()
    local freeCPUs = 0
    if not cpus then
        Logging:ERROR("No Crafting CPUs found, ME system not working?")
    else
        freeCPUs = 0
        for _, cpu in ipairs(cpus) do
            if cpu.isBusy == false then
                freeCPUs = freeCPUs + 1
            end
        end
    end
    return cpus, freeCPUs
end

function filterRequest(request)
    -- "Profession Name"
    -- Remove profession from request target
    local citizen = ""
    local i = 0
    for text in request.target:gmatch("%S+") do
        if i > 0 then
            citizen = citizen .. " " .. text
        end
        i = i + 1
    end
    citizen = citizen:sub(2) -- Remove leading space
    -- Get citizen work type
    local workType = ""
    for _, citizen in ipairs(Citizens) do
        if citizen.name == citizen then
            buildingType = citizen.work.type
            break
        end
    end
    if Config.allowedRequests[workType] then
        return true
    end
    return false
end

function OverwriteItem(item)
    if item.components ~= nil and (ExecutionMode ~= "DP") then -- ! Temporary fix for wrong fingerprint from colonyIntegrator
        local _item, err = bridge.getItem({name=item.name, nbt=item.components})
        if _item ~= nil and err == nil then
            item.fingerprint = _item.fingerprint
        end
    end
end

function SetItemStatus(item, crafting)
    if crafting then
        item.status = "c"
    elseif item.missing > 0 then
        item.status = "m"
    else
        item.status = "a"
    end
end

function GetInputs(skip, tab)
    if tab == nil then
        tab = currentTab
    end

    if ExecutionMode == "ME" and not skip then
        _, FreeCPUs = GetCraftingCpus()
    end
    if CurrentInputIteration == 0 then -- Colony Requests
        ColonyRequests = {}
        local rawColonyRequests = colony.getRequests()
        for _, colonyRequest in ipairs(rawColonyRequests) do
            -- Check invalid requests
            if not Validating.requestItem(colonyRequest) then
                Logging:WARNING("Invalid request")
                Logging:DEBUG("Request: " .. textutils.serializeJSON(colonyRequest))
                goto continue
            end
            -- Do the filtering
            local allowedRequest = false
            if Config.allowedRequests.enabled then
                allowedRequest = filterRequest(colonyRequest)
            else
                allowedRequest = true
            end
            if allowedRequest then
                for _, requestedItem in ipairs(colonyRequest.items) do
                    -- Overwride wrong fingerprint from colonyIntegrator (1.21+)
                    OverwriteItem(requestedItem)
                    -- Check if item is allready in requested
                    local found = false
                    if ColonyRequests[requestedItem.fingerprint] ~= nil then
                        local item = ColonyRequests[requestedItem.fingerprint]
                        item.needed = item.needed + requestedItem.count
                        if item.needed > item.available then
                            item.missing = item.needed - item.available
                        end
                        if ExecutionMode ~= "DP" then
                            SetItemStatus(item, bridge.isItemCrafting({fingerprint=requestedItem.fingerprint}))
                        else
                            SetItemStatus(item, false)
                        end
                        ColonyRequests[requestedItem.fingerprint] = item
                        found = true
                        break
                    end
                    -- If item is not in requested, add it
                    if not found then
                        local item = {
                            name = requestedItem.displayName,
                            fingerprint = requestedItem.fingerprint
                        }
                        -- Exception for fuel as the colony request an enormous amount of fuel
                        if colonyRequest.name == "Fuel" then
                            item.needed = requestedItem.count * colonyRequest.minCount
                        else
                            item.needed = requestedItem.count * colonyRequest.count
                        end
                        if ExecutionMode == "DP" then
                            item.status = "m"
                            item.available = 0
                            item.missing = item.needed
                        else
                            local availableItem, err = bridge.getItem({fingerprint=requestedItem.fingerprint})
                            if err ~= nil then
                                Logging:DEBUG("Error getting item: " .. err)
                            end
                            local status = "m"
                            if Validating.bridgeItem(availableItem) then
                                if item.needed > availableItem.amount then
                                    if bridge.isItemCrafting({fingerprint=requestedItem.fingerprint}) then
                                        status = "c"
                                    end
                                else
                                    status = "a"
                                end
                                item.status = status
                                item.available = availableItem.amount
                                item.missing = item.needed - availableItem.amount
                                if item.missing < 0 then
                                    item.missing = 0
                                end
                            else
                                item.status = "m"
                                item.available = 0
                                item.missing = item.needed
                            end
                        end
                        ColonyRequests[item.fingerprint] = item
                    end
                end
            end
            ::continue::
        end

    else -- Builder Requests
        Builders, BuilderCount = getBuilders()
        if BuilderCount > 0 then
            -- Get request for this builder
            local builder = Builders[CurrentInputIteration]
            if builder ~= nil then
                local builderRequests = colony.getBuilderResources(builder.pos)
                if builderRequests == nil then
                    BuilderRequests[builder.id] = {}
                else
                    BuilderRequests[builder.id] = {}
                    BuilderRequests[builder.id].order = builder.order
                    BuilderRequests[builder.id].items = {}
                    for _, builderRequest in ipairs(builderRequests) do
                        if Validating.builderRequest(builderRequest) then
                            local builderItem = builderRequest.item
                            -- Overwride wrong fingerprint from colonyIntegrator (1.21+)
                            OverwriteItem(builderItem)
                            -- Check if item is allready in requested
                            local found = false
                            if BuilderRequests[builder.id][builderItem.fingerprint] ~= nil then
                                local item = BuilderRequests[builder.id][builderItem.fingerprint]
                                item.needed = item.needed + builderRequest.item.count * builderRequest.needed
                                if item.needed > item.available then
                                    item.missing = item.needed - item.available
                                end
                                SetItemStatus(item, builderRequest.delivering)
                                BuilderRequests[builder.id][builderItem.fingerprint] = item
                                found = true
                                break
                            end
                            if not found then
                                local item = {
                                    name = builderItem.displayName,
                                    fingerprint = builderItem.fingerprint,
                                    needed = builderRequest.item.count * builderRequest.needed,
                                    available = builderRequest.available,
                                    missing = builderRequest.item.count * builderRequest.needed - builderRequest.available
                                }
                                if item.missing < 0 then
                                    item.missing = 0
                                end
                                SetItemStatus(item, builderRequest.delivering)
                                BuilderRequests[builder.id][builderItem.fingerprint] = item
                            end
                        end
                    end
                end
            end
        end
    end
    CurrentInputIteration = CurrentInputIteration + 1
    if CurrentInputIteration > BuilderCount then
        CurrentInputIteration = 0
    end

    if tab == 1 then -- Work Orders
        WorkOrders = colony.getWorkOrders()

    elseif tab == 2 or tab == 6 then -- Citizens or Stats
        Citizens = colony.getCitizens()
        CurrentCitizen = #Citizens
        MaxCitizens = colony.maxOfCitizens()
        IdleCitizens = 0
        HomlessCitizens = 0
        JoblessCitizens = 0
        Children = {}
        for _, citizen in ipairs(Citizens) do
            if citizen.isIdle then
                IdleCitizens = IdleCitizens + 1
            end
            if citizen.home == nil or citizen.home == {} then
                HomlessCitizens = HomlessCitizens + 1
            end
            if citizen.work == nil or citizen.work == {} then
                JoblessCitizens = JoblessCitizens + 1
            end
            if citizen.age == "child" then
                table.insert(Children, citizen)
            end
        end
        -- Stats
        Happiness = colony.getHappiness()
        UnderAttack = colony.isUnderAttack()
        Graves = colony.amountOfGraves()
        ColonyName = colony.getColonyName()
        Visitors = colony.getVisitors()
        CurrentVisitor = #Visitors

    elseif tab == 3 then-- Visitors
        Visitors = colony.getVisitors()
        CurrentVisitor = #Visitors

    elseif tab == 4 then -- Buildings
        Buildings = colony.getBuildings()
        CurrentBuilding = #Buildings

    elseif tab == 5 then -- Research
        local research = colony.getResearch()
        CompletedResearch = {}
        CurrentResearch = {}
        for _, res in pairs(research) do
            for _, child in ipairs(res) do
                CheckResearch(child)
            end
        end
    end
end

function moveItems()
    if CurrentInputIteration ~= 0 then
        return true
    end
    local startTime = os.epoch()
    if ExecutionMode == "ME" or ExecutionMode == "RS" or ExecutionMode == "NI" then
        local empty = true
        if ExecutionMode ~= "NI" then
            if peripheral.call(outputInventory, "list") == nil then
                Logging:ERROR("Output Inventory not found")
                return false
            end
            if not Functions.checkEmptyTable(peripheral.call(outputInventory, "list")) then
                empty = false
            end
        end
        for _, item in ipairs(ColonyRequests) do
            if item.status == "a" then
                if ExecutionMode ~= "NI" then
                    if empty then
                        Logging:DEBUG("Output Inventory empty")
                        Logging:DEBUG("Exporting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.needed)
                        _, err = bridge.exportItemToPeripheral({fingerprint=item.fingerprint, count=item.needed}, outputInventory)
                        if err ~= nil then
                            Logging:DEBUG("Couldn't export item: " .. item.name .. " (" .. item.fingerprint .. ") | Error: " .. err)
                        end
                    else
                        Logging:WARNING("Ouput Inventory not empty")
                        break
                    end
                end
            elseif item.status == "m" then
                if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                    Logging:DEBUG("Item is already crafting: " .. item.name .. " (" .. item.fingerprint .. ")")
                else
                    if item.missing > 0 then
                        if ExecutionMode == "RS" then
                            itenName = ""
                            local status, err = pcall(function () itemName = bridge.getItem({fingerprint=item.fingerprint}).name end)
                            if status then
                                if bridge.isItemCraftable({name=itemName}) then
                                    Logging:DEBUG("Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                                    local _, err = bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                                    if err ~= nil then
                                        Logging:DEBUG("Couldn't craft item: " .. item.name .. " (" .. item.fingerprint .. ") | Error: " .. err)
                                    end
                                else
                                    Logging:DEBUG("Item not craftable: " .. item.name .. " | " .. itemName .. " (" .. item.fingerprint .. ")")
                                end
                            else
                                Logging:DEBUG("Couldn't get item: " .. item.name .. " (" .. item.fingerprint .. ") | Error: " .. err)
                            end
                        elseif ExecutionMode == "ME" then
                            if FreeCPUs > 0 then
                                itenName = ""
                                local status, err = pcall(function () itemName = bridge.getItem({fingerprint=item.fingerprint}).name end)
                                if status then
                                    local _item, err = bridge.getItem({fingerprint=item.fingerprint})
                                    local itemName = _item.name
                                    if err ~= nil then
                                        Logging:DEBUG("Couldn't get item: " .. item.name .. " (" .. item.fingerprint .. ") | Error: " .. err)
                                    end
                                    if bridge.isItemCraftable({name=itemName}) then
                                        Logging:DEBUG("Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                                        _, err = bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                                        if err ~= nil then
                                            Logging:DEBUG("Couldn't craft item: " .. item.name .. " (" .. item.fingerprint .. ") | Error: " .. err)
                                        end
                                        FreeCPUs = FreeCPUs - 1
                                    else
                                        if itemName == nil then
                                            Logging:DEBUG("Item has no recipe: " .. item.name .. " (" .. item.fingerprint .. ")")
                                        else
                                            Logging:DEBUG("Item not craftable: " .. item.name .. " | "  .. itemName .. " (" .. item.fingerprint .. ")")
                                        end
                                    end
                                else
                                    Logging:DEBUG("Couldn't get item: " .. item.name .. " (" .. item.fingerprint .. ") | Error: " .. err)
                                end
                            else
                                Logging:DEBUG("No free Crafting CPUs available")
                            end
                        end
                    else
                        Logging:DEBUG("Item is available: " .. item.name .. " (" .. item.fingerprint .. "), skipping")
                    end
                end
            end
        end
    end
    table.insert(timesMoveItems, os.epoch() - startTime)
    return true
end

function sendWifi(msg)
    if wifi.isOpen(Config.wifi.sendChannel) then
        Logging:DEBUG("Sending message on channel: " .. Config.wifi.sendChannel)
        Logging:DEBUG("Message: " .. msg)
        wifi.transmit(Config.wifi.sendChannel, Config.wifi.receiveChannel, msg)
    else
        Logging:ERROR("WIFI channel closed")
    end
end

function updateWifi()
end

function touchEvent()
    local event, side, x, y = os.pullEvent("monitor_touch")
    if displayMode then
        local hit = false
        for _, index in ipairs(Widgets[-1]) do
            if widgets[index]:clicked(x, y) then
                hit = true
                break
            end
        end
        for _, index in ipairs(Widgets[currentTab]) do
            if widgets[index]:clicked(x, y) then
                hit = true
                break
            end
        end
        if not hit and currentTab == 0 then
            CallbackRefresh()
        end
    end
end

function timerEvent()
    os.pullEvent("timer")
    Logging:DEBUG("Timer event")
    -- Get inputs
    builders, builderCount = getBuilders()
    if ExecutionMode ~= "DP" and bridge ~= nil and bridge.getEnergyUsage() then
        GetInputs()
    elseif ExecutionMode ~= "DP" then
        Logging:ERROR("ME/RS system not working")
        return
    elseif ExecutionMode == "DP" then
        GetInputs(true) -- skip the bridge part
    end
    if widgets.autoButton.active then
        if not moveItems() then
            ExecutionMode = "NI"
        end
    end
    Heartbeat = not Heartbeat
    -- Update display
    if displayMode then
        os.queueEvent("display_update")
    end
end

function terminateEvent()
    local event = os.pullEvent("terminate")
    Running = false
end

function displayUpdateEvent()
    local event = os.pullEvent("display_update")
    if displayMode then
        RefreshMonitor(monitor)
    end
end

function monitorResizeEvent()
    local event = os.pullEvent("monitor_resize")
    if displayMode then
        InitializeDisplay(monitor)
    end
end

function mainLoop ()
    while Running do
        local functions = {
            touchEvent,
            timerEvent,
            terminateEvent,
            displayUpdateEvent,
            monitorResizeEvent
        }
        parallel.waitForAny(table.unpack(functions))
        timerUpdate = os.startTimer(Config.updateInterval)
    end
end

-- Performace tests
timesMoveItems = {}
timesGetInputs = {}
timesUpdateDisplay = {}
-- Start up
VERSION = "0.3.0-dev"
Config = LoadConfig()
Logging:INFO("Starting up, v" .. VERSION)
Running = true
timerUpdate = 0
currentTab = Config.lastTab
LineOffset = 0
Builders = {}
BuilderCount = 0
CurrentInputIteration = 0
ColonyRequests = {}
BuilderRequests = {}
AllowedExport = false
StartupSuccess = true
os.setComputerLabel("Colony Resource Requester")
ScanPeripherals() -- Get all peripherals
if displayMode then
    InitializeDisplay(monitor)
end
if not StartupSuccess then
    Logging:ERROR("Startup failed")
    Running = false
else
    Builders, BuilderCount = getBuilders()
    for i = 1, BuilderCount do
        table.insert(BuilderRequests, {})
    end
    for i = 0, 7 do
        if i == 0 then
            for j = 0, BuilderCount do
                GetInputs(false, i)
            end
        end
        GetInputs(false, i)
    end
    timerUpdate = os.startTimer(5)
    if displayMode then
        os.queueEvent("display_update")
    end
    Logging:INFO("Startup successful")
    mainLoop()
    -- Performance testing
    if Config.testPerformance then
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
        Logging:INFO("moveItems took: " .. tostring(timeMoveItems) .. "ms avg")
        Logging:INFO("moveItems took: " .. tostring(maxTimeMoveItems) .. "ms max")
        Logging:INFO("getInputs took: " .. tostring(timeGetInputs) .. "ms avg")
        Logging:INFO("getInputs took: " .. tostring(maxTimeGetInputs) .. "ms max")
        Logging:INFO("updateDisplay took: " .. tostring(timeUpdateDisplay) .. "ms avg")
        Logging:INFO("updateDisplay took: " .. tostring(maxTimeUpdateDisplay) .. "ms max")
    end
end

if wifi then
    wifi.closeAll()
end
if displayMode then
    ResetDisplay(monitor)
end
SaveConfig(Config)
Logging:INFO("Stopped")
Logging:destroy()
