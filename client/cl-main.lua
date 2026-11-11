local Config <const> = require 'config.config'

local useTarget = Config.Interaction.target and (GetResourceState("ox_target") == "started" or GetResourceState("qb-target") == "started")

local machines = {}
local identifier
local staffMachines = {}

local currentMachine
local currentView
local viewData = {}

local textMachine
local busy = false

local function notify(response)
    if not response then return end

    local message = response.success and response.data and response.data.message or response.error
    if not message then return end

    exports['hype-core']:SendNotify(locale("notify_title"), message, 5000, response.success and "success" or "error")
end

local function canManage(data)
    return (identifier ~= nil and data.owner == identifier) or staffMachines[data.id] == true
end

function CloseUi()
    NuiMessage("close", {})
    SetNuiFocus(false, false)
    TriggerEvent("hype-vendingmachine:client:ui-closed")
end

local function requestView(view, callback, data)
    local response = lib.callback.await(callback, false, data.id)

    if not response or not response.success then
        notify(response)
        return nil
    end

    currentMachine = data.id
    currentView = view
    return response
end

local function openView(view, callback, data)
    local response = requestView(view, callback, data)
    if not response then return end

    viewData[view] = response.data
    NuiMessage("setView", { view = view })
    SetNuiFocus(true, true)
end

function GetOpenMachine()
    return currentMachine, currentView
end

function GetViewData(view)
    return viewData[view]
end

local function openPurchase(data)
    openView("purchase", "hype-vendingmachine:server:get-purchase-data", data)
end

local function openVending(data)
    local machine = machines[data.id]

    if not HasShelf(machine) then
        openView("vending", "hype-vendingmachine:server:get-vending-data", data)
        return
    end

    local response = requestView("screen", "hype-vendingmachine:server:get-vending-data", data)
    if not response then return end

    viewData.vending = response.data

    if not OpenScreen(machine) then
        currentView = nil
    end
end

local function openOwner(data)
    openView("owner", "hype-vendingmachine:server:get-owner-data", data)
end

local function run(action, data)
    if busy or IsPlacing() then return end
    busy = true

    CreateThread(function()
        local ok, err = pcall(action, data)
        busy = false

        if not ok then error(err) end
    end)
end

local function targetOptions(machine)
    return {
        {
            name = "hype-vendingmachine:buy",
            icon = "fa-solid fa-cart-shopping",
            label = locale("target_buy"),
            distance = Config.Interaction.distance,
            canInteract = function()
                return machine.data.forSale and machine.data.status ~= "disabled"
            end,
            onSelect = function()
                run(openPurchase, machine.data)
            end,
        },
        {
            name = "hype-vendingmachine:open",
            icon = "fa-solid fa-store",
            label = locale("target_open"),
            distance = Config.Interaction.distance,
            canInteract = function()
                return not machine.data.forSale
            end,
            onSelect = function()
                run(openVending, machine.data)
            end,
        },
        {
            name = "hype-vendingmachine:manage",
            icon = "fa-solid fa-briefcase",
            label = locale("target_manage"),
            distance = Config.Interaction.distance,
            canInteract = function()
                return not machine.data.forSale and canManage(machine.data)
            end,
            onSelect = function()
                run(openOwner, machine.data)
            end,
        },
    }
end

local function showText(machine)
    if IsCarryingCargo() then return end

    local data, keys = machine.data, Config.Interaction.keys
    local lines

    if data.forSale then
        if data.status == "disabled" then
            exports['hype-core']:HideTextUI()
            return
        end

        lines = { locale("textui_buy", keys.primary.label, lib.math.groupdigits(data.price)) }
    else
        lines = { locale("textui_open", keys.primary.label) }

        if canManage(data) then
            lines[2] = locale("textui_manage", keys.secondary.label)
        end
    end

    exports['hype-core']:ShowTextUI(table.concat(lines, "  \n"))
end

local function onTextKey(machine)
    if IsCarryingCargo() then return end

    local data, keys = machine.data, Config.Interaction.keys

    if IsControlJustReleased(0, keys.primary.control) then
        if not data.forSale then
            run(openVending, data)
        elseif data.status ~= "disabled" then
            run(openPurchase, data)
        end
    elseif IsControlJustReleased(0, keys.secondary.control) and not data.forSale and canManage(data) then
        run(openOwner, data)
    end
end

local function removeEntity(machine)
    if not machine.entity then return end

    if IsScreenOpen(machine.data.id) then
        CloseScreen()
    end

    if useTarget then
        exports['hype-core']:RemoveLocalEntity(machine.entity)
    end

    ClearShelf(machine)
    exports['hype-core']:RemoveEntity(machine.entity)
    machine.entity = nil
end

local function removeMachine(machineId)
    local machine = machines[machineId]
    if not machine then return end

    machines[machineId] = nil
    machine.point:remove()

    if machine.textPoint then
        machine.textPoint:remove()
    end

    if textMachine == machine then
        textMachine = nil
        exports['hype-core']:HideTextUI()
    end

    removeEntity(machine)
