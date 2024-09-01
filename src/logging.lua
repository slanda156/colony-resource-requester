local allLevels = {DEBUG=0, INFO=1, WARNING=2, ERROR=3}

local Logger = {}
Logger.__index = Logger

function Logger.new()
    local self = setmetatable({}, Logger)
    self.logFile = "log.log"
    self.logMode = "a"
    self.logLevel = "DEBUG"
    self.logTimeSource = "local"
    self.logTimeFormat = true
    self.allowedLevels = {DEBUG=0, INFO=1, WARNING=2, ERROR=3}
    return self
end

function Logger:setLogConfig(t)
    if type(t) ~= "table" then
        print("Invalid log config, " .. type(t))
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
        print("Invalid log level")
        return
    end
    if allLevels[level] == nil then
        print("Invalid log level")
        return
    end
    self.logLevel = level
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
        print("Invalid log time source, " .. type(source))
        return
    end
    logTimeSource = source
end

function Logger:setLogTimeFormat(format)
    if type(format) ~= "boolean" then
        print("Invalid log time format, " .. type(format))
        return
    end
    logTimeFormat = format
end

function Logger:setLogFile(file)
    if type(file) ~= "string" then
        print("Invalid log file, " .. type(file))
        return
    end
    logFile = file
end

function Logger:setLogMode(mode)
    if type(mode) ~= "string" then
        print("Invalid log mode, " .. type(mode))
        return
    end
    logMode = mode
end

function Logger:log(level, msg)
    if type(level) ~= "string" then
        print("Invalid log level, " .. tostring(level))
        return
    end
    if type(msg) ~= "string" then
        print("Invalid log message, " .. type(msg))
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