local Config <const> = require "config.config"

local PROVIDERS <const> = { "okokNotify", "ps-ui", "ox_lib" }

local TYPES <const> = {
    okokNotify = { inform = "info" },
    ["ps-ui"] = { inform = "primary" },
}

--- Returns the notification resource to use, honouring Config.Notifications. Falls back to ox_lib,
--- which is always running as a dependency.
---@return string resource
local function provider()
    if Config.Notifications ~= "auto" then return Config.Notifications end

    for _, name in ipairs(PROVIDERS) do
        if GetResourceState(name) == "started" then return name end
    end

    return "ox_lib"
end

--- Shows a notification to the local player.
---@param title string
---@param message string
---@param time number? Milliseconds, 5000 by default.
---@param type string? "success" | "error" | "inform" | "warning", "success" by default.
---@return nil
function Modules.Client.Notify.SendNotify(title, message, time, type)
    local resource = provider()
    time = time or 5000
    type = type or "success"
    type = TYPES[resource] and TYPES[resource][type] or type

    if resource == "okokNotify" then
        exports["okokNotify"]:Alert(title, message, time, type)
    elseif resource == "ps-ui" then
        exports["ps-ui"]:Notify(message, type, time)
    else
        lib.notify({ title = title, description = message, type = type, duration = time })
    end
end

RegisterNetEvent("hype-vendingmachine:client:notify", function(title, message, time, type)
    Modules.Client.Notify.SendNotify(title, message, time, type)
end)
