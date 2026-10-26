local Config <const> = require 'config.config'

local useTarget = Config.Interaction.target and (GetResourceState("ox_target") == "started" or GetResourceState("qb-target") == "started")

--- Props are local objects, spawned only while the player is within Config.Interaction.spawnDistance
--- @type table<integer, MachineEntry>
local machines = {}

-- Who the player is and which machines they work at, sent by the server on load
--- @type string?
local identifier
--- @type table<integer, boolean>
local staffMachines = {}

-- Machine whose menu is open; vending:*, purchase:* and owner:* calls send it to the server
--- @type integer?
local currentMachine
-- Which page is on screen, so live updates (order status) only reach the panel they belong to
--- @type View?
local currentView
-- Checked by the server before a page opens, then handed to the UI by that page's get-data callback
--- @type table<View, table>
local viewData = {}

-- TextUI only: the machine whose hint is on screen
--- @type MachineEntry?
local textMachine
local busy = false

--- @param response CallbackResponse?
local function notify(response)
    if not response then return end

    local message = response.success and response.data and response.data.message or response.error
    if not message then return end

    exports['hype-core']:SendNotify(locale("notify_title"), message, 5000, response.success and "success" or "error")
end

--- The owner and staff get the owner menu
--- @param data MachineProp
--- @return boolean
local function canManage(data)
    return (identifier ~= nil and data.owner == identifier) or staffMachines[data.id] == true
end

--- Asks the server for the page's data first, so a closed machine or missing permission never opens an empty page
--- @param view View
--- @param callback string Server callback that checks the machine and returns the page's data
--- @param data MachineProp
local function openView(view, callback, data)
    local response = lib.callback.await(callback, false, data.id)

    if not response or not response.success then
        Debug("warning", "server refused to open %s for machine %s: %s", view, data.id, response and response.error)
        notify(response)
        return
    end

    Debug("info", "opened %s for machine %s", view, data.id)

    currentMachine = data.id
    currentView = view
    viewData[view] = response.data
    NuiMessage("setView", { view = view })
    SetNuiFocus(true, true)
end

--- The machine whose page is open and which page it is. cl-owner.lua sends the machine with every owner:* call
--- @return integer? machineId
--- @return View? view
function GetOpenMachine()
    return currentMachine, currentView
end

--- What the server sent when a page opened
--- @param view View
--- @return table?
function GetViewData(view)
    return viewData[view]
end

--- @param data MachineProp
local function openPurchase(data)
    openView("purchase", "hype-vendingmachine:server:get-purchase-data", data)
end

--- @param data MachineProp
local function openVending(data)
    openView("vending", "hype-vendingmachine:server:get-vending-data", data)
end

--- @param data MachineProp
local function openOwner(data)
    openView("owner", "hype-vendingmachine:server:get-owner-data", data)
end

--- One request at a time, so a double press doesn't buy twice or open two menus.
--- Runs in its own thread: target callbacks come from another resource and the points loop shouldn't wait on a dialog
--- @param action fun(data: MachineProp)
--- @param data MachineProp
local function run(action, data)
    if busy then
        Debug("info", "ignored input on machine %s, a request is still running", data.id)
        return
    end
    busy = true

    CreateThread(function()
        local ok, err = pcall(action, data)
        busy = false

        if not ok then
            Debug("error", "action on machine %s failed: %s", data.id, err)
            error(err)
        end
    end)
end

--- Options read machine.data when shown, so they follow ownership and sale changes without being re-added
--- @param machine MachineEntry
--- @return table[]
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

--- @param machine MachineEntry
local function showText(machine)
    local data, keys = machine.data, Config.Interaction.keys
    local lines

    -- cl-cargo.lua shows "put the box in" here
    if IsCarryingCargo() then return end

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

--- @param machine MachineEntry
local function onTextKey(machine)
    local data, keys = machine.data, Config.Interaction.keys
    if IsCarryingCargo() then return end

    if IsControlJustReleased(0, keys.primary.control) then
        if data.forSale then
            if data.status ~= "disabled" then run(openPurchase, data) end
        else
            run(openVending, data)
        end
    elseif IsControlJustReleased(0, keys.secondary.control) and not data.forSale and canManage(data) then
        run(openOwner, data)
    end
