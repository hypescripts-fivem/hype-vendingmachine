RegisterNuiCallback("owner:get-data", function(_, cb)
    local ownerData = GetViewData("owner")
    cb(ownerData and { success = true, data = ownerData } or { success = false })
end)

local function forward(name, callback, read)
    RegisterNuiCallback(name, function(data, cb)
        local payload = data
        if read then payload = read(data) end

        cb(lib.callback.await(callback, false, GetOpenMachine(), payload))
    end)
end

local function amount(data) return data.amount end

forward("owner:save-settings", "hype-vendingmachine:server:save-owner-settings")
forward("owner:update-price", "hype-vendingmachine:server:owner-update-price")
forward("owner:order-stock", "hype-vendingmachine:server:owner-order-stock", function(data) return data.items end)
forward("owner:deposit", "hype-vendingmachine:server:owner-deposit", amount)
forward("owner:withdraw", "hype-vendingmachine:server:owner-withdraw", amount)
forward("owner:hire-staff", "hype-vendingmachine:server:owner-hire-staff")
forward("owner:update-staff", "hype-vendingmachine:server:owner-update-staff")
forward("owner:fire-staff", "hype-vendingmachine:server:owner-fire-staff")
forward("owner:transfer", "hype-vendingmachine:server:owner-transfer")
forward("owner:sell", "hype-vendingmachine:server:owner-sell")

RegisterNetEvent("hype-vendingmachine:client:order-status", function(machineId, orderId, status)
    local openMachine, view = GetOpenMachine()
    if view ~= "owner" or openMachine ~= machineId then return end

    NuiMessage("setOrderStatus", { id = orderId, status = status })
end)
