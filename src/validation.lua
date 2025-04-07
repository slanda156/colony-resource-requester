Logging = require("src/logging")
Functions = require("src/function")

local validation = {}

function validation.config (config)
    if config == nil then -- Invalid config
        Logging:DEBUG("Config is nil")
        return -1
    end
    if config.version == nil then -- Invalid version
        Logging:DEBUG("Config version is nil")
        return -1
    end
    if config.version ~= VERSION then -- Outdated version
        Logging:DEBUG("Config version is outdated")
        return 0
    end
    local modelConfig = CreateConfig()
    for key, value in pairs(modelConfig) do
        if config[key] == nil then
            Logging:DEBUG("Config key missing: " .. key)
            return -1
        end
        if type(value) == "table" then
            if not AreTablesEqualTypes(value, config[key]) then
                Logging:DEBUG("Config key invalid: " .. key)
                return -1
            end
        end
    end
    return 1
end

function validation.builderRequest(request)
    if request == nil or checkEmptyTable(request) then
        Logging:ERROR("builderRequest is nil")
        return false
    end
    if request.item == nil then
        Logging:ERROR("builderRequest.item is nil")
        return false
    end
    if request.needed == nil then
        -- Check if item.needs if available (1.21.1+)
        if request.needs ~= nil then
            request.needed = request.needs
        else
            Logging:DEBUG("builderRequest.needed is nil")
            request.needed = 0
        end
    end
    if request.available == nil then
        Logging:DEBUG("builderRequest.available is nil")
        request.available = false
    end
    if request.delivering == nil then
        Logging:DEBUG("builderRequest.delivering is nil")
        request.delivering = false
    end
    return true
end

function validation.builder(builder)
    if builder == nil or checkEmptyTable(builder) then
        Logging:ERROR("builder is nil")
        return false
    end
    if builder.id == nil then
        Logging:ERROR("builder.id is nil")
        return false
    end
    if builder.pos == nil then
        Logging:ERROR("builder.pos is nil")
        return false
    end
    return true
end

function validation.bridgeItem(item)
    if item == nil or checkEmptyTable(item) then
        return false
    end
    if item.name == nil then
        Logging:ERROR("bridgeItem.name is nil")
        return false
    end
    if item.fingerprint == nil then
        Logging:ERROR("bridgeItem.fingerprint is nil")
        return false
    end
    if item.amount == nil then
        -- Check if item.count if available (1.21.1+)
        if item.count ~= nil then
            item.amount = item.count
        else
            Logging:DEBUG("bridgeItem.amount is nil")
            item.amount = 0
        end
    end
    if item.displayName == nil then
        Logging:DEBUG("bridgeItem.displayName is nil")
        item.displayName = item.name
    end
    if item.isCraftable == nil then
        Logging:DEBUG("bridgeItem.isCraftable is nil")
        item.isCraftable = false
    end
    if item.nbt == nil then
        -- Check if item.components if available (1.21.1+)
        if item.components ~= nil then
            item.nbt = item.components
        else
            Logging:DEBUG("bridgeItem.nbt is nil")
            item.nbt = ""
        end
    end
    if item.tags == nil then
        Logging:DEBUG("bridgeItem.tags is nil")
        item.tags = {}
    end
    return true
end

function validation.requestItem(item)
    if item == nil or checkEmptyTable(item) then
        Logging:ERROR("requestItem is nil")
        return false
    end
    if item.name == nil then
        Logging:ERROR("requestItem.name is nil")
        return false
    end
    if item.displayName == nil then
        Logging:DEBUG("requestItem.displayName is nil")
        item.displayName = item.name
    end
    if item.amount == nil then
        -- Check if item.count if available (1.21.1+)
        if item.count ~= nil then
            item.amount = item.count
        else
            Logging:DEBUG("requestItem.amount is nil")
            item.amount = 0
        end
    end
    if item.tags == nil then
        Logging:DEBUG("requestItem.tags is nil")
        item.tags = {}
    end
    return true
end

return validation