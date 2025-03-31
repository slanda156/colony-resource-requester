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
    if not request then
        logging:ERROR("builderRequest is nil")
        return false
    end
    if not request.item then
        logging:ERROR("builderRequest.item is nil")
        return false
    end
    if not request.needed and type(request.needed) ~= "number" then
        logging:ERROR("builderRequest.needed is nil or not a number")
        return false
    end
    if not request.available and type(request.available) ~= "number" then
        logging:ERROR("builderRequest.available is nil or not a number")
        return false
    end
    if not request.delivering and type(request.delivering) ~= "number" then
        logging:ERROR("builderRequest.delivering is nil or not a number")
        return false
    end
    return true
end

function validateBuilder(builder)
    if not builder then
        logging:ERROR("builder is nil")
        return false
    end
    if not builder.id then
        logging:ERROR("builder.id is nil")
        return false
    end
    if not builder.pos then
        logging:ERROR("builder.pos is nil")
        return false
    end
    return true
end
