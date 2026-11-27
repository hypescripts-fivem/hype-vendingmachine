local Config <const> = require "config.config"

-- Forks of qb-inventory come before it, so they are picked when both are running
local SUPPORTED <const> = {
    "ox_inventory",
    "codem-inventory",
    "core_inventory",
    "origen_inventory",
    "tgiann-inventory",
    "jpr-inventory",
    "ps-inventory",
    "qb-inventory",
}

--- Resolves the active inventory from Config.Inventory, auto detecting it when set to "auto".
---@return string? name The inventory resource, or nil when none is supported.
local function detect()
    for _, name in ipairs(SUPPORTED) do
        if Config.Inventory == name then return name end

        if Config.Inventory == "auto" then
            local state = GetResourceState(name)
            if state == "started" or state == "starting" then return name end
        end
    end
end

local name <const> = detect()

if not name then
    error(("[hype-vendingmachine] No supported inventory found (Config.Inventory = %s). Supported: %s"):format(Config.Inventory, table.concat(SUPPORTED, ", ")))
end

Modules.Server.Inventory.Name = name
Modules.Client.Inventory.Name = name

Debug("info", "Inventory detected: %s", name)
