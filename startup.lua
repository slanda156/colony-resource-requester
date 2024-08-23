-- Runtime configuration
updateInterval = 30 -- in seconds
forceHeadless = false -- Force headless mode
-- WIFI is WIP and not working
wifiEnable = false -- Enable wifi
wifiSendChannel = 1 -- The channel to use for the wifi messages
wifiReplyChannel = 600 -- The channel to use for the wifi replies

-- Do not change anything below
logging = require("src/logging")
Button = require("src/widgets").Button
Group = require("src/widgets").Group

function getPeripherals ()
    if not forceHeadless then
        monitor = peripheral.find("monitor")
        displayMode = true
        if not monitor then
            logging.log("WARNING", "Couldn't connect to monitor")
            logging.log("INFO", "Running in headless mode")
            displayMode = false
        else
            monitor.setBackgroundColor(colors.black)
            monitor.setTextColor(colors.white)
            monitor.clear()

            monitor.setTextScale(0.5)
            local width, height = monitor.getSize()
            logging.log("DEBUG", "Monitor size: " .. width .. "x" .. height)
            if width < 57 or height < 24 then
                monitor.setCursorPos(1, 1)
                monitor.write("Monitor too small")
                monitor.setCursorPos(1, 2)
                monitor.write("At least 3x2 required")
                logging.log("WARNING", "Monitor too small, at least 3x2 required")
                logging.log("DEBUG", "Monitor size: " .. width .. "x" .. height)
                logging.log("INFO", "Running in headless mode")
                displayMode = false
            else
                if not monitor.isColor() then
                    displayMode = false
                    logging.log("WARNING", "Monitor must be an Advanced Monitorn, running in headless mode")
                end
            end
        end
    else
        displayMode = false
        logging.log("INFO", "Running in headless mode (forced)")
    end
    local meBridge = peripheral.find("meBridge")
    if meBridge then
        bridge = meBridge
        mode = "ME"
        if not bridge.getEnergyUsage() then
            logging.log("ERROR", "ME Bridge not connected or ME system not working")
        else
            logging.log("INFO", "ME Bridge connected")
        end
    end
    if not mode then
        local rsBridge = peripheral.find("rsBridge")
        if rsBridge then
            bridge = rsBridge
            mode = "RS"
            if not bridge.getEnergyUsage() then
                logging.log("ERROR", "RS Bridge not connected or RS system not working")
            else
                logging.log("INFO", "RS Bridge connected")
            end
        end
    end
    if not mode then
        logging.log("WARNING", "No ME/RS bridge found")
        if not displayMode then
            logging.log("ERROR", "Running in headless mode, stopping")
            startupSuccess = false
            return
        end
        logging.log("INFO", "Running in display only mode")
        mode = "DP"
    end
    colony = peripheral.find("colonyIntegrator")
    if not colony then
        startupSuccess = false
        logging.log("ERROR", "Colony Integrator not found")
    else
        if not colony.isInColony() then
            startupSuccess = false
            logging.log("ERROR", "Colony Integrator not inside a colony")
        else
            logging.log("INFO", "Colony Integrator connected")
        end
    end
    if wifiEnable then
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
            logging.log("WARNING", "Wirless modem not found")
        else
            wifi.open(wifiSendChannel)
            logging.log("INFO", "WIFI enabled")
        end
    else
        logging.log("INFO", "WIFI disabled")
    end

    if mode ~= "DP" then
        local peripherals = peripheral.getNames()
        local found = false
        for _, p in ipairs(peripherals) do
            for _, method in ipairs(peripheral.getMethods(p)) do
                if method == "pushItems" then
                    found = true
                    outputInventory = p
                    logging.log("INFO", "Output inventory found")
                    logging.log("DEBUG", "Output inventory: " .. p)
                    break
                end
            end
        end
        if not found then
            mode = "NI"
            logging.log("ERROR", "No output inventory found")
        end
    end
    sleep(1)
end

function resetDisplay(mon)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.setTextScale(0.5)
    mon.clear()
end

