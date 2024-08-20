-- Logging configuration
logFile = "colony.log" -- The file to log to
logMode = "overwrite" -- append, overwrite
logLevel = "INFO" -- DEBUG, INFO, WARNING, ERROR
logTimeSource = "local" -- ingame: The in-game time, local: The server time, utc: UTC time
logTimeFormat = true -- false: 12h, true: 24h

-- Runtime configuration
updateInterval = 30 -- in seconds
forceHeadless = false -- Force headless mode
wifiEnable = true -- Enable wifi
wifiSendChannel = 1 -- The channel to use for the wifi messages
wifiReplyChannel = 600 -- The channel to use for the wifi replies

-- Do not change anything below
function log (level, msg)
    if type(level) ~= "string" then
        print("Invalid log level")
        return
    end
    if type(msg) ~= "string" then
        print("Invalid log message")
        return
    end
    local allowedLevels = {DEBUG=0, INFO=1, WARNING=2, ERROR=3}
    if logLevel == "INFO" then
        allowedLevels["DEBUG"] = nil
    elseif logLevel == "WARNING" then
        allowedLevels["DEBUG"] = nil
        allowedLevels["INFO"] = nil
    elseif logLevel == "ERROR" then
        allowedLevels["DEBUG"] = nil
        allowedLevels["INFO"] = nil
        allowedLevels["WARNING"] = nil
    end
    if allowedLevels[level] ~= nil then
        local finalMsg = textutils.formatTime(os.time(logTimeSource), logTimeFormat) .. " - " .. level .. " - " ..  msg
        print(finalMsg)
        local file = fs.open(logFile, "a")
        if type(file) == "string" then
            print("Couldn't open log file")
            print(file)
        else
            file.write(finalMsg .. "\n")
        end
        file.close()
    end
end

function getPeripherals ()
    if not forceHeadless then
        monitor = peripheral.find("monitor")
        displayMode = true
        if not monitor then
            log("WARNING", "Couldn't connect to monitor")
            log("INFO", "Running in headless mode")
            displayMode = false
        else
            local width, height = monitor.getSize()
            if width < 14 or height < 10 then
                log("WARNING", "Monitor too small, at least 3x3 required")
                log("DEBUG", "Monitor size: " .. width .. "x" .. height)
                log("INFO", "Running in headless mode")
                displayMode = false
            else
                if not monitor.isColor() then
                    displayMode = false
                    log("WARNING", "Monitor must be an Advanced Monitorn, running in headless mode")
                else
                    monitor.setBackgroundColor(colors.lightGray)
                    monitor.setTextColor(colors.black)
                    monitor.clear()
                    monitor.setTextScale(2)
                    monitor.setCursorPos(width / 2 - 2, height / 2 - 1)
                    monitor.write("Colony")
                    monitor.setCursorPos(width / 2 - 3, height / 2)
                    monitor.write("Resource")
                    monitor.setCursorPos(width / 2 - 3, height / 2 + 1)
                    monitor.write("Requester")
                end
            end
        end
    else
        displayMode = false
        log("INFO", "Running in headless mode (forced)")
    end
    local meBridge = peripheral.find("meBridge")
    if not meBridge then
        log("WARNING", "ME Bridge not found")
    else
        bridge = meBridge
        mode = "ME"
        if not bridge.getEnergyUsage() then
            log("ERROR", "ME Bridge not connected or ME system not working")
        else
            log("INFO", "ME Bridge connected")
        end
    end
    if not mode then
        local rsBridge = peripheral.find("rsBridge")
        if not rsBridge then
            log("WARNING", "RS Bridge not found")
        else
            bridge = rsBridge
            mode = "RS"
            if not bridge.getEnergyUsage() then
                log("ERROR", "RS Bridge not connected or RS system not working")
            else
                log("INFO", "RS Bridge connected")
            end
        end
    end
    if not mode then
        log("ERROR", "No storage bridge found")
        if displayMode == 0 then
            log("INFO", "Running in headless mode, stopping")
            startupSuccess = false
            return
        end
        log("INFO", "Running in display only mode")
        mode = "DP"
    end
    colony = peripheral.find("colonyIntegrator")
    if not colony then
        startupSuccess = false
        log("ERROR", "Colony Integrator not found")
    else
        if not colony.isInColony() then
            startupSuccess = false
            log("ERROR", "Colony Integrator not inside a colony")
        else
            log("INFO", "Colony Integrator connected")
        end
    end
    if wifiEnable then
        wifi = peripheral.find("modem")
        if not wifi then
            log("WARNING", "Modem not found")
        elseif not wifi.isWireless() then
            log("WARNING", "Modem not wireless")
        else
            wifi.open(wifiSendChannel)
            log("INFO", "WIFI enabled")
        end
    else
        log("INFO", "WIFI disabled")
    end

    if mode ~= "DP" then
        local peripherals = peripheral.getNames()
        local found = false
        for _, p in ipairs(peripherals) do
            for _, method in ipairs(peripheral.getMethods(p)) do
                if method == "pushItems" then
                    found = true
                    outputInventory = p
                    log("INFO", "Output inventory found")
                    log("DEBUG", "Output inventory: " .. p)
                    break
                end
            end
        end
        if not found then
            mode = "NI"
            log("ERROR", "No output inventory found")
        end
    end
    sleep(1)
