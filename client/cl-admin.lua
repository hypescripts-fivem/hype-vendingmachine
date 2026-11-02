RegisterNetEvent("hype-vendingmachine:client:open-admin-menu", function()
    -- Opening the menu again would reload it and lose the form whose machine is being placed
    if IsPlacing() then return end

    Debug("info", "opening the admin menu")
    NuiMessage("setView", {
        view = "admin"
    })
    SetNuiFocus(true, true)
end)

RegisterNuiCallback("admin:get-data", function(data, cb)
    local response = lib.callback.await("hype-vendingmachine:server:get-admin-data", false)

    -- Custom (arm) machines need olentrix_vending; without it the panel doesn't offer them
    if response and response.success and response.data then
        response.data.customMachines = GetResourceState("olentrix_vending") == "started"
    end

    cb(response)
end)

RegisterNuiCallback("admin:create-machine", function(data, cb)
    cb(lib.callback.await("hype-vendingmachine:server:create-machine", false, data))
end)

RegisterNuiCallback("admin:update-machine", function(data, cb)
    cb(lib.callback.await("hype-vendingmachine:server:update-machine", false, data))
end)

RegisterNuiCallback("admin:delete-machine", function(data, cb)
    cb(lib.callback.await("hype-vendingmachine:server:delete-machine", false, data))
end)

RegisterNuiCallback("admin:import-machine", function(data, cb)
    cb(lib.callback.await("hype-vendingmachine:server:import-machines", false, data))
end)

RegisterNuiCallback("admin:set-status", function(data, cb)
    cb(lib.callback.await("hype-vendingmachine:server:set-machine-status", false, data))
end)

RegisterNuiCallback("admin:reset-balance", function(data, cb)
    cb(lib.callback.await("hype-vendingmachine:server:reset-machine-balance", false, data))
end)

RegisterNuiCallback("admin:save-settings", function(data, cb)
    cb(lib.callback.await("hype-vendingmachine:server:save-admin-settings", false, data))
end)

-- Puts the admin in front of the machine, facing it, instead of inside the prop
RegisterNuiCallback("admin:teleport", function(data, cb)
    local response = lib.callback.await("hype-vendingmachine:server:get-machine-position", false, data)

    if not response or not response.success then
        Debug("warning", "teleport to machine %s refused: %s", data.id, response and response.error)
        cb(response)
        return
    end

    local position = response.data
    local heading = math.rad(position.heading)
    local x = position.x - math.sin(heading) * 1.2
    local y = position.y + math.cos(heading) * 1.2
    local ped = PlayerPedId()

    -- Held in place until the ground loads, so a long teleport doesn't drop through the map
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(x, y, position.z)
    SetEntityCoords(ped, x, y, position.z, false, false, false, false)
    SetEntityHeading(ped, (position.heading + 180.0) % 360.0)

    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end

    FreezeEntityPosition(ped, false)
    Debug("success", "teleported to machine %s (collision loaded: %s)", data.id, HasCollisionLoadedAroundEntity(ped))
    cb({ success = true })
end)
