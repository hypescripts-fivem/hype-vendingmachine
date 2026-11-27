---@diagnostic disable: duplicate-set-field
if GetResourceState("qb-target") == "missing" then return end
if GetResourceState("ox_target") ~= "missing" then return end

local Config <const> = require "config.config"

local qb_target <const> = exports["qb-target"]
local zones = {}
local entityLabels = {}

--- Converts ox_target style options to qb-target: `onSelect` becomes `action`, and qb-target
--- removes options by label, so the labels are returned too.
---@param options table[]
---@return table[] options
---@return number distance The largest option distance.
---@return string[] labels
local function convert(options)
    local distance, labels = 0, {}

    for index, option in ipairs(options) do
        option.action = option.action or option.onSelect
        distance = math.max(distance, option.distance or 0)
        labels[index] = option.label
    end

    return options, distance > 0 and distance or 2.0, labels
end

--- Adds target options to a local (non-networked) entity.
---@param entity number The entity handle.
---@param options table[] ox_target style options (name, icon, label, distance, canInteract, onSelect).
---@return nil
function Modules.Client.Target.AddLocalEntity(entity, options)
    local converted, distance, labels = convert(options)

    qb_target:AddTargetEntity(entity, { options = converted, distance = distance })

    local list = entityLabels[entity] or {}
    for _, label in ipairs(labels) do list[#list + 1] = label end
    entityLabels[entity] = list
end

--- Removes target options from a local entity.
---@param entity number The entity handle.
---@param names string[]? Labels of the options to remove (the vending options use the label as name). Every option is removed when nil.
---@return nil
function Modules.Client.Target.RemoveLocalEntity(entity, names)
    qb_target:RemoveTargetEntity(entity, names or entityLabels[entity] or {})
    if not names then entityLabels[entity] = nil end
end

--- Adds a sphere target zone.
---@param name string A unique zone name, used to remove it.
---@param coords vector3
---@param radius number
---@param options table[] ox_target style options.
---@return nil
function Modules.Client.Target.AddSphereZone(name, coords, radius, options)
    Modules.Client.Target.RemoveZone(name)

    local converted, distance = convert(options)

    qb_target:AddCircleZone(name, coords, radius, { name = name, debugPoly = Config.Debug }, {
        options = converted,
        distance = distance,
    })

    zones[name] = true
end

--- Removes a target zone added with AddSphereZone.
---@param name string
---@return nil
function Modules.Client.Target.RemoveZone(name)
    if not zones[name] then return end

    qb_target:RemoveZone(name)
    zones[name] = nil
end

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for name in pairs(zones) do
        Modules.Client.Target.RemoveZone(name)
    end
end)