function setUpDisplay(mon)
    resetDisplay(mon)
    if startupSuccess then
        builders, builderCount = getBuilders()
    end
    local width, height = mon.getSize()
    logging.log("DEBUG", "Monitor size: " .. width .. "x" .. height)
    widgets = {}
    widgets.autoButton = Button.new(width * (3 / 4), 1, 6, 1, "Auto", nil, mon)
    widgets.autoButton.active = true
    logging.log("DEBUG", "Added button: " .. widgets.autoButton.label)
    widgets.allGroup = Group.new(4, "All", mon)
    logging.log("DEBUG", "Added group: " .. widgets.allGroup.label)
    for i, builder in ipairs(builders) do
        local group = Group.new(4 + i, builder.name .. " (lvl" .. builder.lvl .. ")", mon)
        group.collapsed = true
        widgets[builder.name] = group
        logging.log("DEBUG", "Added group: " .. builder.name)
    end
end

function updateDisplay (mon)
    local width, height = mon.getSize()
    local maxLines = height - 3
    resetDisplay(mon)
    -- Title | Auto Button | Status
    mon.setBackgroundColor(colors.lightGray)
    mon.setTextColor(colors.black)
    mon.setCursorPos(1, 1)
    mon.write("Colony Resource Requester" .. string.rep(" ", width))
    mon.setCursorPos(width - 2, 1)
    mon.write(mode)
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
        widgets.allGroup:clear()
        if allRequests ~= nil and allRequests ~= {} then
            for _, item in ipairs(allRequests) do
                if item then
                    widgets.allGroup:addItem({item.name, item.needed, item.available, item.missing, item.status})
                end
            end
        end
        local i = 0
        local nextLine = widgets.allGroup.line + widgets.allGroup.lines
        local index = ""
        repeat
            index = "Builder " .. i
            for key, widget in pairs(widgets) do
                if widget.type == "group" then
                    if key == index then
                        widget:clear()
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
    end
    mon.setTextColor(colors.white)
    mon.setCursorPos(width - 13, height)
    mon.write("v" .. VERSION)
    mon.setCursorPos(width - 5, height)
    mon.write(updateInterval - iteration .. "s")
    mon.setCursorPos(width - 1, height)
    if Heartbeat then
        mon.setBackgroundColor(colors.black)
    else
        mon.setBackgroundColor(colors.red)
    end
    mon.write("  ")
end

function callbackRefresh ()
    logging.log("DEBUG", "Refresh callback")
    getInputs()
    local success = true
    if widgets.autoButton.active then
        success = moveItems()
    end
    if displayMode then
        os.queueEvent("display_update")
    end
    iteration = 0
    os.cancelTimer(timerID)
    if success == nil or success then
        timerID = os.startTimer(1)
    else
        getPeripherals()
        if success == nil or success then
            timerID = os.startTimer(1)
        else
            mode = "NI"
        end
    end
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

function getInputs(skip)
    -- allRequests -> Holds all items that are requested
    -- builderRequests -> Holds a table for each builder with all items that are requested
    -- item = {name, fingerprint, needed, available, missing, status}

    if mode == "ME" and not skip then
        local cpus = bridge.getCraftingCPUs()
        if not cpus then
            logging.log("ERROR", "No Crafting CPUs found, ME system not working?")
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
            for _, existingItem in ipairs(builderRequests[builder.id].items) do
                if existingItem.fingerprint == builderItem.fingerprint then
                    skipped = true
                    break
                end
            end
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
                local item = {name=itemRequest.displayName, fingerprint=itemRequest.fingerprint, needed=itemRequest.count * request.count}
                table.insert(allRequests, item)
            end
        end
    end
    if not skip and mode ~= "DP" then
        local rawAllItems = {}
        for _, request in ipairs(allRequests) do
            local fingerprint = request.fingerprint
            local item, err = bridge.getItem({fingerprint=fingerprint})
            if item then
                table.insert(rawAllItems, item)
            elseif err then
                logging.log("DEBUG", "Couldn't get item: " .. request.name .. " | Error: " .. err)
            else
                logging.log("ERROR", "Couldn't get item: " .. request.name .. " | Bridge error")
            end
        end
        if not rawAllItems then
            logging.log("ERROR", "No items found, ME/RS system not working?")
            return
        end
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
end

