RegisterNuiCallback("owner:get-data", function(data, cb)
    local ownerData = GetViewData("owner")
    cb(ownerData and { success = true, data = ownerData } or { success = false })
end)

--- Registers an owner:* NUI callback that hands the request to its server callback, along with the open machine
--- @param name string NUI callback name
--- @param callback string Server callback name
--- @param read? fun(data: table): any Picks what to send from the NUI payload; the whole payload when omitted
local function forward(name, callback, read)
    RegisterNuiCallback(name, function(data, cb)
        local machineId = GetOpenMachine()
        local payload = data

        if read then
            payload = read(data)
        end

        Debug("info", "%s on machine %s", name, machineId)
        local response = lib.callback.await(callback, false, machineId, payload)

        if not response or not response.success then
            Debug("warning", "%s on machine %s failed: %s", name, machineId, response and response.error)
        end

        cb(response)
    end)
end

forward("owner:save-settings", "hype-vendingmachine:server:save-owner-settings")
forward("owner:update-price", "hype-vendingmachine:server:owner-update-price")
forward("owner:order-stock", "hype-vendingmachine:server:owner-order-stock", function(data) return data.items end)
forward("owner:deposit", "hype-vendingmachine:server:owner-deposit", function(data) return data.amount end)
forward("owner:withdraw", "hype-vendingmachine:server:owner-withdraw", function(data) return data.amount end)
forward("owner:hire-staff", "hype-vendingmachine:server:owner-hire-staff")
forward("owner:update-staff", "hype-vendingmachine:server:owner-update-staff")
forward("owner:fire-staff", "hype-vendingmachine:server:owner-fire-staff")
forward("owner:transfer", "hype-vendingmachine:server:owner-transfer")
forward("owner:sell", "hype-vendingmachine:server:owner-sell")

-- Sent to everyone; only the panel open on that machine cares
RegisterNetEvent("hype-vendingmachine:client:order-status", function(machineId, orderId, status)
    local openMachine, view = GetOpenMachine()
    if view ~= "owner" or openMachine ~= machineId then return end

    Debug("info", "order %s of machine %s is now %s", orderId, machineId, status)
    NuiMessage("setOrderStatus", { id = orderId, status = status })
end)
