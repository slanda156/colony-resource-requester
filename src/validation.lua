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
    if request.needed == nil then
        -- Check if item.needs if available (1.21.1+)
        if request.needs ~= nil then
            request.amount = request.needs
        else
            logging:DEBUG("builderRequest.needed is nil")
            request.needs = 0
        end
    end
    if request.available == nil then
        logging:DEBUG("builderRequest.available is nil")
        request.available = false
    end
    if request.delivering == nil then
        logging:DEBUG("builderRequest.delivering is nil")
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
        -- Check if item.count if available (1.21.1+)
        if item.count ~= nil then
            item.amount = item.count
        else
            logging:DEBUG("bridgeItem.amount is nil")
            item.amount = 0
        end
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
    if item.name == nil then
        logging:ERROR("requestItem.name is nil")
        return false
    end
    if item.displayName == nil then
        logging:DEBUG("requestItem.displayName is nil")
        item.displayName = item.name
    end
    if item.amount == nil then
        -- Check if item.count if available (1.21.1+)
        if item.count ~= nil then
            item.amount = item.count
        else
            logging:DEBUG("requestItem.amount is nil")
            item.amount = 0
        end
    end
    if item.tags == nil then
        logging:DEBUG("requestItem.tags is nil")
        item.tags = {}
    end
    return true
end