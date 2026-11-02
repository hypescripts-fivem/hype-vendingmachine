local Config <const> = require 'config.config'

-- Arm machines (Config.Machines `arm`): their stock is shown on the shelves and olentrix_vending's arm vends each unit sold
local VENDING <const> = "olentrix_vending"

--- @type table<string, CatalogProduct>
local catalog = {}
for _, product in ipairs(Config.Products) do
    catalog[product.id] = product
end

--- @param vendId integer
local function collect(vendId)
    TriggerServerEvent("hype-vendingmachine:server:vend-collect", vendId)
    Debug("info", "collecting vend %s", vendId)
end

--- @param data MachineProp
--- @param item string
--- @return integer
local function stockOf(data, item)
    for _, product in ipairs(data.products) do
        if product.item == item then return product.stock end
    end

    return 0
end

--- @param machine MachineEntry
--- @param item string
--- @param slot string
--- @return ShelfLane?
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

--- Spawns or deletes props so the lane shows `count` of them, then puts them in place from the front
--- @param machine MachineEntry
--- @param lane ShelfLane
--- @param count integer
local function layout(machine, lane, count)
    local entities = lane.entities
    count = math.min(count, lane.capacity)

    while #entities > count do
        DeleteObject(table.remove(entities))
    end

    if #entities < count then
        local entity = machine.entity
        local ok = pcall(lib.requestModel, lane.model)

        -- The prop went away while the model loaded
        if not ok or machine.entity ~= entity or not entity then return end

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

--- @param shelf Shelf
local function deleteLanes(shelf)
    for _, lane in pairs(shelf.lanes) do
        for _, prop in ipairs(lane.entities) do
            DeleteObject(prop)
        end
    end

    shelf.lanes = {}
end

--- Matches the shelves to the machine's products and stock. A product change (admin edit) rebuilds the lanes,
--- after the arm is done if it's working
--- @param machine MachineEntry
function RefreshShelf(machine)
    local shelf = machine.shelf
    if not shelf then return end

    local items = {}
    for index, product in ipairs(machine.data.products) do
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
        layout(machine, lane, stockOf(machine.data, item) + (shelf.pending[item] or 0))
    end
end

--- Puts the arm in a freshly spawned arm machine and fills its shelves
--- @param machine MachineEntry
function SetupShelf(machine)
    if not ArmModels[machine.data.model] or GetResourceState(VENDING) ~= "started" then return end

    local entity = machine.entity

    if not exports[VENDING]:AddArm(entity) then
        Debug("error", "could not add the arm to machine %s", machine.data.id)
        return
    end

    -- The prop went away while the arm's models loaded
    if machine.entity ~= entity then
        exports[VENDING]:RemoveArm(entity)
        return
    end

    machine.shelf = { key = "", lanes = {}, queue = {}, pending = {}, vending = false }
    RefreshShelf(machine)
    Debug("info", "set up the shelves of machine %s", machine.data.id)
end

--- Before the prop is deleted: the props and arm go, and this player's waiting vends are collected now
--- @param machine MachineEntry
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

--- Works through the queue, one unit at a time: the arm takes the front prop of the lane to the tray
--- @param machine MachineEntry
--- @param shelf Shelf
local function runQueue(machine, shelf)
    if shelf.vending then return end
    shelf.vending = true

    CreateThread(function()
        while machine.shelf == shelf and #shelf.queue > 0 do
            local step = table.remove(shelf.queue, 1)

            if step.collect then
                collect(step.vendId)
            else
                local lane = shelf.lanes[step.item]
                local prop = table.remove(lane.entities, 1)
                shelf.pending[step.item] = shelf.pending[step.item] - 1

                if prop then
                    local dropped = promise.new()

                    -- The dropped prop is deleted once the arm is back home
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
                    layout(machine, lane, stockOf(machine.data, step.item) + shelf.pending[step.item])
                end
            end
        end

        shelf.vending = false

        -- Products changed while the arm was working
        if machine.shelf == shelf then RefreshShelf(machine) end
    end)
end

--- Queues the units of a checkout for the arm. The buyer collects after its last unit, or right away without an arm
--- @param machine MachineEntry?
--- @param vendId integer
--- @param buyer integer Server id
--- @param lines SaleLine[]
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

    Debug("info", "queued vend %s on machine %s (%d step(s) waiting)", vendId, machine.data.id, #shelf.queue)

    runQueue(machine --[[@as MachineEntry]], shelf)
end

--- Arm machines close the page after a checkout, so the buyer can watch the arm
--- @param machine MachineEntry?
--- @return boolean
function HasShelf(machine)
    return machine ~= nil and machine.shelf ~= nil
end
