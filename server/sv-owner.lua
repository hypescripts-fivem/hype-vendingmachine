local Config <const> = require 'config.config'

local knownPermissions = {}
for _, permission in ipairs(Config.StaffPermissions) do
    knownPermissions[permission] = true
end

local panelViewers = {}
local schedules = {}
local restocking = {}

local function wholesalePrice(product, multiplier)
    return math.floor(product.wholesale * multiplier + 0.5)
end

local function readPermissions(value)
    local permissions = {}

    for _, permission in ipairs(DecodeJson(value) or {}) do
        if knownPermissions[permission] then
            permissions[#permissions + 1] = permission
        end
    end

    return permissions
end

local function getAccess(playerId, row)
    local identifier = exports['hype-core']:GetPlayerIdentifier(playerId)
    if not identifier or ToBoolean(row.for_sale) then return nil end

    if row.owner == identifier then
        return { owner = true, permissions = {} }, identifier
    end

    local member = MySQL.single.await(Queries.GetStaffMember, { row.id, identifier })
    if not member then return nil end

    local permissions = readPermissions(member.permissions)
    if #permissions == 0 then return nil end

    return { owner = false, permissions = permissions }, identifier, member.id
end

local function can(access, permission)
    return access.owner or lib.table.contains(access.permissions, permission)
end

function SetOrderStatus(orderId, machineId, status)
    MySQL.update.await(Queries.UpdateOrderStatus, { status, orderId })

    for playerId, viewing in pairs(panelViewers) do
        if viewing == machineId then
            TriggerClientEvent("hype-vendingmachine:client:order-status", playerId, machineId, tostring(orderId), status)
        end
    end
end

local function getRevenue(machineId)
    local byDay = {}
    for _, row in ipairs(MySQL.query.await(Queries.GetDailyRevenue, { machineId, Config.Limits.revenueDays - 1 }) or {}) do
        byDay[row.day] = row
    end

    local revenue = {}
    for index, day in ipairs(LastDays(Config.Limits.revenueDays)) do
        local row = byDay[day]
        revenue[index] = {
            date = day,
            revenue = row and tonumber(row.revenue) or 0,
            sales = row and tonumber(row.sales) or 0,
        }
    end

    return revenue
end

local function getTransactions(machineId)
    local transactions = {}

    for index, row in ipairs(MySQL.query.await(Queries.GetTransactions, { machineId, Config.Limits.historyLength }) or {}) do
        transactions[index] = {
            id = tostring(row.id),
            time = row.created_at,
            buyer = row.buyer_name,
            productId = row.item,
            quantity = row.quantity,
            total = row.total,
        }
    end

    return transactions
end

local function getCashMovements(machineId)
    local movements = {}

    for index, row in ipairs(MySQL.query.await(Queries.GetCashMovements, { machineId, Config.Limits.historyLength }) or {}) do
        movements[index] = {
            id = tostring(row.id),
            time = row.created_at,
            type = row.type,
            amount = row.amount,
            by = row.by_name,
        }
    end

    return movements
end

local function getOrders(machineId)
    local orders, byId, ids = {}, {}, {}

    for index, row in ipairs(MySQL.query.await(Queries.GetOrders, { machineId, Config.Limits.historyLength }) or {}) do
        local order = {
            id = tostring(row.id),
            time = row.created_at,
            items = {},
            total = row.total,
            status = row.status,
        }

        orders[index] = order
        byId[row.id] = order
        ids[index] = row.id
    end

    if #ids > 0 then
        for _, row in ipairs(MySQL.query.await(Queries.GetOrderItems, { ids }) or {}) do
            local items = byId[row.order_id].items
            items[#items + 1] = { productId = row.item, quantity = row.quantity }
        end
    end

    return orders
end

local function getStaff(machineId)
    local staff = {}

    for index, row in ipairs(MySQL.query.await(Queries.GetStaff, { machineId }) or {}) do
        staff[index] = {
            id = tostring(row.id),
            name = row.name,
            hiredAt = row.hired_at,
            lastOnline = row.last_online,
            online = exports['hype-core']:GetPlayerSource(row.identifier) ~= nil,
            permissions = readPermissions(row.permissions),
        }
    end

    return staff
end

lib.callback.register("hype-vendingmachine:server:get-owner-data", function(source, machineId)
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err) end

    local access, identifier, memberId = getAccess(playerId, row)
    if not access then return Fail(locale("error_no_permission")) end

    if not access.owner then
        MySQL.update(Queries.UpdateStaffLastOnline, { row.id, identifier })
    end

    local multiplier = GetSettings().wholesaleMultiplier
    local products, sold = GetProducts(row.id)

    local wholesale = {}
    for _, product in ipairs(Config.Products) do
        wholesale[product.id] = wholesalePrice(product, multiplier)
    end

    local data = {
        access = access,
        settings = GetOwnerSettings(row),
        balance = row.balance,
        wallet = can(access, "cash.deposit") and exports['hype-core']:GetPlayerMoney(playerId, Config.CashAccount) or 0,
        capacity = row.capacity,
        products = products,
        wholesale = wholesale,
        revenue = {},
        transactions = {},
        unitsSold = {},
        cashMovements = {},
        orders = {},
        staff = {},
        selfId = access.owner and "owner" or tostring(memberId),
    }

    if can(access, "dashboard.view") then
        data.revenue = getRevenue(row.id)
        data.unitsSold = sold
    end

    if can(access, "transactions.view") then data.transactions = getTransactions(row.id) end
    if can(access, "cash.history") then data.cashMovements = getCashMovements(row.id) end
    if can(access, "restock.order") then data.orders = getOrders(row.id) end

    if can(access, "staff.view") or can(access, "staff.manage") then
        data.staff = getStaff(row.id)
        data.ownerMember = {
            name = row.owner_name or "",
            online = exports['hype-core']:GetPlayerSource(row.owner) ~= nil,
        }
    end

    panelViewers[playerId] = row.id

    return { success = true, data = data }
end)

local function isTime(value)
    local hours, minutes = Trim(value):match("^(%d%d):(%d%d)$")
    return hours ~= nil and tonumber(hours) < 24 and tonumber(minutes) < 60
end

local function toMinutes(value)
    local hours, minutes = value:match("^(%d%d):(%d%d)$")
    return tonumber(hours) * 60 + tonumber(minutes)
end

local function setSchedule(machineId, schedule)
    if type(schedule) == "table" and schedule.enabled and isTime(schedule.opensAt) and isTime(schedule.closesAt) then
        schedules[machineId] = { opensAt = toMinutes(schedule.opensAt), closesAt = toMinutes(schedule.closesAt) }
    else
        schedules[machineId] = nil
    end
end

local function passedBetween(time, from, to)
    local offset = (time - from) % 1440
    return offset > 0 and offset <= (to - from) % 1440
end

local function applySchedules(from, to)
    for machineId, schedule in pairs(schedules) do
        local opensAt, closesAt = schedule.opensAt, schedule.closesAt

        if passedBetween(opensAt, from, to) or passedBetween(closesAt, from, to) then
            local status = (to - opensAt) % 1440 < (closesAt - opensAt) % 1440 and "open" or "closed"

            if MySQL.update.await(Queries.SetScheduledStatus, { status, machineId, status }) > 0 then
                SyncMachine(machineId)
            end
        end
    end
end

local function scheduleLoop()
    local last, warned

    while true do
        Wait(1000)

        local time = exports['hype-core']:GetGameTime()

        if not time then
            if not warned then
                print("^3[WARNING] hype-core has no in-game time, so machine operating hours are not applied^0")
                warned = true
            end

            last = nil
        else
            local now = time.hour * 60 + time.minute

            if last and now ~= last and next(schedules) then
                applySchedules(last, now)
            end

            last = now
        end
    end
end

lib.callback.register("hype-vendingmachine:server:save-owner-settings", function(source, machineId, data)
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err) end

    local access = getAccess(playerId, row)
    if not access then return Fail(locale("error_no_permission")) end

    if type(data) ~= "table" then return Fail(locale("error_invalid_machine")) end

    local settings = GetOwnerSettings(row)

    if can(access, "settings.general") then
        local name, description = Trim(data.name), Trim(data.description)
        local nameLength = utf8.len(name)

        if not nameLength or nameLength < 1 or nameLength > Config.Limits.nameLength then
            return Fail(locale("error_invalid_name", Config.Limits.nameLength))
        end

        if (utf8.len(description) or math.huge) > Config.Limits.descriptionLength then
            return Fail(locale("error_invalid_description", Config.Limits.descriptionLength))
        end

        if data.open == true and row.status == "disabled" then
            return Fail(locale("error_machine_disabled"))
        end

        settings.name = name
        settings.description = description
        settings.open = data.open == true
    end

    if can(access, "settings.hours") and type(data.schedule) == "table" then
        local schedule = data.schedule

        if not isTime(schedule.opensAt) or not isTime(schedule.closesAt) or schedule.opensAt == schedule.closesAt then
            return Fail(locale("error_invalid_schedule"))
        end

        settings.schedule = {
            enabled = schedule.enabled == true,
            opensAt = Trim(schedule.opensAt),
            closesAt = Trim(schedule.closesAt),
        }
    end

    if can(access, "settings.stock") then
        local threshold = math.tointeger(tonumber(data.lowStockThreshold))

        if not threshold or threshold < 0 or threshold > row.capacity then
            return Fail(locale("error_invalid_threshold", row.capacity))
        end

        settings.lowStockThreshold = threshold
        settings.autoRestock = data.autoRestock == true
        settings.notifyLowStock = data.notifyLowStock == true
        settings.notifySales = data.notifySales == true
    end

    if can(access, "settings.payments") and type(data.payments) == "table" then
        local payments = { cash = data.payments.cash == true, bank = data.payments.bank == true }

        if not payments.cash and not payments.bank then
            return Fail(locale("error_invalid_payments"))
        end

        settings.payments = payments
    end

    MySQL.update.await(Queries.UpdateMachineSettings, {
        settings.name,
        settings.description,
        settings.open and "open" or "closed",
        json.encode({
            schedule = settings.schedule,
            lowStockThreshold = settings.lowStockThreshold,
            autoRestock = settings.autoRestock,
            notifyLowStock = settings.notifyLowStock,
            notifySales = settings.notifySales,
            payments = settings.payments,
        }),
        row.id,
    })

    setSchedule(row.id, settings.schedule)

    if settings.name ~= row.name or (settings.open and "open" or "closed") ~= row.status then
        SyncMachine(row.id)
    end

    return { success = true }
end)