end

local Group = {}
Group.__index = Group

function Group.new(line, label, mon)
    local self = setmetatable({}, Group)
    self.type = "group"
    self.line = line
    self.lines = 1
    self.label = label
    self.collapsed = false
    self.size = 0
    self.items = {}
    self.monitor = mon
    return self
end

function Group:updateLines()
    if self.collapsed then
        self.lines = 1
    else
        self.lines = 1 + self.size
    end
end

function Group:addItem(item)
    if not item[1] then
        log("ERROR", "Item name missing")
        log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    if not item[2] then
        log("ERROR", "Item needed missing")
        log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    if not item[3] then
        log("ERROR", "Item available missing")
        log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    if not item[4] then
        log("ERROR", "Item missing missing")
        log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    if not item[5] then
        log("ERROR", "Item status missing")
        log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    log("DEBUG", "Adding item to group: " .. item[1])
    table.insert(self.items, item)
    self.size = self.size + 1
    self:updateLines()
end

function Group:removeItem(item)
    for i, v in ipairs(self.items) do
        if v == item then
            table.remove(self.items, i)
            self.size = self.size - 1
            self:updateLines()
            break
        end
    end
end

function Group:clear()
    self.items = {}
    self.size = 0
    self:updateLines()
end

function Group:toggle()
    self.collapsed = not self.collapsed
    self:updateLines()
end

function Group:render()
    local width, height = self.monitor.getSize()
    self.monitor.setBackgroundColor(colors.gray)
    self.monitor.setTextColor(colors.black)
    self.monitor.setCursorPos(1, self.line)
    if self.collapsed then
        self.monitor.write("+ " .. self.size .. " " .. self.label .. ":" .. string.rep(" ", width))
    else
        self.monitor.write("- " .. self.size .. " " .. self.label .. ":" .. string.rep(" ", width))
        self.monitor.setBackgroundColor(colors.lightGray)
        for i, item in ipairs(self.items) do
            if item[1] then
                self.monitor.setCursorPos(1, self.line + i)
                if item[5] == "a" then
                    self.monitor.setTextColor(colors.green)
                elseif item[5] == "c" then
                    self.monitor.setTextColor(colors.yellow)
                elseif item[5] == "m" then
                    self.monitor.setTextColor(colors.red)
                elseif item[5] == "b" then
                    self.monitor.setTextColor(colors.blue)
                else
                    self.monitor.setTextColor(colors.pink)
                end
                self.monitor.write("    " .. item[1])
                self.monitor.write(string.rep(" ", 25 - string.len(item[1])))
                self.monitor.write(" | " .. item[2])
                self.monitor.write(string.rep(" ", 5 - string.len(tostring(item[2]))))
                self.monitor.write(" | " .. item[3])
                self.monitor.write(string.rep(" ", 5 - string.len(tostring(item[3]))))
                self.monitor.write(" | " .. item[4])
                self.monitor.write(string.rep(" ", width))
            end
        end
    end
