Logging = require("src/logging")

function compInt(number)
    if type(number) == "string" then
        number = tonumber(number)
    elseif type(number) ~= "number" then
        Logging:ERROR("Invalid number")
        Logging:DEBUG("Number: " .. textutils.serialize(number))
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

function checkEmptyTable(t)
    if t == nil then
        return false
    end
    if type(t) ~= "table" then
        Logging:ERROR("Invalid table")
        return false
    end
    return next(t) == nil
end

function InsertAt (str, char, i)
    return str:sub(1, i) .. char .. str:sub(i + 1)
end

function GetIndexes (str, pattern)
    local indexes = {}
    local i = 0
    while true do
        local _i = string.find(str, pattern, i + 1)
        if _i == nil then
            break
        else
            i = _i
            table.insert(indexes, i)
        end
    end
    return indexes
end

function PrettyJSON (json)
    local j = json
    local locations = {}
    locations = GetIndexes(j, "{")
    for i = 1, #locations do
        j = InsertAt(j, "\n", locations[i] + i - 1)
    end
    locations = GetIndexes(j, "}")
    for i = 1, #locations do
        j = InsertAt(j, "\n", locations[i] + i - 2)
    end
    locations = GetIndexes(j, ",")
    for i = 1, #locations do
        j = InsertAt(j, "\n", locations[i] + i - 1)
    end
    return j
end

function MergeTable (t, newT)
    local merged = {}
    for key, value in pairs(t) do
        if newT[key] ~= nil then
            if type(value) == "table" then
                merged[key] = MergeTable(value, newT[key])
            else
                merged[key] = newT[key]
            end
        end
    end
    return merged
end

function AreTablesEqualTypes (t1, t2)
    for key, value in pairs(t1) do
        if t2[key] == nil then
            return false
        elseif type(value) ~= type(t2[key]) then
            return false
        end
        if type(value) == "table" then
            return AreTablesEqualTypes(value, t2[key])
        end
    end
    return true
end

return {
    compInt = compInt,
    checkEmptyTable = checkEmptyTable,
    InsertAt = InsertAt,
    GetIndexes = GetIndexes,
    PrettyJSON = PrettyJSON,
    MergeTable = MergeTable,
    AreTablesEqualTypes = AreTablesEqualTypes
}