local function prepareCashMove(playerId, machineId, amount, permission)
    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return nil, err end

    local access, identifier = getAccess(playerId, row)
    if not access or not can(access, permission) then return nil, locale("error_no_permission") end

    amount = math.tointeger(tonumber(amount))
    if not amount or amount < 1 or amount > Config.Limits.maxCashTransfer then
        return nil, locale("error_invalid_amount", lib.math.groupdigits(Config.Limits.maxCashTransfer))
    end

    return row, amount, identifier
end

lib.callback.register("hype-vendingmachine:server:owner-deposit", function(source, machineId, amount)
    local playerId = source

    local row, result, identifier = prepareCashMove(playerId, machineId, amount, "cash.deposit")
    if not row then return Fail(result) end
    amount = result

    if not exports['hype-core']:RemovePlayerMoney(playerId, Config.CashAccount, amount) then
        return Fail(locale("error_not_enough_money"))
    end

    if MySQL.update.await(Queries.AddBalance, { amount, row.id }) == 0 then
        exports['hype-core']:AddPlayerMoney(playerId, Config.CashAccount, amount)
        return Fail(locale("error_machine_not_found"))
    end

    MySQL.insert(Queries.InsertCashMovement, { row.id, "deposit", amount, identifier, GetPlayerDisplayName(playerId) })

    return {
        success = true,
        data = {
            balance = MySQL.scalar.await(Queries.GetMachineBalance, { row.id }),
            wallet = exports['hype-core']:GetPlayerMoney(playerId, Config.CashAccount),
        }
    }
end)