end

function Group:clicked(x, y)
    if y == self.line then
        self:toggle()
        os.queueEvent("display_update")
        return true
    end
    return false
end

local Button = {}
Button.__index = Button

function Button.new(x, y, width, height, label, callback, mon)
    local self = setmetatable({}, Button)
    self.type = "button"
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.label = label
    self.callback = callback
    self.active = false
    self.monitor = mon
    return self
end

function Button:render()
    self.monitor.setTextColor(colors.black)
    self.monitor.setCursorPos(self.x, self.y)
    if self.active then
        self.monitor.setBackgroundColor(colors.green)
    else
        self.monitor.setBackgroundColor(colors.red)
    end
    self.monitor.write(self.label)
end

function Button:clicked(x, y)
    if x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height then
        log("DEBUG", "Button clicked: " .. self.label)
        if self.callback then
            self.callback()
        end
        self.active = not self.active
        os.queueEvent("display_update")
        return true
    end
    return false
end

function resetDisplay(mon)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.setTextScale(0.5)
    mon.clear()
end

function setUpDisplay(mon)
    resetDisplay(mon)
    local width, height = mon.getSize()
    log("DEBUG", "Monitor size: " .. width .. "x" .. height)
    widgets = {}
    widgets.autoButton = Button.new(width / 2 + 4, 1, 1, 5, "Auto", nil, mon)
    widgets.autoButton.active = true
    log("DEBUG", "Added button: " .. widgets.autoButton.label)
    -- widgets.refreshButton = Button.new(width / 2 + 9, 1, 1, 5, "Refresh", callbackRefresh, mon)
    -- log("DEBUG", "Added button: " .. widgets.refreshButton.label)
    widgets.exitButton = Button.new(width / 2 + 17, 1, 1, 5, "Exit", function() running = false end, mon)
    log("DEBUG", "Added button: " .. widgets.exitButton.label)
    widgets.generalGroup = Group.new(3, "General", mon)
    log("DEBUG", "Added group: " .. widgets.generalGroup.label)
    for i, builder in ipairs(builders) do
        local group = Group.new(3 + i, builder.name .. " (lvl" .. builder.lvl .. ")", mon)
        widgets[builder.name] = group
        log("DEBUG", "Added group: " .. builder.name)
    end
end

function callbackRefresh ()
    log("DEBUG", "Refresh callback")
    getInputs()
    if widgets.autoButton.active then
        moveItems()
    end
    if displayMode then
        os.queueEvent("display_update")
    end
    iteration = 0
    os.cancelTimer(timerID)
    timerID = os.startTimer(1)
end

function updateDisplay (mon)
    local width, height = mon.getSize()
    local maxLines = height - 3
    resetDisplay(mon)
    -- Title | Auto Button | Status
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1, 1)
    mon.write("Colony Resource Requester" .. string.rep(" ", width))
    mon.setCursorPos(width - 2, 1)
    mon.write(mode)
    -- Item Name | Requested | Available | Missing | Status
    widgets.generalGroup:clear()
    for _, item in ipairs(remainingRequests) do
        if item then
            widgets.generalGroup:addItem({item.name, item.needed, item.available, item.missing, item.status})
        end
    end
    local i = 0
    local nextLine = widgets.generalGroup.line + widgets.generalGroup.lines
    local index = ""
    repeat
        index = "Builder " .. i
        for key, widget in pairs(widgets) do
            if widget.type == "group" then
                if key == index then
                    widget:clear()
                    for _, item in ipairs(builderRequests[i]) do
                        if item then
                            widget:addItem({item.name, item.needed, item.available, item.missing, item.status})
                        end
                    end
                    widget.line = nextLine
                    nextLine = widget.line + widget.lines
                    break
                end
            end
        end
        -- widgets[index].line = nextLine
        i = i + 1
    until i == builderCount
    for _, widget in pairs(widgets) do
        widget:render()
    end
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
    mon.setCursorPos(width - 5, height)
    mon.setTextColor(colors.white)
    mon.write(updateInterval - iteration .. "s")
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
    for _, building in ipairs(buildings) do
        if building.type == "builder" then
            table.insert(builders, {name="Builder " .. i, lvl=building.level, pos=building.location, id=i})
            i = i + 1
        end
    end
    return builders, i
