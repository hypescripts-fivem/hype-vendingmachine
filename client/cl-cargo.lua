local Config <const> = require 'config.config'
local Cargo <const> = Config.Cargo
local Keys <const> = Config.Interaction.keys

local UPDATE_INTERVAL <const> = 250

local useTarget = Config.Interaction.target and (GetResourceState("ox_target") == "started" or GetResourceState("qb-target") == "started")

local job
local points = {}
local shownText

local function notify(message, type)
    exports['hype-core']:SendNotify(locale("notify_title"), message, 5000, type or "success")
end

local function addPoint(name, point)
    points[name] = point
    if not useTarget then return end

    local options = {}
    for index, option in ipairs(point.options) do
        options[index] = {
            name = option.label,
            label = option.label,
            icon = option.icon,
            distance = Config.Interaction.distance,
            offset = point.offset,
            absoluteOffset = point.offset ~= nil,
            bones = point.bones,
            canInteract = function() return job ~= nil and option.canInteract() end,
            onSelect = option.onSelect,
        }
    end

    if point.entity then
        exports['hype-core']:AddLocalEntity(point.entity, options)
    else
        exports['hype-core']:AddSphereZone("hype-vendingmachine:cargo-" .. name, point.coords, Config.Interaction.distance, options)
    end
end

local function removePoint(name)
    local point = points[name]
    if not point then return end

    points[name] = nil
    if not useTarget then return end

    if not point.entity then
        exports['hype-core']:RemoveZone("hype-vendingmachine:cargo-" .. name)
    elseif DoesEntityExist(point.entity) then
        local labels = {}
        for index, option in ipairs(point.options) do labels[index] = option.label end

        exports['hype-core']:RemoveLocalEntity(point.entity, labels)
    end
end

local function pointCoords(point, from)
    if point.coords then return point.coords end

    local nearest
    for _, name in ipairs(point.bones or {}) do
        local bone = GetEntityBoneIndexByName(point.entity, name)

        if bone ~= -1 then
            local coords = GetWorldPositionOfEntityBone(point.entity, bone)
            if not nearest or #(from - coords) < #(from - nearest) then nearest = coords end
        end
    end

    return nearest or GetOffsetFromEntityInWorldCoords(point.entity, point.offset or vec3(0.0, 0.0, 0.0))
end

local function createProp(model, coords)
    local hash = lib.requestModel(model)
    local entity = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    return entity
end

local function syncProps()
    local netIds = {}

    for _, entity in ipairs({ job.cart or 0, job.carrying or 0, table.unpack(job.cartBoxes) }) do
        if entity ~= 0 then netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(entity) end
    end

    TriggerServerEvent("hype-vendingmachine:server:cargo-props", netIds)
end

local function playAnim(anim)
    if not anim then
        ClearPedTasks(cache.ped)
        return
    end

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.name, 8.0, -8.0, -1, 49, anim.time or 0.0, false, false, false)
    RemoveAnimDict(anim.dict)
end

local function attachToPed(entity, attach)
    local ped = cache.ped
    local offset, rotation = attach.offset, attach.rotation

    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, attach.bone), offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, true, true, false, true, 2, true)
end

local function carry(box, fromCart)
    attachToPed(box, Cargo.boxAttach)
    playAnim(Cargo.boxAnim)

    job.carrying = box
    job.fromCart = fromCart
end

local function deleteCart()
    if job.holding then
        job.holding = false
        playAnim()
    end

    removePoint("cart")
    exports['hype-core']:RemoveEntity(job.cart)
    job.cart = nil

    syncProps()
end

local function grabCart()
    FreezeEntityPosition(job.cart, false)
    attachToPed(job.cart, Cargo.cartAttach)
    playAnim(Cargo.cartAnim)

    job.holding = true
    TriggerServerEvent("hype-vendingmachine:server:cargo-grab")
end

local function dropCart()
    DetachEntity(job.cart, true, true)
    PlaceObjectOnGroundProperly(job.cart)
    FreezeEntityPosition(job.cart, true)
    playAnim()

    job.holding = false

    if #job.cartBoxes == 0 and #(GetEntityCoords(job.cart) - job.spawn.xyz) <= Config.Interaction.maxDistance then
        deleteCart()
    end
end

local function loadBox(vehicle)
    exports['hype-core']:RemoveEntity(job.carrying)
    job.carrying = nil
    playAnim()

    job.vehicle = vehicle
    job.inVehicle = job.inVehicle + 1

    if job.fromCart then
        job.loaded = job.loaded + 1
        TriggerServerEvent("hype-vendingmachine:server:cargo-load")
    end

    syncProps()
end

local function endJob()
    for name in pairs(points) do removePoint(name) end

    for _, box in ipairs(job.cartBoxes) do exports['hype-core']:RemoveEntity(box) end
    exports['hype-core']:RemoveEntity(job.cart)
    exports['hype-core']:RemoveEntity(job.carrying)

    if job.holding or job.carrying then playAnim() end

    if shownText then
        shownText = nil
        exports['hype-core']:HideTextUI()
    end

    job = nil
end

local function deliverBox()
    CreateThread(function()
        if not lib.callback.await("hype-vendingmachine:server:cargo-deliver", false) or not job then return end

        exports['hype-core']:RemoveEntity(job.carrying)
        job.carrying = nil
        job.delivered = job.delivered + 1
        playAnim()

        if job.delivered == job.total then
            endJob()
        else
            syncProps()
        end
    end)
end

