--- Shows a notification to a player.
---@param playerId number The player's server id.
---@param title string
---@param message string
---@param time number? Milliseconds, 5000 by default.
---@param type string? "success" | "error" | "inform" | "warning", "success" by default.
---@return nil
function Modules.Server.Notify.SendNotify(playerId, title, message, time, type)
    TriggerClientEvent("hype-vendingmachine:client:notify", playerId, title, message, time, type)
end