end

function getInputs()
    -- allRequests -> Holds all items that are requested
    -- builderRequests -> Holds a table for each builder with all items that are requested
    -- remainingRequests -> Holds all items that are requested but not by a builder
    -- item = {name, fingerprint, needed, available, missing, status}

    if mode == "ME" then
        local cpus = bridge.getCraftingCPUs()
        freeCPUs = 0
        for _, cpu in ipairs(cpus) do
            if cpu.isBusy == false then
                freeCPUs = freeCPUs + 1
            end
        end
    end

    allRequests = {}
    builderRequests = {}
    remainingRequests = {}

    for _, builder in ipairs(builders) do
        if not builderRequests[builder.id] then
            builderRequests[builder.id] = {}
        end
        local builderResources = colony.getBuilderResources(builder.pos)
        for _, builderRequest in ipairs(builderResources) do
            if builderRequest.status == "DONT_HAVE" and builderRequest.needed - builderRequest.available > 0 then
                builderItem = builderRequest.item
                builderItem.count = builderItem.count * (builderRequest.needed - builderRequest.available)
            end
            if builderItem then
                local skipped = false
                for _, existingItem in ipairs(builderRequests[builder.id]) do
                    if existingItem.fingerprint == builderItem.fingerprint then
                        existingItem.needed = existingItem.needed + builderItem.count
                        skipped = true
                        break
                    end
                end
                if not skipped then
                    local item = {name=builderItem.displayName, fingerprint=builderItem.fingerprint, needed=builderItem.count}
                    table.insert(builderRequests[builder.id], item)
                end
            end
        end
    end

    local rawRequests = colony.getRequests()
    for _, request in ipairs(rawRequests) do
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
                local item = {name=itemRequest.displayName, fingerprint=itemRequest.fingerprint, needed=itemRequest.count}
                table.insert(allRequests, item)
            end
        end
    end
    local rawAllItems = bridge.listItems()
    -- log("DEBUG", "All requests: " .. textutils.serialize(allRequests))
    -- log("DEBUG", "All items: " .. textutils.serialize(rawAllItems))
    for _, item in ipairs(rawAllItems) do
        for _, requestedItem in ipairs(allRequests) do
            if item.fingerprint == requestedItem.fingerprint then
                local status = "a"
                if item.amount < requestedItem.needed then
                    if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                        status = "c"
                    else
                        status = "m"
                    end
                end
                requestedItem.status = status
                requestedItem.available = item.amount
                if item.amount < requestedItem.needed then
                    requestedItem.missing = requestedItem.needed - item.amount
                else
                    requestedItem.missing = 0
                end
            end
        end
        for _, builder in ipairs(builders) do
            for _, requestedItem in ipairs(builderRequests[builder.id]) do
                if item.fingerprint == requestedItem.fingerprint then
                    local status = "a"
                    if item.amount < requestedItem.needed then
                        if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                            status = "c"
                        else
                            status = "m"
                        end
                    end
                    requestedItem.status = status
                    requestedItem.available = item.amount
                    if item.amount < requestedItem.needed then
                        requestedItem.missing = requestedItem.needed - item.amount
                    else
                        requestedItem.missing = 0
                    end
                end
            end
        end
    end
    for _, item in ipairs(allRequests) do
        if item then
            if not item.status then
                item.status = "m"
                item.available = 0
                item.missing = item.needed
            end
        end
    end
    for _, builder in ipairs(builders) do
        for _, item in ipairs(builderRequests[builder.id]) do
            if item then
                if not item.status then
                    item.status = "m"
                    item.available = 0
                    item.missing = item.needed
                end
            end
        end
    end
    for _, builder in ipairs(builders) do
        for _, builderItem in ipairs(builderRequests[builder.id]) do
            local found = false
            for _, item in ipairs(allRequests) do
                if item.fingerprint == builderItem.fingerprint then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(allRequests, builderItem)
            end
        end
    end
    for _, item in ipairs(allRequests) do
        local remaining = true
        for _, builder in ipairs(builders) do
            for _, builderItem in ipairs(builderRequests[builder.id]) do
                if item.fingerprint == builderItem.fingerprint then
                    remaining = false
                    break
                end
            end
        end
        if remaining then
            table.insert(remainingRequests, item)
        end
    end
