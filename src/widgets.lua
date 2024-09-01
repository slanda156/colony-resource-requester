logging = require("src/logging")
strFuncs = require("src/function").strFuncs

local Group = {}
Group.__index = Group

function Group.new(line, label, mon)
    local self = setmetatable({}, Group)
    self.type = "group"
    self.line = line
    self.lineOffset = 0
    self.lines = 1
    self.label = label
    self.collapsed = false
    self.size = 0
    self.order = ""
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

function Group:setOrder(order)
    self.order = order
    -- .id: string 	The work order's id
    -- .priority: number 	The priority of the work order
    -- .workOrderType: string 	The type of work order
    -- .changed: boolean 	If the work order changed
    -- .isClaimed: boolean 	Whether the work order has been claimed
    -- .builder: table 	The position of the builder (has x, y, z)
    -- .buildingName: string 	The name of the building
    -- .type: string 	The type of the building
    -- .targetLevel: number 	The building's target level
end

function Group:addItem(item)
    local error = false
    if not item[1] then
        logging.log("ERROR", "Item name missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        error = true
    end
    if not item[2] then
        logging.log("ERROR", "Item needed missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        error = true
    end
    if not item[3] then
        logging.log("ERROR", "Item available missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        error = true
    end
    if not item[4] then
        logging.log("ERROR", "Item missing missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        error = true
    end
    if not item[5] then
        logging.log("ERROR", "Item status missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        error = true
    end
    if error then
        return
    end
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
    local line = self.line - self.lineOffset
    self.monitor.setBackgroundColor(colors.gray)
    self.monitor.setTextColor(colors.black)
    self.monitor.setCursorPos(1, line)
    local orderMsg = ""
    local orderMsgStart = ""
    local orderMsgEnd = ""
    if self.order ~= nil and self.order ~= {} and self.order ~= "" then
        if self.order.workOrderType == "BUILD" then
            orderMsgStart = orderMsgStart .. "[B]"
        elseif self.order.workOrderType == "UPGRADE" then
            orderMsgStart = orderMsgStart .. "[U]"
        elseif self.order.workOrderType == "REPAIR" then
            orderMsgStart = orderMsgStart .. "[R]"
        else
            orderMsgStart = orderMsgStart .. "[?]"
            logging.log("ERROR", "Unknown work order type: " .. self.order.workOrderType)
        end
        if self.order.workOrderType == "UPGRADE" then
            orderMsgEnd = orderMsgEnd .. " (lvl" .. self.order.targetLevel - 1 .. " -> lvl" .. self.order.targetLevel .. ")"
        else
            orderMsgEnd = orderMsgEnd .. " (lvl" .. self.order.targetLevel .. ")"
        end
        local maxBuildingNameLength = width - (5 + string.len(tostring(self.size)) + string.len(self.label) + string.len(orderMsgStart) + string.len(orderMsgEnd))
        local buildingName = self.order.buildingName
        if string.len(buildingName) > maxBuildingNameLength then
            buildingName = string.sub(buildingName, 1, maxBuildingNameLength - 3) .. "..."
        end
        orderMsg = orderMsgStart .. " " .. buildingName .. orderMsgEnd
    end
    if self.collapsed then
        collSign = "+"
    else
        collSign = "-"
    end
    if line < height -1 and line > 3 then
        if orderMsg == "" then
            self.monitor.write(collSign .. self.size .. " " .. self.label .. ":" .. string.rep(" ", width))
        else
            self.monitor.write(collSign .. self.size .. " " .. self.label .. ": " .. orderMsg .. string.rep(" ", width))
        end
    end
    if not self.collapsed then
        self.monitor.setBackgroundColor(colors.lightGray)
        for i, item in ipairs(self.items) do
            if item[1] then
                if line + i >= height - 1 or line + 1 < 3 then
                    break
                end
                self.monitor.setCursorPos(1, line + i)
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
                local spacing = 7
                local maxLabelLength = width - 4 - (spacing * 3)
                local label = item[1]
                label = string.gsub(label, "%[", "")
                label = string.gsub(label, "%]", "")
                if string.len(label) > maxLabelLength then
                    label = string.sub(label, 1, maxLabelLength - 3) .. "..."
                end
                local needed = strFuncs.compInt(item[2])
                local available = strFuncs.compInt(item[3])
                local missing = strFuncs.compInt(item[4])
                self.monitor.write(string.rep(" ", width))
                self.monitor.setCursorPos(4, line + i)
                self.monitor.write(label)
                self.monitor.setCursorPos(width - (spacing * 3 - 1), line + i)
                self.monitor.write("|" .. needed)
                self.monitor.setCursorPos(width - (spacing * 2 - 1), line + i)
                self.monitor.write("|" .. available)
                self.monitor.setCursorPos(width - (spacing * 1 - 1), line + i)
                self.monitor.write("|" .. missing)
            end
        end
    end
end

function Group:clicked(x, y)
    local line = self.line - self.lineOffset
    if y == line and line > 3 then
        self:toggle()
        os.queueEvent("display_update")
        return true
    end
    return false
end

local Button = {}
Button.__index = Button

function Button.new(x, y, width, height, label, callback, arg, switch, mon)
    local self = setmetatable({}, Button)
    self.type = "button"
    self.x = x
    self.y = y
    self.width = width
    if self.width < string.len(label) then
        self.width = string.len(label)
    end
    self.height = height
    if self.height < 1 then
        self.height = 1
    end
    self.label = label
    self.callback = callback
    self.callbackArg = arg
    self.active = false
    self.switch = switch
    self.monitor = mon
    self.backgroundActive = colors.green
    self.backgroundInactive = colors.red
    return self
end

function Button:render()
    self.monitor.setTextColor(colors.black)
    self.monitor.setCursorPos(self.x, self.y)
    if self.active then
        self.monitor.setBackgroundColor(self.backgroundActive)
    else
        self.monitor.setBackgroundColor(self.backgroundInactive)
    end
    local space = string.rep(" ", math.ceil((self.width - string.len(self.label)) / 2))
    local halfedSpace = math.floor(self.height / 2)
    if self.height > 1 then
        local i = 0
        repeat
            self.monitor.setCursorPos(self.x, self.y + i)
            self.monitor.write(string.rep(" ", self.width))
            i = i + 1
        until i >= halfedSpace
    end
    self.monitor.setCursorPos(self.x, self.y + halfedSpace)
    self.monitor.write(space .. self.label .. space)
    if self.height > 1 and math.mod(self.height, 2) == 1 then
        local i = 0
        repeat
            self.monitor.setCursorPos(self.x, self.y + halfedSpace + 1 + i)
            self.monitor.write(string.rep(" ", self.width))
            i = i + 1
        until i >= halfedSpace
    end
end

function Button:clicked(x, y)
    if x >= self.x - 1 and x < self.x + self.width and y >= self.y and y < self.y + self.height then -- self.x - 1, unsure why
        logging.log("DEBUG", "Button clicked: " .. self.label)
        if self.callback then
            self.callback(self.callbackArg)
        end
        if self.switch then
            self.active = not self.active
        end
        os.queueEvent("display_update")
        return true
    end
    return false
end

return {Group = Group, Button = Button}