lib.callback.register("hype-vendingmachine:server:owner-withdraw", function(source, machineId, amount)
    local playerId = source

    local row, result, identifier = prepareCashMove(playerId, machineId, amount, "cash.withdraw")
    if not row then return Fail(result) end
    amount = result

    if MySQL.update.await(Queries.RemoveBalance, { amount, row.id, amount }) == 0 then
        return Fail(locale("error_not_enough_balance"))
    end

    if not exports['hype-core']:AddPlayerMoney(playerId, Config.CashAccount, amount) then
        MySQL.update.await(Queries.AddBalance, { amount, row.id })
        Debug("error", "could not pay player %s their withdrawal of %s from machine %s, balance restored", playerId, amount, row.id)
        return Fail(locale("error_database"))
    end

    MySQL.insert(Queries.InsertCashMovement, { row.id, "withdraw", amount, identifier, GetPlayerDisplayName(playerId) })

    return {
        success = true,
        data = {
            balance = MySQL.scalar.await(Queries.GetMachineBalance, { row.id }),
            wallet = exports['hype-core']:GetPlayerMoney(playerId, Config.CashAccount),
        }
    }
end)

local function advanceOrder(orderId)
    local order = MySQL.single.await(Queries.GetOrder, { orderId })
    if not order or order.status ~= "preparing" then return end

    SetOrderStatus(orderId, order.machine_id, "prepared")