end

function moveItems()
    if mode == "ME" or mode == "RS" then
        local empty = true
        if peripheral.call(outputInventory, "list") ~= {} then
            empty = false
        end
        for _, item in ipairs(allRequests) do
            if item.status == "a" then
                if empty then
                    log("DEBUG", "Exporting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.needed)
                    bridge.exportItemToPeripheral({fingerprint=item.fingerprint, count=item.needed}, outputInventory)
                else
                    log("WARNING", "Ouput Inventory not empty")
                end
            elseif item.status == "m" then
                if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                    log("DEBUG", "Item is already crafting: " .. item.name .. " (" .. item.fingerprint .. ")")
                else
                    if mode == "RS" then
                        log("DEBUG", "Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                        bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                    elseif mode == "ME" then
                        if freeCPUs > 0 then
                            log("DEBUG", "Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                            bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                            if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                                freeCPUs = freeCPUs - 1
                            end
                        else
                            log("DEBUG", "No free Crafting CPUs available")
                        end
                    end
                end
            end
        end
    end
end

function sendWifi(msg)
    if wifi.isOpen(wifiSendChannel) then
        log("DEBUG", "Sending message on channel: " .. wifiSendChannel)
        log("DEBUG", "Message: " .. msg)
        wifi.transmit(wifiSendChannel, wifiReplyChannel, msg)
    else
        log("ERROR", "WIFI channel closed")
    end
end

function updateWifi()
end

function main ()
    -- Get inputs
    getInputs()
    -- Update display
    if displayMode then
        os.queueEvent("display_update")
    end
    -- Update every updateInterval seconds the logic
    if iteration == updateInterval then
        if widgets.autoButton.active then
            moveItems()
        end
        if wifi then
            updateWifi()
        end
        iteration = 0
    end
    Heartbeat = not Heartbeat
    iteration = iteration + 1
    timerID = os.startTimer(1)
end

function handleEvents ()
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEventRaw()
        if event == "terminate" then
            running = false
            return
        elseif event == "monitor_touch" then
            if displayMode then
                local hit = false
                for _, widget in pairs(widgets) do
                    if widget:clicked(p2, p3) then
                        hit = true
                        break
                    end
                end
                if not hit then
                    callbackRefresh()
                end
            end
        elseif event == "display_update" then
            if displayMode then
                updateDisplay(monitor)
            end
        elseif event == "timer" then
            main()
        end
    end
end

-- Clear log file
if logMode == "overwrite" then
    local file = fs.open(logFile, "w")
    file.close()
end
-- Start up
log("INFO", "Starting up")
timerID = 0
iteration = 0
startupSuccess = true
os.setComputerLabel("Colony Resource Requester")
getPeripherals() -- Get all peripherals
builders, builderCount = getBuilders()
if displayMode then
    setUpDisplay(monitor)
end
if not startupSuccess then
    log("ERROR", "Startup failed")
else
    running = true
    log("INFO", "Startup successful")
end

timerID = os.startTimer(1)
handleEvents()

if wifi then
    wifi.closeAll()
end
if displayMode then
    resetDisplay(monitor)
end
log("INFO", "Stopped")
