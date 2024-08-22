logging = require("src/logging")

local strFuncs = {}

function strFuncs.compInt(number)
    if type(number) == "string" then
        number = tonumber(number)
    elseif type(number) ~= "number" then
        logging.log("ERROR", "Invalid number")
        logging.log("DEBUG", "Number: " .. textutils.serialize(number))
        return
    end
    output = ""
    if number < 0 then
        output = output .. "-"
        number = number * -1
    end
    if number < 1000 then
        output = output .. number
    elseif number < 1000000 then
        output = output .. math.floor(number / 100) / 10 .. "K"
    elseif number < 1000000000 then
        output = output .. math.floor(number / 100000) / 10 .. "M"
    elseif number < 1000000000000 then
        output = output .. math.floor(number / 100000000) / 10 .. "G"
    else -- Hopefully nothing will ever get this high
        output = output .. math.floor(number / 100000000000) / 10 .. "T"
    end
    return output
end

return {
    strFuncs = strFuncs
}