end

local function scheduleOrder(orderId, delay)
    SetTimeout(math.max(math.floor(delay), 0), function()
        advanceOrder(orderId)
    end)
end

local function deliveryDelay()
    return GetSettings().deliveryMinutes * 60000
end

MySQL.ready(function()
    MySQL.update.await(Queries.ResetShippingOrders)

    local delay, now = deliveryDelay(), os.time() * 1000
    for _, order in ipairs(MySQL.query.await(Queries.GetPendingOrders) or {}) do
        local elapsed = type(order.updated_at) == "number" and now - order.updated_at or 0
        scheduleOrder(order.id, delay - elapsed)
    end

    for _, row in ipairs(MySQL.query.await(Queries.GetScheduledMachines) or {}) do
        setSchedule(row.id, GetOwnerSettings(row).schedule)
    end

    CreateThread(scheduleLoop)
end)

local function placeOrder(row, lines, total, orderedBy, byName)
    if MySQL.update.await(Queries.RemoveBalance, { total, row.id, total }) == 0 then
        return nil, locale("error_not_enough_balance")
    end

    local orderId = MySQL.insert.await(Queries.InsertOrder, { row.id, total, orderedBy })

    if not orderId then
        MySQL.update.await(Queries.AddBalance, { total, row.id })
        Debug("error", "could not insert the stock order for machine %s, balance restored", row.id)
        return nil, locale("error_database")
    end

    local values = {}
    for index, line in ipairs(lines) do
        values[index] = { orderId, line.item, line.quantity, line.unitPrice }
    end

    MySQL.prepare.await(Queries.InsertOrderItem, values)
    MySQL.insert(Queries.InsertCashMovement, { row.id, "order", total, orderedBy, byName })

    scheduleOrder(orderId, deliveryDelay())

    return orderId
end

local function getIncomingStock(machineId)
    local incoming = {}
    for _, line in ipairs(MySQL.query.await(Queries.GetIncomingStock, { machineId }) or {}) do
        incoming[line.item] = tonumber(line.quantity) or 0
    end

    return incoming
end

function AutoRestock(row)
    if not row.owner or restocking[row.id] then return end

    local settings = GetOwnerSettings(row)
    if not settings.autoRestock then return end

    restocking[row.id] = true

    local incoming = getIncomingStock(row.id)
    local multiplier = GetSettings().wholesaleMultiplier
    local lines, total = {}, 0

    for _, product in ipairs(MySQL.query.await(Queries.GetMachineProducts, { row.id }) or {}) do
        local catalog = ProductsById[product.item]

        if catalog and not incoming[product.item] and product.stock <= settings.lowStockThreshold and product.stock < row.capacity then
            local quantity = math.min(row.capacity - product.stock, Config.Limits.maxOrderQuantity)
            local unitPrice = wholesalePrice(catalog, multiplier)

            lines[#lines + 1] = { item = product.item, quantity = quantity, unitPrice = unitPrice }
            total = total + unitPrice * quantity
        end
    end

    if #lines > 0 then
        local orderId, err = placeOrder(row, lines, total, row.owner, locale("auto_restock"))

        if not orderId then
            Debug("warning", "auto restock of machine %s failed: %s", row.id, err)
        end
    end

    restocking[row.id] = nil
end

lib.callback.register("hype-vendingmachine:server:owner-order-stock", function(source, machineId, items)
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err) end

    local access, identifier = getAccess(playerId, row)
    if not access or not can(access, "restock.order") then return Fail(locale("error_no_permission")) end

    local requested, itemsError = ReadItems(items, "productId", Config.Limits.maxOrderQuantity)
    if not requested then return Fail(itemsError) end

    local stock = {}
    for _, product in ipairs(MySQL.query.await(Queries.GetMachineProducts, { row.id }) or {}) do
        stock[product.item] = product.stock
    end

    local incoming = getIncomingStock(row.id)
    local multiplier = GetSettings().wholesaleMultiplier
    local lines, total = {}, 0

    for item, quantity in pairs(requested) do
        local catalog = ProductsById[item]
        if not stock[item] or not catalog then return Fail(locale("error_invalid_products")) end

        if stock[item] + (incoming[item] or 0) + quantity > row.capacity then
            return Fail(locale("error_over_capacity", catalog.name, row.capacity))
        end

        local unitPrice = wholesalePrice(catalog, multiplier)
        lines[#lines + 1] = { item = item, quantity = quantity, unitPrice = unitPrice }
        total = total + unitPrice * quantity
    end

    local orderId, orderError = placeOrder(row, lines, total, identifier, GetPlayerDisplayName(playerId))
    if not orderId then return Fail(orderError) end

    return {
        success = true,
        data = {
            balance = MySQL.scalar.await(Queries.GetMachineBalance, { row.id }),
            orderId = tostring(orderId),
        }
    }
end)

lib.callback.register("hype-vendingmachine:server:owner-pickup-order", function(source, machineId, orderId)
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err) end

    local access = getAccess(playerId, row)
    if not access or not can(access, "restock.order") then return Fail(locale("error_no_permission")) end

    return StartCargo(playerId, row, math.tointeger(tonumber(orderId)))
end)

