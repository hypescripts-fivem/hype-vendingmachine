--- Checks whether a player is an admin: allowed the "command" ace, as with `add_ace group.admin command allow`.
---@param playerId number The player's server id.
---@return boolean
function IsAdmin(playerId)
    return IsPlayerAceAllowed(tostring(playerId), "command") or false
end

--- Checks whether a server id belongs to a connected player.
---@param playerId number?
---@return boolean
function IsPlayerOnline(playerId)
    return playerId ~= nil and GetPlayerName(playerId) ~= nil
end

--- Checks whether a player is within maxDistance of the coords.
---@param playerId number The player's server id.
---@param coords vector3|table
---@param maxDistance number
---@return boolean
function IsPlayerNearCoords(playerId, coords, maxDistance)
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return false end

    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z)) <= maxDistance
end

--- Returns the in-game time from GlobalState.currentTime, which the weather / time sync
--- resource (qbx_weathersync, Renewed-Weathersync, ...) keeps up to date.
---@return { hour: integer, minute: integer }? time nil when no resource provides it.
function GetGameTime()
    local time = GlobalState.currentTime
    if type(time) ~= "table" or type(time.hour) ~= "number" or type(time.minute) ~= "number" then return nil end

    return { hour = time.hour, minute = time.minute }
end

--- Describes a player for the webhook logs: name, server id, character, license and Discord mention.
---@param playerId number The player's server id.
---@return string
function FormatPlayerForLog(playerId)
    local license = GetPlayerIdentifierByType(playerId, "license")
    local discord = GetPlayerIdentifierByType(playerId, "discord")

    local parts = {
        ("%s (ID: %s)"):format(Framework.Server.GetCharacterName(playerId) or GetPlayerName(playerId) or "Unknown", playerId),
        Framework.Server.GetPlayerIdentifier(playerId) or "no-character",
    }

    if license then parts[#parts + 1] = license end
    if discord then parts[#parts + 1] = ("discord: <@%s>"):format(discord:gsub("discord:", "")) end

    return table.concat(parts, " | ")
end
