local Config <const> = require 'config.config'
local Cargo <const> = Config.Cargo

local useTarget = Config.Interaction.target and (GetResourceState("ox_target") == "started" or GetResourceState("qb-target") == "started")

--- @type CargoState?
local job

--- What the player can use during the job: the cart, a vehicle and the machine.
--- With a target resource they're handed to it, otherwise the job loop shows them as TextUI
--- @type table<string, CargoPoint>
local points = {}

-- TextUI only: what's on screen, so it's only sent again when it changes
--- @type string?
local shownText

--- @param message string
--- @param type? "success" | "error" | "info" | "warning"
local function notify(message, type)
    exports['hype-core']:SendNotify(locale("notify_title"), message, 5000, type or "success")
end

--- @param name string
--- @param point CargoPoint
local function addPoint(name, point)
    points[name] = point
    if not useTarget then return end

    local options = {}
    for index, option in ipairs(point.options) do
        -- The label doubles as the name: ox_target removes options by name, qb-target by label
        options[index] = {
            name = option.label,
            label = option.label,
            icon = option.icon,
            distance = Config.Interaction.distance,
            -- In metres from the entity, like the TextUI; without absoluteOffset ox_target reads it as a fraction of the model size
            offset = point.offset,
            absoluteOffset = point.offset ~= nil,
            bones = point.bones,
            -- ox_target can still ask right after the job ended
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

--- @param name string
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

--- Where the point's TextUI is reached from: its coords, the bone nearest the player, or the entity offset
--- @param point CargoPoint
--- @param from vector3 The player's position
--- @return vector3
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

--- @param model string
--- @param coords vector3
--- @return integer
local function createProp(model, coords)
    local hash = lib.requestModel(model)
    local entity = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    return entity
end

--- Tells the server which props to delete if the player drops
local function syncProps()
    local netIds = {}

    for _, entity in ipairs({ job.cart or 0, job.carrying or 0, table.unpack(job.cartBoxes) }) do
        if entity ~= 0 then netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(entity) end
    end

    TriggerServerEvent("hype-vendingmachine:server:cargo-props", netIds)
end

--- @param anim? CargoAnim Stops the current one when omitted
local function playAnim(anim)
    local ped = PlayerPedId()

    if not anim then
        ClearPedTasks(ped)
        return
    end

    lib.requestAnimDict(anim.dict)
    -- 49: loop, upper body only, the player keeps control (legs walk). The 8th argument is where it starts, 0-1
    TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, -1, 49, anim.time or 0.0, false, false, false)
    RemoveAnimDict(anim.dict)
end

--- @param entity integer
--- @param attach CargoAttach
local function attachToPed(entity, attach)
    local ped = PlayerPedId()
    local offset, rotation = attach.offset, attach.rotation

    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, attach.bone), offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, true, true, false, true, 2, true)
end

--- @param box integer
--- @param fromCart boolean
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
    Debug("info", "cart removed")
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

    -- Emptied and back where it was picked up
    if #job.cartBoxes == 0 and #(GetEntityCoords(job.cart) - job.spawn.xyz) <= Config.Interaction.maxDistance then
        deleteCart()
    end
end

--- @param vehicle integer
local function loadBox(vehicle)
    exports['hype-core']:RemoveEntity(job.carrying)
    job.carrying = nil
    playAnim()

    -- The first vehicle loaded is the job's
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
    Debug("info", "cargo job ended")
end

-- Awaits the server, so it runs in its own thread: target callbacks come from another resource
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

--- Load and unload options on the vehicle's trunk, or the rear doors of a van like the burrito
--- @param vehicle integer
--- @return CargoPoint
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
                    carry(createProp(Cargo.boxModel, GetEntityCoords(PlayerPedId())), false)
                    syncProps()
                end,
            },
        },
    }
end

