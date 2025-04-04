logging = require("src/logging")

function validateConfig (config)
    if config == nil then -- Invalid config
        logging:DEBUG("Config is nil")
        return -1
    end
    if config.version == nil then -- Invalid version
        logging:DEBUG("Config version is nil")
        return -1
    end
    if config.version ~= VERSION then -- Outdated version
        logging:DEBUG("Config version is outdated")
        return 0
    end
    local modelConfig = createConfig()
    for key, value in pairs(modelConfig) do
        if config[key] == nil then
            logging:DEBUG("Config key missing: " .. key)
            return -1
        end
        if type(value) == "table" then
            if not compareTable(value, config[key]) then
                logging:DEBUG("Config key invalid: " .. key)
                return -1
            end
        end
    end
    return 1
end

function validateBuilderRequest(request)
    if request == nil then
        logging:ERROR("builderRequest is nil")
        return false
    end
    if request.item == nil then
        logging:ERROR("builderRequest.item is nil")
        return false
    end
    if request.needed == nil and type(request.needed) ~= "number" then
        logging:DEBUG("builderRequest.needed is nil or not a number")
        request.needed = 0
    end
    if request.available == nil and type(request.available) ~= "boolean" then
        logging:DEBUG("builderRequest.available is nil or not a boolean")
        request.available = false
    end
    if request.delivering == nil and type(request.delivering) ~= "boolean" then
        logging:DEBUG("builderRequest.delivering is nil or not a boolean")
        request.delivering = false
    end
    return true
end

function validateBuilder(builder)
    if builder == nil then
        logging:ERROR("builder is nil")
        return false
    end
    if builder.id == nil then
        logging:ERROR("builder.id is nil")
        return false
    end
    if builder.pos == nil then
        logging:ERROR("builder.pos is nil")
        return false
    end
    return true
end

function validateBridgeItem(item)
    if item == nil then
        logging:ERROR("bridgeItem is nil")
        return false
    end
    if item.name == nil then
        logging:ERROR("bridgeItem.name is nil")
        return false
    end
    if item.fingerprint == nil then
        logging:ERROR("bridgeItem.fingerprint is nil")
        return false
    end
    if item.amount == nil then
        logging:DEBUG("bridgeItem.amount is nil")
        item.amount = 0
    end
    if item.displayName == nil then
        logging:DEBUG("bridgeItem.displayName is nil")
        item.displayName = item.name
    end
    if item.isCraftable == nil then
        logging:DEBUG("bridgeItem.isCraftable is nil")
        item.isCraftable = false
    end
    if item.nbt == nil then
        logging:DEBUG("bridgeItem.nbt is nil")
        item.nbt = ""
    end
    if item.tags == nil then
        logging:DEBUG("bridgeItem.tags is nil")
        item.tags = {}
    end
    return true
end

function validateRequestItem(item)
    if item == nil then
        logging:ERROR("requestItem is nil")
        return false
    end
    if item.item == nil then
        logging:ERROR("requestItem.item is nil")
        return false
    end
    if item.displayName == nil then
        logging:DEBUG("requestItem.displayName is nil")
        item.displayName = item.item
    end
    if item.status == nil then
        logging:ERROR("requestItem.status is nil")
        return false
    end
    if item.needed == nil and type(item.needed) ~= "number" then
        logging:DEBUG("requestItem.needed is nil or not a number")
        item.needed = 0
    end
    if item.available == nil and type(item.available) ~= "boolean" then
        logging:DEBUG("requestItem.available is nil or not a boolean")
        item.available = false
    end
    if item.delivering == nil and type(item.delivering) ~= "boolean" then
        logging:DEBUG("requestItem.delivering is nil or not a boolean")
        item.delivering = false
    end
    return true
end