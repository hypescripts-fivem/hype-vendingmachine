local Config <const> = require 'config.config'

local VENDING <const> = "olentrix_vending"

local catalog = {}
for _, product in ipairs(Config.Products) do
    catalog[product.id] = product
end

local function collect(vendId)
    TriggerServerEvent("hype-vendingmachine:server:vend-collect", vendId)
end

local function stockOf(machine, item)
    for _, product in ipairs(machine.stock or {}) do
        if product.item == item then return product.stock end
    end

    return 0
end

local function newLane(machine, item, slot)
    local product = catalog[item]
    local model = product and product.model and joaat(product.model)

    if not model or not IsModelInCdimage(model) then
        Debug("warning", "no shelf model for %s on machine %s", item, machine.data.id)
        return nil
    end

    local min, max = GetModelDimensions(model)
    local capacity, pitch = exports[VENDING]:GetSlotCapacity(max.y - min.y)

    return {
        slot = slot,
        model = model,
        front = exports[VENDING]:GetSlotOffset(slot, 1),
        lift = -min.z,
        pitch = pitch,
        capacity = capacity,
        entities = {},
    }
end

local function layout(machine, lane, count)
    local entities = lane.entities
    count = math.min(count, lane.capacity)

    while #entities > count do
        DeleteObject(table.remove(entities))
    end

    if #entities < count then
        local entity = machine.entity
        local ok = pcall(lib.requestModel, lane.model)

        if not ok or not entity or machine.entity ~= entity then return end

        local coords = GetEntityCoords(entity)
        for index = #entities + 1, count do
            local prop = CreateObjectNoOffset(lane.model, coords.x, coords.y, coords.z, false, false, false)
            SetEntityCollision(prop, false, false)
            entities[index] = prop
        end

        SetModelAsNoLongerNeeded(lane.model)
    end

    for position, prop in ipairs(entities) do
        AttachEntityToEntity(prop, machine.entity, 0, lane.front.x, lane.front.y + (position - 1) * lane.pitch, lane.front.z + lane.lift,
            0.0, 0.0, 0.0, false, false, false, false, 2, true)
    end
end

local function deleteLanes(shelf)
    for _, lane in pairs(shelf.lanes) do
        for _, prop in ipairs(lane.entities) do
            DeleteObject(prop)
        end
    end

    shelf.lanes = {}
end

function RefreshShelf(machine)
    local shelf = machine.shelf
    if not shelf or not machine.stock then return end

    local items = {}
    for index, product in ipairs(machine.stock) do
        items[index] = product.item
    end

    local key = table.concat(items, ",")

    if key ~= shelf.key then
        if shelf.vending then return end

        deleteLanes(shelf)
        shelf.key = key

        local slots = exports[VENDING]:GetSlots()
        local slot = 1

        for _, item in ipairs(items) do
            if not slots[slot] then break end

            local lane = newLane(machine, item, slots[slot])
            if lane then
                shelf.lanes[item] = lane
                slot = slot + 1
            end
        end
    end

    for item, lane in pairs(shelf.lanes) do
        layout(machine, lane, stockOf(machine, item) + (shelf.pending[item] or 0))
    end
end

function SetupShelf(machine)
    if GetResourceState(VENDING) ~= "started" then return end

    local entity = machine.entity

    if not exports[VENDING]:AddArm(entity) then
        Debug("error", "could not add the arm to machine %s", machine.data.id)
        return
    end

    local stock = lib.callback.await("hype-vendingmachine:server:get-stock", false, machine.data.id)

    if machine.entity ~= entity then
        exports[VENDING]:RemoveArm(entity)
        return
    end

    machine.stock = stock
    machine.shelf = { key = "", lanes = {}, queue = {}, pending = {}, vending = false }
    RefreshShelf(machine)
end

function ClearShelf(machine)
    local shelf = machine.shelf
    if not shelf then return end

    machine.shelf = nil

    for _, step in ipairs(shelf.queue) do
        if step.collect then collect(step.vendId) end
    end

    deleteLanes(shelf)

    if GetResourceState(VENDING) == "started" then
        exports[VENDING]:RemoveArm(machine.entity)
    end
end

local function vendUnit(machine, shelf, step)
    local lane = shelf.lanes[step.item]
    local prop = table.remove(lane.entities, 1)
    shelf.pending[step.item] = shelf.pending[step.item] - 1

    if prop then
        local dropped = promise.new()

        local started = exports[VENDING]:Vend(machine.entity, lane.slot, prop, function(held)
            if held and DoesEntityExist(held) then DeleteObject(held) end
            dropped:resolve()
        end)

        if started then
            Citizen.Await(dropped)
        else
            DeleteObject(prop)
        end
    end

    if machine.shelf == shelf then
        layout(machine, lane, stockOf(machine, step.item) + shelf.pending[step.item])
    end
end

local function runQueue(machine, shelf)
    if shelf.vending then return end
    shelf.vending = true

    CreateThread(function()
        while machine.shelf == shelf and #shelf.queue > 0 do
            local step = table.remove(shelf.queue, 1)

            if step.collect then
                collect(step.vendId)
            else
                vendUnit(machine, shelf, step)
            end
        end

        shelf.vending = false

        if machine.shelf == shelf then RefreshShelf(machine) end
    end)
end

function QueueVend(machine, vendId, buyer, lines)
    local mine = buyer == cache.serverId
    local shelf = machine and machine.shelf

    if not shelf then
        if mine then collect(vendId) end
        return
    end

    for _, line in ipairs(lines) do
        if shelf.lanes[line.item] then
            for _ = 1, line.quantity do
                shelf.queue[#shelf.queue + 1] = { vendId = vendId, item = line.item }
            end

            shelf.pending[line.item] = (shelf.pending[line.item] or 0) + line.quantity
        end
    end

    if mine then
        shelf.queue[#shelf.queue + 1] = { vendId = vendId, collect = true }
    end

    runQueue(machine, shelf)
end

function HasShelf(machine)
    return machine ~= nil and machine.shelf ~= nil
end
