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
