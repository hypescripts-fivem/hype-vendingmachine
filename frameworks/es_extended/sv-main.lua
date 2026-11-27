---@diagnostic disable: duplicate-set-field
if Framework.Name ~= "es_extended" then return end

local ESX <const> = exports.es_extended:getSharedObject()

--- ESX calls the cash account "money".
---@param account "cash"|"bank"
---@return string
local function accountName(account)
    return account == "cash" and "money" or account
end

--- Returns the ESX identifier of a player.
---@param playerId number The player's server id.
---@return string? identifier The identifier, or nil when the player is not loaded.
function Framework.Server.GetPlayerIdentifier(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    return xPlayer and xPlayer.getIdentifier() or nil
end

--- Returns the server id of an online character.
---@param identifier string The ESX identifier.
---@return number? playerId The server id, or nil when the character is offline.
function Framework.Server.GetPlayerSource(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    return xPlayer and xPlayer.source or nil
end

--- Returns the character name of a player.
---@param playerId number The player's server id.
---@return string? name The character name, or nil when the player is not loaded.
function Framework.Server.GetCharacterName(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    return xPlayer and xPlayer.getName() or nil
end

--- Returns the balance of a player's account.
---@param playerId number The player's server id.
---@param account "cash"|"bank"
---@return number balance
function Framework.Server.GetPlayerMoney(playerId, account)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local data = xPlayer and xPlayer.getAccount(accountName(account))
    return data and data.money or 0
end

--- Adds money to a player's account.
---@param playerId number The player's server id.
---@param account "cash"|"bank"
---@param amount number
---@return boolean success
function Framework.Server.AddPlayerMoney(playerId, account, amount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end

    xPlayer.addAccountMoney(accountName(account), amount)
    return true
end

--- Removes money from a player's account, only when the balance covers it.
---@param playerId number The player's server id.
---@param account "cash"|"bank"
---@param amount number
---@return boolean success
function Framework.Server.RemovePlayerMoney(playerId, account, amount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer or Framework.Server.GetPlayerMoney(playerId, account) < amount then return false end

    xPlayer.removeAccountMoney(accountName(account), amount)
    return true
end
