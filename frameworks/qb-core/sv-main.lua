---@diagnostic disable: duplicate-set-field
if Framework.Name ~= "qb-core" then return end

local QBCore <const> = exports["qb-core"]:GetCoreObject()

--- Returns the citizenid of a player.
---@param playerId number The player's server id.
---@return string? identifier The citizenid, or nil when the player is not loaded.
function Framework.Server.GetPlayerIdentifier(playerId)
    local Player = QBCore.Functions.GetPlayer(playerId)
    return Player and Player.PlayerData.citizenid or nil
end

--- Returns the server id of an online character.
---@param identifier string The citizenid.
---@return number? playerId The server id, or nil when the character is offline.
function Framework.Server.GetPlayerSource(identifier)
    local Player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    return Player and Player.PlayerData.source or nil
end

--- Returns the character name of a player.
---@param playerId number The player's server id.
---@return string? name "Firstname Lastname", or nil when the player is not loaded.
function Framework.Server.GetCharacterName(playerId)
    local Player = QBCore.Functions.GetPlayer(playerId)
    local info = Player and Player.PlayerData.charinfo
    if not info or not info.firstname or not info.lastname then return nil end
    return ("%s %s"):format(info.firstname, info.lastname)
end

--- Returns the balance of a player's account.
---@param playerId number The player's server id.
---@param account "cash"|"bank"
---@return number balance
function Framework.Server.GetPlayerMoney(playerId, account)
    local Player = QBCore.Functions.GetPlayer(playerId)
    return Player and Player.Functions.GetMoney(account) or 0
end

--- Adds money to a player's account.
---@param playerId number The player's server id.
---@param account "cash"|"bank"
---@param amount number
---@return boolean success
function Framework.Server.AddPlayerMoney(playerId, account, amount)
    local Player = QBCore.Functions.GetPlayer(playerId)
    return Player ~= nil and Player.Functions.AddMoney(account, amount) ~= false
end

--- Removes money from a player's account, only when the balance covers it.
---@param playerId number The player's server id.
---@param account "cash"|"bank"
---@param amount number
---@return boolean success
function Framework.Server.RemovePlayerMoney(playerId, account, amount)
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player or Player.Functions.GetMoney(account) < amount then return false end
    return Player.Functions.RemoveMoney(account, amount) ~= false
end