--- Puts the cart and its boxes at the spawn once the player gets there
local function spawnProps()
    local spawn = job.spawn

    -- The configured height is the player's; the ground is loaded by now, so the cart goes down onto it
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
    Debug("info", "cargo props spawned")
end

--- @param data { spawn: integer, boxes: integer, machine: { x: number, y: number, z: number } }
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
    }

    addPoint("machine", {
        coords = vec3(data.machine.x, data.machine.y, data.machine.z),
        options = {
            {
                label = locale("target_cargo_deliver"),
                icon = "fa-solid fa-box",
                -- Only boxes that came out of the vehicle
                canInteract = function() return job.carrying ~= nil and not job.fromCart end,
                onSelect = deliverBox,
            },
        },
    })

    SetNewWaypoint(spawn.x, spawn.y)
    notify(locale("notify_cargo_started"), "info")
    Debug("success", "cargo job started at spawn %d with %d box(es)", data.spawn, data.boxes)

    local dropOption = { label = locale("target_cargo_drop"), canInteract = function() return true end, onSelect = dropCart }

    CreateThread(function()
        while job do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local distance = #(coords - job.spawn.xyz)
            local sleep = 500

            if not job.arrived and distance <= Config.Interaction.spawnDistance then
                spawnProps()
            end

            -- Leaving only counts once the cart is there
            local away = job.arrived and distance > Cargo.cancelDistance

            if away and job.loaded < job.total then
                Debug("warning", "left the pickup area, cancelling the order")
                TriggerServerEvent("hype-vendingmachine:server:cargo-cancel")
                endJob()
                break
            end

            -- Every box is loaded and the cart wasn't brought back
            if away and job.cart then deleteCart() end

            -- Until the first load any vehicle nearby can take the box
            local vehicle = job.vehicle or (job.carrying and lib.getClosestVehicle(coords, 5.0, false))
            if vehicle ~= (points.vehicle and points.vehicle.entity) then
                removePoint("vehicle")
                if vehicle then addPoint("vehicle", vehiclePoint(vehicle)) end
            end

            -- Ragdoll, entering a vehicle and the like stop the animation
            local anim = job.holding and Cargo.cartAnim or job.carrying and Cargo.boxAnim
            if anim and not IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
                playAnim(anim)
            elseif anim and anim.time then
                -- Started at anim.time by playAnim; held there once it's playing
                SetEntityAnimSpeed(ped, anim.dict, anim.name, 0.0)
            end

            local options = {}

            if job.holding then
                options = { dropOption }
            elseif not useTarget then
                local nearest, nearestDistance = nil, Config.Interaction.distance

                for _, point in pairs(points) do
                    local distance = #(coords - pointCoords(point, coords))
                    if distance <= nearestDistance then nearest, nearestDistance = point, distance end
                end

                for _, option in ipairs(nearest and nearest.options or {}) do
                    if option.canInteract() then options[#options + 1] = option end
                end
            end

            local keys = Config.Interaction.keys
            local lines = {}
            for index, key in ipairs({ keys.primary, keys.secondary }) do
                if options[index] then lines[index] = locale("textui_cargo", key.label, options[index].label) end
            end

            local text = #lines > 0 and table.concat(lines, "  \n") or nil
            if text ~= shownText then
                shownText = text

                if text then
                    exports['hype-core']:ShowTextUI(text)
                else
                    exports['hype-core']:HideTextUI()
                end
            end

            if text then
                sleep = 0

                if IsControlJustReleased(0, keys.primary.control) then
                    options[1].onSelect()
                elseif options[2] and IsControlJustReleased(0, keys.secondary.control) then
                    options[2].onSelect()
                end
            end

            Wait(sleep)
        end
    end)
end

--- cl-main.lua keeps the machine's own TextUI out of the way while a box is carried to it
--- @return boolean
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

    SetNuiFocus(false, false)
    NuiMessage("close", {})
    TriggerEvent("hype-vendingmachine:client:ui-closed")

    startJob(response.data)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() and job then
        endJob()
    end
end)
