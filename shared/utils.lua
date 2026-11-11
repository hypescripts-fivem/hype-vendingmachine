local Config <const> = require "config.config"

local prefixes <const> = {
    success = "^2[SUCCESS]^0",
    error = "^1[ERROR]^0",
    warning = "^3[WARNING]^0",
    info = "^4[INFO]^0",
}

local context <const> = IsDuplicityVersion() and "SERVER" or "CLIENT"

function Debug(status, message, ...)
    if not Config.Debug then return end

    local body = tostring(message or "")
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, body, ...)
        if ok then body = formatted end
    end

    print(("[DEBUG:%s] %s %s"):format(context, prefixes[status] or status, body))
end
