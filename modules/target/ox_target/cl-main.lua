---@diagnostic disable: duplicate-set-field
if GetResourceState("ox_target") == "missing" then return end

local Config <const> = require "config.config"

local ox_target <const> = exports.ox_target
local zones = {}

--- Adds target options to a local (non-networked) entity.
---@param entity number The entity handle.
---@param options table[] ox_target style options (name, icon, label, distance, canInteract, onSelect).
---@return nil
function Modules.Client.Target.AddLocalEntity(entity, options)
    ox_target:addLocalEntity(entity, options)
end

--- Removes target options from a local entity.
---@param entity number The entity handle.
---@param names string[]? Option names to remove. Every option is removed when nil.
---@return nil
function Modules.Client.Target.RemoveLocalEntity(entity, names)
    ox_target:removeLocalEntity(entity, names)
end

--- Adds a sphere target zone.
---@param name string A unique zone name, used to remove it.
---@param coords vector3
---@param radius number
---@param options table[] ox_target style options.
---@return nil
function Modules.Client.Target.AddSphereZone(name, coords, radius, options)
    Modules.Client.Target.RemoveZone(name)

    zones[name] = ox_target:addSphereZone({
        name = name,
        coords = coords,
        radius = radius,
        debug = Config.Debug,
        options = options,
    })
end

--- Removes a target zone added with AddSphereZone.
---@param name string
---@return nil
function Modules.Client.Target.RemoveZone(name)
    if not zones[name] then return end

    ox_target:removeZone(zones[name])
    zones[name] = nil
end

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for name in pairs(zones) do
        Modules.Client.Target.RemoveZone(name)
    end
end)
