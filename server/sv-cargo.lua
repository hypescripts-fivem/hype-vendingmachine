local Config <const> = require 'config.config'
local Cargo <const> = Config.Cargo

local propModels <const> = {
    [joaat(Cargo.model) & 0xFFFFFFFF] = true,
    [joaat(Cargo.boxModel) & 0xFFFFFFFF] = true,
}

local jobs = {}
local remaining = {}

local function isBeingPickedUp(orderId)
    for _, job in pairs(jobs) do
        if job.orderId == orderId then return true end
    end

    return false
end

function StartCargo(playerId, row, orderId)
    if jobs[playerId] then return Fail(locale("error_cargo_busy")) end

    local order = orderId and MySQL.single.await(Queries.GetOrder, { orderId })
    if not order or order.machine_id ~= row.id or order.status ~= "prepared" or isBeingPickedUp(order.id) then
        return Fail(locale("error_order_not_ready"))
    end

    local boxes = remaining[order.id]
    if not boxes then
        boxes = {}
        for index, line in ipairs(MySQL.query.await(Queries.GetOrderItems, { { order.id } }) or {}) do
            boxes[index] = { item = line.item, quantity = line.quantity }
        end
    end

    local spawn = math.random(#Cargo.spawns)

    jobs[playerId] = {
        orderId = order.id,
        machineId = row.id,
        spawn = Cargo.spawns[spawn].xyz,
        boxes = boxes,
        loaded = 0,
        delivered = 0,
        shipping = false,
        props = {},
    }

    Debug("success", "player %s is picking up order %s (%d box(es)) at spawn %d", playerId, order.id, #boxes, spawn)

    return {
        success = true,
        data = {
            spawn = spawn,
            boxes = #boxes,
            machine = { x = row.x, y = row.y, z = row.z },
        }
    }
end

RegisterNetEvent("hype-vendingmachine:server:cargo-props", function(netIds)
    local job = jobs[source]
    if not job or type(netIds) ~= "table" or #netIds > #job.boxes + 2 then return end

    job.props = netIds
end)

RegisterNetEvent("hype-vendingmachine:server:cargo-grab", function()
    local job = jobs[source]
    if not job or job.shipping then return end

    job.shipping = true
    SetOrderStatus(job.orderId, job.machineId, "shipping")
end)

RegisterNetEvent("hype-vendingmachine:server:cargo-load", function()
    local playerId = source
    local job = jobs[playerId]
    if not job or job.loaded >= #job.boxes then return end

    if not IsPlayerNearCoords(playerId, job.spawn, Cargo.cancelDistance) then return end

    job.loaded = job.loaded + 1
end)

RegisterNetEvent("hype-vendingmachine:server:cargo-cancel", function()
    local playerId = source
    local job = jobs[playerId]
    if not job or job.loaded >= #job.boxes then return end

    jobs[playerId] = nil
    remaining[job.orderId] = nil

    SetOrderStatus(job.orderId, job.machineId, "cancelled")
    Notify(playerId, locale("notify_cargo_cancelled"), "error")
end)

lib.callback.register("hype-vendingmachine:server:cargo-deliver", function(source)
    local playerId = source
    local job = jobs[playerId]
    if not job or job.delivered >= job.loaded then return false end

    local row = MySQL.single.await(Queries.GetMachine, { job.machineId })
    if not row or not IsPlayerNearCoords(playerId, vector3(row.x, row.y, row.z), Config.Interaction.maxDistance) then
        return false
    end

    job.delivered = job.delivered + 1
    local box = job.boxes[job.delivered]

    MySQL.update.await(Queries.AddStock, { box.quantity, row.capacity, row.id, box.item })
    SyncStock(row)

    if job.delivered < #job.boxes then return true end

    jobs[playerId] = nil
    remaining[job.orderId] = nil

    SetOrderStatus(job.orderId, job.machineId, "completed")
    Notify(playerId, locale("notify_cargo_delivered", row.name))

    return true
end)

AddEventHandler("playerDropped", function()
    local playerId = source
    local job = jobs[playerId]
    if not job then return end

    jobs[playerId] = nil

    for _, netId in ipairs(job.props) do
        local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)

        if DoesEntityExist(entity) and propModels[GetEntityModel(entity) & 0xFFFFFFFF] and NetworkGetFirstEntityOwner(entity) == playerId then
            DeleteEntity(entity)
        end
    end

    remaining[job.orderId] = { table.unpack(job.boxes, job.delivered + 1) }

    if job.shipping then
        SetOrderStatus(job.orderId, job.machineId, "prepared")
    end
end)
