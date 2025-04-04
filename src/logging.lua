local allLevels = {DEBUG=0, INFO=1, WARNING=2, ERROR=3}

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
    self.logMode = "a"
    self.logLevel = "DEBUG"
    self.logTimeSource = "local"
    self.logTimeFormat = true
    self.allowedLevels = copy(allLevels)
    self.firstMsg = true
    return self
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
    if self.logLevel == "DEBUG" then
        self.allowedLevels = copy(allLevels)
    elseif self.logLevel == "INFO" then
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
    self.logFile = file
end

function Logger:setLogMode(mode)
    if type(mode) ~= "string" then
        self:ERROR("Invalid log mode, " .. type(mode))
        return
    end
    self.logMode = mode
end

function Logger:log(level, msg)
    if self.firstMsg then
        local file = fs.open(self.logFile, "a")
        file.write("\n")
        file.close()
        self.firstMsg = false
    end
    if type(level) ~= "string" then
        self:WARNING("Invalid log level, " .. tostring(level))
        return
    end
    if type(msg) ~= "string" then
        self:WARNING("Invalid log message, " .. type(msg))
        return
    end
    if self.allowedLevels[level] ~= nil then
        local finalMsg = textutils.formatTime(os.time(self.logTimeSource), self.logTimeFormat) .. " - " .. level .. " - " ..  msg
        print(finalMsg)
        local file = fs.open(self.logFile, "a")
        if type(file) == "string" then
            print("Couldn't open log file")
            print(file)
        else
            file.write(finalMsg .. "\n")
        end
        file.close()
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


local logger = Logger.new()

return logger