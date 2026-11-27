local Config <const> = require "config.config"

Framework = {
    Name = nil,
    Server = {},
    Client = {},
}

local resources <const> = {
    qbx = "qbx_core",
    qb = "qb-core",
    esx = "es_extended",
}

-- qbx_core first: it also provides the qb-core exports
local candidates <const> = { "qbx_core", "qb-core", "es_extended" }

--- Resolves the active framework from Config.Framework, auto detecting it when set to "auto".
---@return "qbx_core"|"qb-core"|"es_extended"|nil name
local function detect()
    if resources[Config.Framework] then return resources[Config.Framework] end

    for _, resource in ipairs(candidates) do
        local state = GetResourceState(resource)
        if state == "started" or state == "starting" then return resource end
    end
end

Framework.Name = detect()

if not Framework.Name then
    error(("[hype-vendingmachine] No supported framework found (Config.Framework = %s). Supported: qbx_core, qb-core, es_extended"):format(Config.Framework))
end

Debug("info", "Framework detected: %s", Framework.Name)
