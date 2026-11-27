local inventory <const> = Modules.Server.Inventory.Name

---@class InventoryAdapter
---@field canCarry fun(playerId: number, item: string, count: integer): boolean
---@field addItem fun(playerId: number, item: string, count: integer): boolean

--- qb-inventory and its forks share the same exports.
---@param resource string
---@return InventoryAdapter
local function qbStyle(resource)
    return {
        canCarry = function(playerId, item, count)
            return exports[resource]:CanAddItem(playerId, item, count)
        end,
        addItem = function(playerId, item, count)
            return exports[resource]:AddItem(playerId, item, count, false, nil, "hype-vendingmachine")
        end,
    }
end

---@type table<string, InventoryAdapter>
local ADAPTERS <const> = {
    ["ox_inventory"] = {
        canCarry = function(playerId, item, count)
            return exports.ox_inventory:CanCarryItem(playerId, item, count)
        end,
        addItem = function(playerId, item, count)
            return exports.ox_inventory:AddItem(playerId, item, count)
        end,
    },
    ["codem-inventory"] = {
        -- codem-inventory has no carry check, AddItem fails when the item doesn't fit
        canCarry = function() return true end,
        addItem = function(playerId, item, count)
            return exports["codem-inventory"]:AddItem(playerId, item, count)
        end,
    },
    ["core_inventory"] = {
        canCarry = function(playerId, item, count)
            return exports.core_inventory:canCarry(playerId, item, count)
        end,
        addItem = function(playerId, item, count)
            return exports.core_inventory:addItem(playerId, item, count)
        end,
    },
    ["origen_inventory"] = {
        canCarry = function(playerId, item, count)
            return exports.origen_inventory:canCarryItem(playerId, item, count)
        end,
        addItem = function(playerId, item, count)
            return exports.origen_inventory:addItem(playerId, item, count, nil, nil, true)
        end,
    },
    ["tgiann-inventory"] = {
        canCarry = function(playerId, item, count)
            return exports["tgiann-inventory"]:CanCarryItem(playerId, item, count)
        end,
        addItem = function(playerId, item, count)
            return exports["tgiann-inventory"]:AddItem(playerId, item, count)
        end,
    },
    ["jpr-inventory"] = qbStyle("jpr-inventory"),
    ["ps-inventory"] = qbStyle("ps-inventory"),
    ["qb-inventory"] = qbStyle("qb-inventory"),
}

local adapter <const> = ADAPTERS[inventory]

--- Checks whether a player has room for the items.
---@param playerId number The player's server id.
---@param item string The item name.
---@param count integer
---@return boolean canCarry
function Modules.Server.Inventory.CanCarryItem(playerId, item, count)
    return adapter.canCarry(playerId, item, count) and true or false
end

--- Gives items to a player.
---@param playerId number The player's server id.
---@param item string The item name.
---@param count integer
---@return boolean success
function Modules.Server.Inventory.AddItem(playerId, item, count)
    return adapter.addItem(playerId, item, count) and true or false
end
