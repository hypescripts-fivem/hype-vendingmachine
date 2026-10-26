local Config <const> = require 'config.config'

--- Pickups in progress, by player
--- @type table<integer, CargoJob>
local jobs = {}

--- Boxes not delivered yet of pickups cut short by a disconnect, so the next pickup doesn't bring them twice
--- @type table<integer, CargoBox[]>
local remaining = {}

--- @param orderId integer
--- @return boolean
local function isBeingPickedUp(orderId)
    for _, job in pairs(jobs) do
        if job.orderId == orderId then return true end
    end

    return false
end

--- Called by owner-pickup-order once the machine and permission are checked
--- @param playerId integer
--- @param row MachineRow
--- @param orderId integer?
--- @return CallbackResponse
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

    local spawn = math.random(#Config.Cargo.spawns)

    jobs[playerId] = {
        orderId = order.id,
        machineId = row.id,
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

-- The client's cart and boxes, deleted by the server if the player drops
RegisterNetEvent("hype-vendingmachine:server:cargo-props", function(netIds)
    local job = jobs[source]
    if not job or type(netIds) ~= "table" then return end

    job.props = netIds
end)

-- The first grab of the cart puts the order on its way
RegisterNetEvent("hype-vendingmachine:server:cargo-grab", function()
    local job = jobs[source]
    if not job or job.shipping then return end

    job.shipping = true
    SetOrderStatus(job.orderId, job.machineId, "shipping")
end)

RegisterNetEvent("hype-vendingmachine:server:cargo-load", function()
    local job = jobs[source]
    if not job or job.loaded >= #job.boxes then return end

    job.loaded = job.loaded + 1
    Debug("info", "player %s loaded box %d/%d of order %s", source, job.loaded, #job.boxes, job.orderId)
end)

-- Sent by the client when the player went past Config.Cargo.cancelDistance before every box was loaded
RegisterNetEvent("hype-vendingmachine:server:cargo-cancel", function()
    local playerId = source
    local job = jobs[playerId]
    if not job or job.loaded >= #job.boxes then return end

    jobs[playerId] = nil
    remaining[job.orderId] = nil

    SetOrderStatus(job.orderId, job.machineId, "cancelled")
    Notify(playerId, locale("notify_cargo_cancelled"), "error")
end)

-- Each box adds its product's stock; the last one completes the order
lib.callback.register("hype-vendingmachine:server:cargo-deliver", function(source)
    local playerId = source
    local job = jobs[playerId]
    if not job or job.delivered >= job.loaded then return false end

    local row = MySQL.single.await(Queries.GetMachine, { job.machineId })
    if not row or not exports['hype-core']:IsPlayerNearCoords(playerId, vector3(row.x, row.y, row.z), Config.Interaction.maxDistance) then
        return false
    end

    job.delivered = job.delivered + 1
    local box = job.boxes[job.delivered]

    -- Never above capacity, even if the admin lowered it after the order
    MySQL.update.await(Queries.AddStock, { box.quantity, row.capacity, row.id, box.item })
    Debug("success", "player %s delivered %sx %s to machine %s (%d/%d)", playerId, box.quantity, box.item, row.id, job.delivered, #job.boxes)

    if job.delivered < #job.boxes then return true end

    jobs[playerId] = nil
    remaining[job.orderId] = nil

    SetOrderStatus(job.orderId, job.machineId, "completed")
    Notify(playerId, locale("notify_cargo_delivered", row.name))

    return true
end)

-- The props go, the order waits for a new pickup with the boxes that weren't delivered
AddEventHandler("playerDropped", function()
    local job = jobs[source]
    if not job then return end

    jobs[source] = nil

    for _, netId in ipairs(job.props) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end

    remaining[job.orderId] = { table.unpack(job.boxes, job.delivered + 1) }

    if job.shipping then
        SetOrderStatus(job.orderId, job.machineId, "prepared")
    end
end)