local function vehiclePoint(vehicle)
    return {
        entity = vehicle,
        bones = { "boot", "door_dside_r", "door_pside_r" },
        options = {
            {
                label = locale("target_cargo_load"),
                icon = "fa-solid fa-box",
                canInteract = function() return job.carrying ~= nil end,
                onSelect = function() loadBox(vehicle) end,
            },
            {
                label = locale("target_cargo_unload"),
                icon = "fa-solid fa-box-open",
                canInteract = function() return not job.carrying and not job.holding and job.inVehicle > 0 end,
                onSelect = function()
                    job.inVehicle = job.inVehicle - 1
                    carry(createProp(Cargo.boxModel, GetEntityCoords(cache.ped)), false)
                    syncProps()
                end,
            },
        },
    }
end

local function spawnProps()
    local spawn = job.spawn

    local cart = createProp(Cargo.model, spawn.xyz)
    SetEntityHeading(cart, spawn.w)
    PlaceObjectOnGroundProperly(cart)
    FreezeEntityPosition(cart, true)

    job.cart = cart
    job.arrived = true

    for index = 1, job.total do
        local box = createProp(Cargo.boxModel, spawn.xyz)
        local offset = Cargo.boxOffset + Cargo.boxStep * (index - 1)

        AttachEntityToEntity(box, cart, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        job.cartBoxes[index] = box
    end

    addPoint("cart", {
        entity = cart,
        offset = Cargo.handleOffset,
        options = {
            {
                label = locale("target_cargo_grab"),
                icon = "fa-solid fa-dolly",
                canInteract = function() return not job.holding and not job.carrying end,
                onSelect = grabCart,
            },
            {
                label = locale("target_cargo_take"),
                icon = "fa-solid fa-box",
                canInteract = function() return not job.holding and not job.carrying and #job.cartBoxes > 0 end,
                onSelect = function() carry(table.remove(job.cartBoxes), true) end,
            },
        },
    })

    syncProps()
end

local function availableOptions(coords)
    if job.holding then return { job.dropOption } end
    if useTarget then return {} end

    local nearest, nearestDistance = nil, Config.Interaction.distance
    for _, point in pairs(points) do
        local distance = #(coords - pointCoords(point, coords))
        if distance <= nearestDistance then nearest, nearestDistance = point, distance end
    end

    local options = {}
    for _, option in ipairs(nearest and nearest.options or {}) do
        if option.canInteract() then options[#options + 1] = option end
    end

    return options
end

local function showOptions(options)
    local text
    if options[1] then
        text = locale("textui_cargo", Keys.primary.label, options[1].label)
        if options[2] then
            text = text .. "  \n" .. locale("textui_cargo", Keys.secondary.label, options[2].label)
        end
    end

    if text == shownText then return end
    shownText = text

    if text then
        exports['hype-core']:ShowTextUI(text)
    else
        exports['hype-core']:HideTextUI()
    end
end

local function update()
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local distance = #(coords - job.spawn.xyz)

    if not job.arrived and distance <= Config.Interaction.spawnDistance then
        spawnProps()
    end

    local away = job.arrived and distance > Cargo.cancelDistance

    if away and job.loaded < job.total then
        TriggerServerEvent("hype-vendingmachine:server:cargo-cancel")
        endJob()
        return {}
    end

    if away and job.cart then deleteCart() end

    local vehicle = job.vehicle or (job.carrying and lib.getClosestVehicle(coords, 5.0, false))
    if vehicle ~= (points.vehicle and points.vehicle.entity) then
        removePoint("vehicle")
        if vehicle then addPoint("vehicle", vehiclePoint(vehicle)) end
    end

    local anim = job.holding and Cargo.cartAnim or job.carrying and Cargo.boxAnim
    if anim and not IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
        playAnim(anim)
    end

    local options = availableOptions(coords)
    showOptions(options)

    return options
end

local function jobLoop()
    local options, nextUpdate = {}, 0

    while job do
        local now = GetGameTimer()
        if now >= nextUpdate then
            options = update()
            nextUpdate = now + UPDATE_INTERVAL
        end

        if not job then break end

        local held = job.holding and Cargo.cartAnim
        if held and held.time then
            SetEntityAnimSpeed(cache.ped, held.dict, held.name, 0.0)
        end

        if options[1] then
            local selected
            if IsControlJustReleased(0, Keys.primary.control) then
                selected = options[1]
            elseif options[2] and IsControlJustReleased(0, Keys.secondary.control) then
                selected = options[2]
            end

            if selected then
                selected.onSelect()
                nextUpdate = 0
            end
        end

        Wait((options[1] or held) and 0 or UPDATE_INTERVAL)
    end
end

local function startJob(data)
    local spawn = Cargo.spawns[data.spawn]

    job = {
        spawn = spawn,
        arrived = false,
        cartBoxes = {},
        total = data.boxes,
        loaded = 0,
        inVehicle = 0,
        delivered = 0,
        holding = false,
        fromCart = false,
        dropOption = { label = locale("target_cargo_drop"), canInteract = function() return true end, onSelect = dropCart },
    }

    addPoint("machine", {
        coords = vec3(data.machine.x, data.machine.y, data.machine.z),
        options = {
            {
                label = locale("target_cargo_deliver"),
                icon = "fa-solid fa-box",
                canInteract = function() return job.carrying ~= nil and not job.fromCart end,
                onSelect = deliverBox,
            },
        },
    })

    SetNewWaypoint(spawn.x, spawn.y)
    notify(locale("notify_cargo_started"), "info")

    CreateThread(jobLoop)
end

function IsCarryingCargo()
    return job ~= nil and job.carrying ~= nil
end

RegisterNuiCallback("owner:pickup-order", function(data, cb)
    if job then
        cb({ success = false, error = locale("error_cargo_busy") })
        return
    end

    local response = lib.callback.await("hype-vendingmachine:server:owner-pickup-order", false, GetOpenMachine(), data.id)
    cb(response)

    if not response or not response.success then return end

    CloseUi()
    startJob(response.data)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() and job then
        endJob()
    end
end)