end

--- @param machine MachineEntry
local function removeEntity(machine)
    if not machine.entity then return end

    if useTarget then
        exports['hype-core']:RemoveLocalEntity(machine.entity)
    end

    exports['hype-core']:RemoveEntity(machine.entity)
    machine.entity = nil

    Debug("info", "removed the prop of machine %s", machine.data.id)
end

--- @param machineId integer
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
    Debug("info", "removed machine %s", machineId)
end

--- @param data MachineProp
local function setMachine(data)
    local current = machines[data.id]

    -- Same prop in the same place: only the sale, owner or status changed
    if current and current.data.model == data.model and current.data.x == data.x and current.data.y == data.y
        and current.data.z == data.z and current.data.heading == data.heading then
        current.data = data
        Debug("info", "updated machine %s (status: %s, for sale: %s)", data.id, data.status, data.forSale)

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
            if machine.entity then return end

            local entity = exports['hype-core']:CreateLocalProp(data.model, vec4(data.x, data.y, data.z, data.heading))
            if not entity then
                Debug("error", "could not spawn %s for machine %s", data.model, data.id)
                return
            end

            -- The machine was moved, removed or left behind while the model loaded
            if machines[data.id] ~= machine or not machine.inside then
                exports['hype-core']:RemoveEntity(entity)
                Debug("info", "dropped the prop of machine %s, it changed while loading", data.id)
                return
            end

            -- The saved position is the admin's, about a metre above the ground
            PlaceObjectOnGroundProperly(entity)
            machine.entity = entity
            Debug("info", "spawned the prop of machine %s", data.id)

            if useTarget then
                exports['hype-core']:AddLocalEntity(entity, targetOptions(machine))
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
    Debug("info", "added machine %s (%s)", data.id, data.model)
end

--- Drops every prop and loads the machines again from the server
local function loadMachines()
    for machineId in pairs(machines) do
        removeMachine(machineId)
    end

    local response = lib.callback.await("hype-vendingmachine:server:get-machines", false)
    if not response then
        Debug("error", "could not load the machines from the server")
        return
    end

    identifier = response.identifier
    staffMachines = {}

    for _, machineId in ipairs(response.staff or {}) do
        staffMachines[machineId] = true
    end

    for _, data in ipairs(response.machines or {}) do
        setMachine(data)
    end

    Debug("success", "loaded %d machine(s), staff at %d", #(response.machines or {}), #(response.staff or {}))
end

RegisterNetEvent("hype-vendingmachine:client:set-machine", setMachine)
RegisterNetEvent("hype-vendingmachine:client:remove-machine", removeMachine)

for _, view in ipairs({ "vending", "purchase" }) do
    RegisterNuiCallback(view .. ":get-data", function(data, cb)
        cb(viewData[view] and { success = true, data = viewData[view] } or { success = false })
    end)
end

RegisterNuiCallback("checkout", function(data, cb)
    Debug("info", "checkout on machine %s with %s", currentMachine, data.payment)
    cb(lib.callback.await("hype-vendingmachine:server:checkout", false, currentMachine, data.items, data.payment))
end)

AddEventHandler("hype-vendingmachine:client:ui-closed", function()
    currentView = nil
end)

-- Sent when this player is hired or fired, so "Manage machine" shows up or goes away without a relog
RegisterNetEvent("hype-vendingmachine:client:set-staff", function(machineId, isStaff)
    staffMachines[machineId] = isStaff or nil
    Debug("info", "staff access for machine %s: %s", machineId, isStaff)

    local machine = machines[machineId]
    if machine and textMachine == machine then
        showText(machine)
    end
end)

-- On success the UI closes itself, so the result is also shown as a notification
RegisterNuiCallback("purchase:buy", function(data, cb)
    Debug("info", "buying machine %s", currentMachine)
    local response = lib.callback.await("hype-vendingmachine:server:buy-machine", false, currentMachine)

    if response and response.success then
        notify(response)
    end

    cb(response)
end)

AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        loadMachines()
    end
end)

RegisterNetEvent("hype-core:client:player-loaded", function()
    loadMachines()
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for machineId in pairs(machines) do
        removeMachine(machineId)
    end
end)