lib.callback.register("hype-vendingmachine:server:owner-update-price", function(source, machineId, data)
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err) end

    local access = getAccess(playerId, row)
    if not access or not can(access, "products.prices") then return Fail(locale("error_no_permission")) end

    if type(data) ~= "table" then return Fail(locale("error_invalid_products")) end

    local price = math.tointeger(tonumber(data.price))
    if not price or price < 0 or price > Config.Limits.maxPrice then
        return Fail(locale("error_invalid_price", Config.Limits.maxPrice))
    end

    if type(data.id) ~= "string" or MySQL.update.await(Queries.UpdateProductPrice, { price, row.id, data.id }) == 0 then
        return Fail(locale("error_invalid_products"))
    end

    return { success = true }
end)

local function readGrant(access, requested)
    if type(requested) ~= "table" then return nil end

    local permissions = {}
    for _, permission in ipairs(Config.StaffPermissions) do
        if lib.table.contains(requested, permission) then
            if not can(access, permission) then return nil end
            permissions[#permissions + 1] = permission
        end
    end

    return #permissions > 0 and permissions or nil
end

local function canManageMember(access, permissions)
    for _, permission in ipairs(permissions) do
        if not can(access, permission) then return false end
    end

    return true
end

local function prepareStaffAction(playerId, machineId)
    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return nil, err end

    local access = getAccess(playerId, row)
    if not access or not can(access, "staff.manage") then return nil, locale("error_no_permission") end

    return row, access
end

lib.callback.register("hype-vendingmachine:server:owner-hire-staff", function(source, machineId, data)
    local playerId = source

    local row, access = prepareStaffAction(playerId, machineId)
    if not row then return Fail(access) end

    if type(data) ~= "table" then return Fail(locale("error_player_not_found")) end

    local permissions = readGrant(access, data.permissions)
    if not permissions then return Fail(locale("error_invalid_permissions")) end

    local targetId = math.tointeger(tonumber(data.playerId))
    if not targetId or not exports['hype-core']:IsPlayerOnline(targetId)
        or not exports['hype-core']:IsPlayerNearCoords(targetId, vector3(row.x, row.y, row.z), Config.Interaction.maxDistance) then
        return Fail(locale("error_player_not_found"))
    end

    local identifier = exports['hype-core']:GetPlayerIdentifier(targetId)
    if not identifier then return Fail(locale("error_player_not_found")) end

    if identifier == row.owner or MySQL.single.await(Queries.GetStaffMember, { row.id, identifier }) then
        return Fail(locale("error_already_staff"))
    end

    local name = GetPlayerDisplayName(targetId)
    local memberId = MySQL.insert.await(Queries.InsertStaff, { row.id, identifier, name, json.encode(permissions) })
    if not memberId then return Fail(locale("error_database")) end

    TriggerClientEvent("hype-vendingmachine:client:set-staff", targetId, row.id, true)
    Notify(targetId, locale("notify_hired", row.name))

    return {
        success = true,
        data = {
            member = {
                id = tostring(memberId),
                name = name,
                hiredAt = os.time() * 1000,
                online = true,
                permissions = permissions,
            },
        }
    }
end)

lib.callback.register("hype-vendingmachine:server:owner-update-staff", function(source, machineId, data)
    local playerId = source

    local row, access = prepareStaffAction(playerId, machineId)
    if not row then return Fail(access) end

    local member = type(data) == "table" and MySQL.single.await(Queries.GetStaffMemberById, { tonumber(data.id), row.id })
    if not member then return Fail(locale("error_staff_not_found")) end

    if not canManageMember(access, readPermissions(member.permissions)) then return Fail(locale("error_no_permission")) end

    local permissions = readGrant(access, data.permissions)
    if not permissions then return Fail(locale("error_invalid_permissions")) end

    MySQL.update.await(Queries.UpdateStaffPermissions, { json.encode(permissions), member.id, row.id })

    return { success = true }
end)

local function sendStaffRemoved(identifier, row)
    local memberSource = exports['hype-core']:GetPlayerSource(identifier)
    if not memberSource then return end

    TriggerClientEvent("hype-vendingmachine:client:set-staff", memberSource, row.id, false)
    Notify(memberSource, locale("notify_staff_removed", row.name), "info")
end

lib.callback.register("hype-vendingmachine:server:owner-fire-staff", function(source, machineId, data)
    local playerId = source

    local row, access = prepareStaffAction(playerId, machineId)
    if not row then return Fail(access) end

    local member = type(data) == "table" and MySQL.single.await(Queries.GetStaffMemberById, { tonumber(data.id), row.id })
    if not member then return Fail(locale("error_staff_not_found")) end

    if not canManageMember(access, readPermissions(member.permissions)) then return Fail(locale("error_no_permission")) end

    MySQL.update.await(Queries.DeleteStaff, { member.id, row.id })
    sendStaffRemoved(member.identifier, row)

    return { success = true }
end)

local function prepareOwnerAction(playerId, machineId)
    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return nil, err end

    local access, identifier = getAccess(playerId, row)
    if not access or not access.owner then return nil, locale("error_no_permission") end

    return row, identifier
end

local function removeAllStaff(row)
    local members = MySQL.query.await(Queries.GetStaff, { row.id }) or {}
    MySQL.update.await(Queries.DeleteAllStaff, { row.id })

    for _, member in ipairs(members) do
        sendStaffRemoved(member.identifier, row)
    end
end

lib.callback.register("hype-vendingmachine:server:owner-transfer", function(source, machineId, data)
    local playerId = source

    local row, identifier = prepareOwnerAction(playerId, machineId)
    if not row then return Fail(identifier) end

    local targetId = type(data) == "table" and math.tointeger(tonumber(data.playerId))
    local targetIdentifier = targetId and exports['hype-core']:IsPlayerOnline(targetId) and exports['hype-core']:GetPlayerIdentifier(targetId)
    if not targetIdentifier then return Fail(locale("error_player_not_found")) end

    if targetIdentifier == identifier then return Fail(locale("error_transfer_self")) end

    local maxMachines = GetSettings().maxMachinesPerPlayer
    if (MySQL.scalar.await(Queries.CountMachinesByOwner, { targetIdentifier }) or 0) >= maxMachines then
        return Fail(locale("error_target_max_machines", maxMachines))
    end

    local targetName = GetPlayerDisplayName(targetId)

    if MySQL.update.await(Queries.TransferMachine, { targetIdentifier, targetName, row.id, identifier }) == 0 then
        return Fail(locale("error_machine_changed"))
    end

    removeAllStaff(row)
    SyncMachine(row.id)

    Debug("success", "player %s transferred machine %s to player %s (%s)", playerId, row.id, targetId, targetIdentifier)

    Notify(playerId, locale("notify_machine_transferred", row.name, targetName))
    Notify(targetId, locale("notify_machine_received", GetPlayerDisplayName(playerId), row.name))

    return { success = true }
end)

lib.callback.register("hype-vendingmachine:server:owner-sell", function(source, machineId)
    local playerId = source

    local row, identifier = prepareOwnerAction(playerId, machineId)
    if not row then return Fail(identifier) end

    local balance = MySQL.scalar.await(Queries.GetMachineBalance, { row.id }) or 0

    if MySQL.update.await(Queries.SellMachine, { row.id, identifier, balance }) == 0 then
        return Fail(locale("error_machine_changed"))
    end

    MySQL.transaction.await({
        { query = Queries.ClampStock, values = { 0, row.id } },
        { query = Queries.DeletePendingOrders, values = { row.id } },
    })

    removeAllStaff(row)

    local payout = math.floor(row.price * Config.SellRefund / 100) + balance
    if payout > 0 then
        exports['hype-core']:AddPlayerMoney(playerId, Config.PurchaseAccount, payout)
    end

    Debug("success", "player %s sold machine %s for %s", playerId, row.id, payout)

    SyncMachine(row.id)
    SyncStock(row)
    Notify(playerId, locale("notify_machine_sold", row.name, lib.math.groupdigits(payout)))

    return { success = true }
end)

AddEventHandler("playerDropped", function()
    panelViewers[source] = nil
end)
