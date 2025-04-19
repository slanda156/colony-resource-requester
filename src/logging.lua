require("src/types")

local allLevels = {DEBUG=true, INFO=true, WARNING=true, ERROR=true}
local levelColors = {DEBUG=colors.cyan, INFO=colors.white, WARNING=colors.yellow, ERROR=colors.red}

-- https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end


local Logger = {}
Logger.__index = Logger

function Logger.new()
    local self = setmetatable({}, Logger)
    self.logFile = "crr.log"
    ---@type LogMode
    self.logMode = "a"
    ---@type LogLevel
    self.logLevel = "DEBUG"
    ---@type LogTimeSource
    self.logTimeSource = "local"
    ---@type LogTimeFormat
    self.logTimeFormat = true
    self.allowedLevels = copy(allLevels)
    self.firstMsg = true
---@diagnostic disable-next-line: param-type-mismatch
    self._formatedTime = textutils.formatTime(os.time(self.logTimeSource), self.logTimeFormat)
---@diagnostic disable-next-line: param-type-mismatch
    self._lastFormatedTime = os.time(self.logTimeSource)
    self._file = fs.open(self.logFile, self.logMode)
    self._termWidth, self._termHeight = term.getSize()
    return self
end

function Logger:destroy()
    if self._file ~= nil then
        self._file.close()
    end
end

function Logger:log(level, msg)
    if self.firstMsg then
        if self.logMode == "a" then
            self._file.write("\n")
        end
        self.firstMsg = false
    end
    if self.allowedLevels[level] ~= nil then
        -- Check if the time has changed
        if os.time(self.logTimeSource) - self._lastFormatedTime > 1 then
            self._formatedTime = textutils.formatTime(os.time(self.logTimeSource), self.logTimeFormat)
            self._lastFormatedTime = os.time(self.logTimeSource)
        end
        -- Construct the message
        local finalMsg = table.concat({self._formatedTime, " - ", level, " - ", tostring(msg)})
        local termMsg = ""
        -- Check if the message is too long
        if #finalMsg > self._termWidth then
            termMsg = string.sub(finalMsg, 1, self._termWidth - 3) .. "..."
        else
            termMsg = finalMsg
        end
        -- Log to terminal
        term.setTextColor(levelColors[level])
        term.setBackgroundColor(colors.black)
        print(termMsg) --ToDo: Possibly create own print function to handle scrolling in the terminal
        -- Log to file
        if self._file == nil then
            self._file = fs.open(self.logFile, self.logMode)
        end
        self._file.write(finalMsg .. "\n")
    end
end

function Logger:DEBUG(msg)
    self:log("DEBUG", msg)
end

function Logger:INFO(msg)
    self:log("INFO", msg)
end

function Logger:WARNING(msg)
    self:log("WARNING", msg)
end

function Logger:ERROR(msg)
    self:log("ERROR", msg)
end

function Logger:setLogConfig(t)
    if type(t) ~= "table" then
        self:ERROR("Invalid log config, " .. type(t))
        return
    end
    self:setLogFile(t.logFile)
    self:setLogMode(t.logMode)
    self:setLogLevel(t.logLevel)
    self:setLogTimeSource(t.logTimeSource)
    self:setLogTimeFormat(t.logTimeFormat)
end

---@param level LogLevel
function Logger:setLogLevel(level)
    if type(level) ~= "string" then
        self:ERROR("Invalid log level type, " .. type(level))
        return
    end
    if allLevels[level] == nil then
        self:ERROR("Invalid log level, " .. level)
        return
    end
    self.logLevel = level
    self.allowedLevels = copy(allLevels)
    if self.logLevel == "INFO" then
        self.allowedLevels["DEBUG"] = nil
    elseif self.logLevel == "WARNING" then
        self.allowedLevels["DEBUG"] = nil
        self.allowedLevels["INFO"] = nil
    elseif self.logLevel == "ERROR" then
        self.allowedLevels["DEBUG"] = nil
        self.allowedLevels["INFO"] = nil
        self.allowedLevels["WARNING"] = nil
    end
end

function Logger:setLogTimeSource(source)
    if type(source) ~= "string" then
        self:ERROR("Invalid log time source, " .. type(source))
        return
    end
    self.logTimeSource = source
end

function Logger:setLogTimeFormat(format)
    if type(format) ~= "boolean" then
        self:ERROR("Invalid log time format, " .. type(format))
        return
    end
    self.logTimeFormat = format
end

function Logger:setLogFile(file)
    if type(file) ~= "string" then
        self:ERROR("Invalid log file, " .. type(file))
        return
    end
    if self.logFile ~= nil then
        self._file.close()
        self._file = fs.open(file, self.logMode)
    end
    self.logFile = file
end

function Logger:setLogMode(mode)
    if type(mode) ~= "string" then
        self:ERROR("Invalid log mode, " .. type(mode))
        return
    end
    self.logMode = mode
end

local logger = Logger.new()

return logger