end

local function spawnProp(machine)
    local data = machine.data
    local entity = exports['hype-core']:CreateLocalProp(data.model, vec4(data.x, data.y, data.z, data.heading))
    if not entity then
        Debug("error", "could not spawn %s for machine %s", data.model, data.id)
        return
    end

    if machines[data.id] ~= machine or not machine.inside then
        exports['hype-core']:RemoveEntity(entity)
        return
    end

    PlaceObjectOnGroundProperly(entity)
    machine.entity = entity

    if useTarget then
        exports['hype-core']:AddLocalEntity(entity, targetOptions(machine))
    end

    if ArmModels[data.model] then
        SetupShelf(machine)
        ShowIdleScreens()
    end
end

local function setMachine(data)
    local current = machines[data.id]

    if current and current.data.model == data.model and current.data.x == data.x and current.data.y == data.y
        and current.data.z == data.z and current.data.heading == data.heading then
        current.data = data

        if textMachine == current then
            showText(current)
        end

        return
    end

    removeMachine(data.id)

    local machine = { data = data, inside = false }
    local coords = vec3(data.x, data.y, data.z)

    machine.point = lib.points.new({
        coords = coords,
        distance = Config.Interaction.spawnDistance,
        onEnter = function()
            machine.inside = true
            if not machine.entity and not machine.hidden then
                spawnProp(machine)
            end
        end,
        onExit = function()
            machine.inside = false
            removeEntity(machine)
        end,
    })

    if not useTarget then
        machine.textPoint = lib.points.new({
            coords = coords,
            distance = Config.Interaction.distance,
            onEnter = function()
                textMachine = machine
                showText(machine)
            end,
            onExit = function()
                if textMachine ~= machine then return end

                textMachine = nil
                exports['hype-core']:HideTextUI()
            end,
            nearby = function()
                onTextKey(machine)
            end,
        })
    end

    machines[data.id] = machine
end

function GetMachine(machineId)
    return machines[machineId]
end

function SetMachineHidden(machineId, hidden)
    local machine = machines[machineId]
    if not machine then return end

    if hidden then
        machine.hidden = true
        removeEntity(machine)
    else
        local data = machine.data
        removeMachine(machineId)
        setMachine(data)
    end
end

local function loadMachines()
    for machineId in pairs(machines) do
        removeMachine(machineId)
    end

    local response = lib.callback.await("hype-vendingmachine:server:get-machines", false)
    if not response then return end

    identifier = response.identifier
    staffMachines = {}

    for _, machineId in ipairs(response.staff) do
        staffMachines[machineId] = true
    end

    for _, data in ipairs(response.machines) do
        setMachine(data)
    end
end

RegisterNetEvent("hype-vendingmachine:client:set-machine", setMachine)
RegisterNetEvent("hype-vendingmachine:client:remove-machine", removeMachine)

RegisterNetEvent("hype-vendingmachine:client:set-stock", function(machineId, stock)
    local machine = machines[machineId]
    if not machine then return end

    machine.stock = stock
    RefreshShelf(machine)
end)

RegisterNetEvent("hype-vendingmachine:client:vend", function(machineId, vendId, buyer, lines, stock)
    local machine = machines[machineId]

    if machine then
        machine.stock = stock
    end

    QueueVend(machine, vendId, buyer, lines)
end)

RegisterNetEvent("hype-vendingmachine:client:set-staff", function(machineId, isStaff)
    staffMachines[machineId] = isStaff or nil

    local machine = machines[machineId]
    if machine and textMachine == machine then
        showText(machine)
    end
end)

for _, view in ipairs({ "vending", "purchase" }) do
    RegisterNuiCallback(view .. ":get-data", function(_, cb)
        cb(viewData[view] and { success = true, data = viewData[view] } or { success = false })
    end)
end

RegisterNuiCallback("checkout", function(data, cb)
    local machineId = currentMachine
    local response = lib.callback.await("hype-vendingmachine:server:checkout", false, machineId, data.items, data.payment)
    cb(response)

    if not response or not response.success then return end

    if IsScreenOpen(machineId) then
        CloseScreen()
    elseif HasShelf(machines[machineId]) then
        CloseUi()
    end
end)

RegisterNuiCallback("purchase:buy", function(_, cb)
    local response = lib.callback.await("hype-vendingmachine:server:buy-machine", false, currentMachine)

    if response and response.success then
        notify(response)
    end

    cb(response)
end)

AddEventHandler("hype-vendingmachine:client:ui-closed", function()
    currentView = nil
end)

AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        loadMachines()
    end
end)

RegisterNetEvent("hype-core:client:player-loaded", loadMachines)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for machineId in pairs(machines) do
        removeMachine(machineId)
    end
end)
