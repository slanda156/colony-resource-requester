-- Runtime configuration
updateInterval = 30 -- in seconds
forceHeadless = false -- Force headless mode
-- WIFI is WIP and not working
wifiEnable = true -- Enable wifi
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
            local width, height = monitor.getSize()
            if width < 14 or height < 10 then
                logging.log("WARNING", "Monitor too small, at least 3x3 required")
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
    if not meBridge then
        logging.log("WARNING", "ME Bridge not found")
    else
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
        if not rsBridge then
            logging.log("WARNING", "RS Bridge not found")
        else
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
        logging.log("ERROR", "No storage bridge found")
        if displayMode == 0 then
            logging.log("INFO", "Running in headless mode, stopping")
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
        wifi = peripheral.find("modem")
        if not wifi then
            logging.log("WARNING", "Modem not found")
        elseif not wifi.isWireless() then
            logging.log("WARNING", "Modem not wireless")
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
    local width, height = mon.getSize()
    logging.log("DEBUG", "Monitor size: " .. width .. "x" .. height)
    widgets = {}
    widgets.autoButton = Button.new(width / 2 + 4, 1, 1, 5, "Auto", nil, mon)
    widgets.autoButton.active = true
    logging.log("DEBUG", "Added button: " .. widgets.autoButton.label)
    widgets.exitButton = Button.new(width / 2 + 17, 1, 1, 5, "Exit", function() running = false end, mon)
    logging.log("DEBUG", "Added button: " .. widgets.exitButton.label)
    widgets.allGroup = Group.new(3, "All", mon)
    logging.log("DEBUG", "Added group: " .. widgets.allGroup.label)
    for i, builder in ipairs(builders) do
        local group = Group.new(3 + i, builder.name .. " (lvl" .. builder.lvl .. ")", mon)
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
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1, 1)
    mon.write("Colony Resource Requester" .. string.rep(" ", width))
    mon.setCursorPos(width - 2, 1)
    mon.write(mode)
    -- Requests | Work Orders | Citizens | Visitors | Buildings | Research | Stats
    if currentTab == 0 then
        -- Item Name | Requested | Available | Missing | Status
        widgets.allGroup:clear()
        for _, item in ipairs(allRequests) do
            if item then
                widgets.allGroup:addItem({item.name, item.needed, item.available, item.missing, item.status})
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

function getBuilders()
    local buildings = colony.getBuildings()
    local builders = {}
    local i = 0
    local orders = {}
    for _, order in ipairs(colony.getWorkOrders()) do
        orders[order.builder] = order
    end
    for _, building in ipairs(buildings) do
        if building.type == "builder" then
            table.insert(builders, {name="Builder " .. i, lvl=building.level, pos=building.location, order=orders[building.location], id=i})
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
    remainingRequests = {}

    for _, builder in ipairs(builders) do
        if not builderRequests[builder.id] then
            builderRequests[builder.id] = {items={}}
        end
        -- Get current build order of each builder
        for _, order in builder.order do
            builderRequests[builder.id].order = order
        end
        local builderResources = colony.getBuilderResources(builder.pos)
        for _, builderRequest in ipairs(builderResources) do
            if builderRequest.status == "DONT_HAVE" and builderRequest.needed - builderRequest.available > 0 then
                builderItem = builderRequest.item
                builderItem.count = builderItem.count * (builderRequest.needed - builderRequest.available)
            end
            if builderItem then
                local skipped = false
                for _, existingItem in ipairs(builderRequests[builder.id].items) do
                    if existingItem.fingerprint == builderItem.fingerprint then
                        existingItem.needed = existingItem.needed + builderItem.count
                        skipped = true
                        break
                    end
                end
                if not skipped then
                    local item = {name=builderItem.displayName, fingerprint=builderItem.fingerprint, needed=builderItem.count}
                    table.insert(builderRequests[builder.id].items, item)
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
                local item = {name=itemRequest.displayName, fingerprint=itemRequest.fingerprint, needed=itemRequest.count * request.count}
                table.insert(allRequests, item)
            end
        end
    end
    local rawAllItems = bridge.listItems()
    -- logging.log("DEBUG", "All requests: " .. textutils.serialize(allRequests))
    -- logging.log("DEBUG", "All items: " .. textutils.serialize(rawAllItems))
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
        for _, builder in ipairs(builders) do
            for _, requestedItem in ipairs(builderRequests[builder.id].items) do
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
        for _, item in ipairs(builderRequests[builder.id].items) do
            if item then
                if not item.status then
                    item.status = "m"
                    item.available = 0
                    item.missing = item.needed
                end
            end
        end
    end
    -- Removed do to too many items
    -- for _, builder in ipairs(builders) do
    --     for _, builderItem in ipairs(builderRequests[builder.id]) do
    --         local found = false
    --         for _, item in ipairs(allRequests) do
    --             if item.fingerprint == builderItem.fingerprint then
    --                 found = true
    --                 break
    --             end
    --         end
    --         if not found then
    --             table.insert(allRequests, builderItem)
    --         end
    --     end
    -- end
    for _, item in ipairs(allRequests) do
        local remaining = true
        for _, builder in ipairs(builders) do
            for _, builderItem in ipairs(builderRequests[builder.id].items) do
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
        if next(peripheral.call(outputInventory, "list")) ~= nil then
            empty = false
        end
        for _, item in ipairs(allRequests) do
            if item.status == "a" then
                if empty then
                    logging.log("DEBUG", "Exporting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.needed)
                    bridge.exportItemToPeripheral({fingerprint=item.fingerprint, count=item.needed}, outputInventory)
                else
                    logging.log("WARNING", "Ouput Inventory not empty")
                end
            elseif item.status == "m" then
                if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                    logging.log("DEBUG", "Item is already crafting: " .. item.name .. " (" .. item.fingerprint .. ")")
                else
                    if mode == "RS" then
                        logging.log("DEBUG", "Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                        bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                        sleep(0.1)
                        if not bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                            logging.log("WARNING", "Couldn't craft item")
                        end
                    elseif mode == "ME" then
                        if freeCPUs > 0 then
                            logging.log("DEBUG", "Crafting item: " .. item.name .. " (" .. item.fingerprint .. ")" .. " Amount: " .. item.missing)
                            bridge.craftItem({fingerprint=item.fingerprint, count=item.missing})
                            sleep(0.1)
                            if bridge.isItemCrafting({fingerprint=item.fingerprint}) then
                                freeCPUs = freeCPUs - 1
                            else
                                logging.log("WARNING", "Couldn't craft item")
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
    if bridge.getEnergyUsage() then
        getInputs()
    else
        logging.log("ERROR", "ME/RS system not working")
        logging.log("INFO", "Retrying in 10 seconds")
        timerID = os.startTimer(10)
        return
    end
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
VERSION = "0.2.0"
logging.log("INFO", "Starting up, " .. VERSION)
timerID = 0
iteration = 0
currentTab = 0
startupSuccess = true
os.setComputerLabel("Colony Resource Requester")
getPeripherals() -- Get all peripherals
builders, builderCount = getBuilders()
if displayMode then
    setUpDisplay(monitor)
end
if not startupSuccess then
    logging.log("ERROR", "Startup failed")
else
    running = true
    logging.log("INFO", "Startup successful")
end

timerID = os.startTimer(1)
handleEvents()

if wifi then
    wifi.closeAll()
end
if displayMode then
    resetDisplay(monitor)
end
logging.log("INFO", "Stopped")