function moveItems()
    if mode == "ME" or mode == "RS" or mode = "NI" then
        local empty = true
        if peripheral.call(outputInventory, "list") == nil then
            logging.log("ERROR", "Output Inventory not found")
            return
        end
        if next(peripheral.call(outputInventory, "list")) ~= nil then
            empty = false
        end
        for _, item in ipairs(allRequests) do
            if item.status == "a" then
                if mode ~= "NI" then
                    if empty then
                        logging.log("DEBUG", "Exporting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.needed)
                        bridge.exportItemToPeripheral({fingerprint=item.fingerprint, count=item.needed}, outputInventory)
                    else
                        logging.log("WARNING", "Ouput Inventory not empty")
                    end
                else
                    logging.log("DEBUG", "Item is available: " .. item.name .. " (" .. item.fingerprint .. "), skipping")
                end
            elseif item.status == "m" then
                if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                    logging.log("DEBUG", "Item is already crafting: " .. item.name .. " (" .. item.fingerprint .. ")")
                else
                    if mode == "RS" then
                        local itemName = bridge.getItem({fingerprint=item.fingerprint}).name
                        if bridge.isItemCraftable({name=itemName}) then
                            logging.log("DEBUG", "Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                            bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                            sleep(0.1)
                            if not bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                                logging.log("DEBUG", "Couldn't craft item")
                            end
                        else
                            logging.log("DEBUG", "Item not craftable: " .. item.name .. " | " .. itemName .. " (" .. item.fingerprint .. ")")
                        end
                    elseif mode == "ME" then
                        if freeCPUs > 0 then
                            local itemName = bridge.getItem({fingerprint=item.fingerprint}).name
                            if bridge.isItemCraftable({name=itemName}) then
                                logging.log("DEBUG", "Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                                bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                                sleep(0.1)
                                if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                                    freeCPUs = freeCPUs - 1
                                else
                                    logging.log("DEBUG", "Couldn't craft item")
                                end
                            else
                                if itemName == nil then
                                    logging.log("DEBUG", "Item has no recipe: " .. item.name .. " (" .. item.fingerprint .. ")")
                                else
                                    logging.log("DEBUG", "Item not craftable: " .. item.name .. " | "  .. itemName .. " (" .. item.fingerprint .. ")")
                                end
                            end
                        else
                            logging.log("DEBUG", "No free Crafting CPUs available")
                        end
                    end
                end
            end
        end
    end
end

function sendWifi(msg)
    if wifi.isOpen(wifiSendChannel) then
        logging.log("DEBUG", "Sending message on channel: " .. wifiSendChannel)
        logging.log("DEBUG", "Message: " .. msg)
        wifi.transmit(wifiSendChannel, wifiReplyChannel, msg)
    else
        logging.log("ERROR", "WIFI channel closed")
    end
end

function updateWifi()
end

function update ()
    -- Get inputs
    builders, builderCount = getBuilders()
    if mode ~= "DP" and bridge ~= nil and bridge.getEnergyUsage() then
        getInputs(false)
    elseif mode ~= "DP" then
        logging.log("ERROR", "ME/RS system not working")
        logging.log("INFO", "Retrying in 10 seconds")
        timerID = os.startTimer(10)
        return
    elseif mode == "DP" then
        getInputs(true) -- skip the bridge part
    end
    -- Update display
    if displayMode then
        os.queueEvent("display_update")
    end
    -- Update every updateInterval seconds the logic
    if iteration == updateInterval then
        local success = true
        if widgets.autoButton.active then
            success = moveItems()
        end
        if wifi then
            updateWifi()
        end
        iteration = 0
    end
    Heartbeat = not Heartbeat
    iteration = iteration + 1
    if success == nil or success then
        timerID = os.startTimer(1)
    else
        mode = "NI"
    end
end

function handleEvents ()
    while running do
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
            update()
        end
    end
end

-- Clear log file
if logMode == "overwrite" then
    local file = fs.open(logFile, "w")
    file.close()
end
-- Start up
VERSION = "0.2.1-dev"
logging.log("INFO", "Starting up, v" .. VERSION)
running = true
timerID = 0
iteration = 0
currentTab = 0
builders = {}
builderCount = 0
startupSuccess = true
os.setComputerLabel("Colony Resource Requester")
getPeripherals() -- Get all peripherals
if displayMode then
    setUpDisplay(monitor)
end
if not startupSuccess then
    logging.log("ERROR", "Startup failed")
    running = false
else
    logging.log("INFO", "Startup successful")
    timerID = os.startTimer(1)
    handleEvents()
end


if wifi then
    wifi.closeAll()
end
if displayMode then
    resetDisplay(monitor)
end
logging.log("INFO", "Stopped")
