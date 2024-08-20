file = open("logging.json", "r")
local rawData = file.readAll()
file.close()
local config = textutils.unserializeJSON(rawData)
logFile = config.logFile
logMode = config.logMode
logLevel = config.logLevel
logTimeSource = config.logTimeSource
logTimeFormat = config.logTimeFormat

local logging = {}

function logging.log (level, msg)
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

return logging