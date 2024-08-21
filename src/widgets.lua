logging = require("src/logging")
strFuncs = require("src/function").strFuncs

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
    if not item[1] then
        logging.log("ERROR", "Item name missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    if not item[2] then
        logging.log("ERROR", "Item needed missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    if not item[3] then
        logging.log("ERROR", "Item available missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    if not item[4] then
        logging.log("ERROR", "Item missing missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
        return
    end
    if not item[5] then
        logging.log("ERROR", "Item status missing")
        logging.log("DEBUG", "Item: " .. textutils.serialize(item))
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
    if self.line >= height -1 then
        return
    end
    self.monitor.setBackgroundColor(colors.gray)
    self.monitor.setTextColor(colors.black)
    self.monitor.setCursorPos(1, self.line)
    local orderMsg = ""
    if self.order ~= nil and self.order ~= {} and self.order ~= "" then
        if self.order.workOrderType == "BUIDLING" then
            oderMsg = oderMsg .. "[B]"
        elseif self.order.workOrderType == "UPGRADE" then
            oderMsg = oderMsg .. "[U]"
        elseif self.order.workOrderType == "REPAIR" then
            oderMsg = oderMsg .. "[R]"
        end
        orderMsg = orderMsg .. " " .. self.order.buildingName
        orderMsg = orderMsg .. " (lvl" .. self.order.targetLevel .. ")"
    end
    if self.collapsed then
        collSign = "+"
    else
        collSign = "-"
    end
    if orderMsg == "" then
        self.monitor.write(collSign .. self.size .. " " .. self.label .. ":" .. string.rep(" ", width))
    else
        self.monitor.write(collSign .. self.size .. " " .. self.label .. ":" .. "(" .. orderMsg .. ")" .. string.rep(" ", width))
    end
    if not self.collapsed then
        self.monitor.setBackgroundColor(colors.lightGray)
        for i, item in ipairs(self.items) do
            if item[1] then
                if self.line + i >= height - 1 then
                    break
                end
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
                local needed = strFuncs.compInt(item[2])
                local available = strFuncs.compInt(item[3])
                local missing = strFuncs.compInt(item[4])
                self.monitor.write("    " .. item[1])
                self.monitor.write(string.rep(" ", 25 - string.len(item[1])))
                self.monitor.write("|" .. needed)
                self.monitor.write(string.rep(" ", 6 - string.len(tostring(needed))))
                self.monitor.write("|" .. available)
                self.monitor.write(string.rep(" ", 6 - string.len(tostring(available))))
                self.monitor.write("|" .. missing)
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
        logging.log("DEBUG", "Button clicked: " .. self.label)
        if self.callback then
            self.callback()
        end
        self.active = not self.active
        os.queueEvent("display_update")
        return true
    end
    return false
end

return {Group = Group, Button = Button}