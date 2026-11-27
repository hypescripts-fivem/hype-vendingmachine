local Config <const> = require 'config.config'
local AdminMenu <const> = Config.Commands.AdminMenu

local machineModels = {}
for _, machine in ipairs(Config.Machines) do
    machineModels[machine.value] = true
end

local settingRanges <const> = {
    wholesaleMultiplier = { min = 0.5, max = 2 },
    salesTax = { min = 0, max = 30, integer = true },
    maxMachinesPerPlayer = { min = 1, max = 100, integer = true },
    deliveryMinutes = { min = 1, max = 30, integer = true },
    defaultCapacity = { min = 1, max = Config.Limits.maxCapacity, integer = true },
    defaultPrice = { min = 0, max = Config.Limits.maxMachinePrice, integer = true },
}

lib.addCommand(AdminMenu.name, {
    help = AdminMenu.help,
    restricted = AdminMenu.permission,
}, function(source)
    if source == 0 or not IsAdmin(source) then return end

    TriggerClientEvent('hype-vendingmachine:client:open-admin-menu', source)
end)

local function isAdmin(playerId)
    return IsAdmin(playerId)
end

local function toInteger(value, min, max)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < min or value > max then return nil end
    return math.tointeger(value)
end

local function round(value)
    return math.floor(value * 100 + 0.5) / 100
end

local function validateMachine(data)
    if type(data) ~= "table" then return nil, locale("error_invalid_machine") end

    local name = Trim(data.name)
    local nameLength = utf8.len(name)
    if not nameLength or nameLength < 1 or nameLength > Config.Limits.nameLength then
        return nil, locale("error_invalid_name", Config.Limits.nameLength)
    end

    if not machineModels[data.model] then return nil, locale("error_invalid_model") end

    local location = type(data.location) == "table" and data.location or {}
    local x, y, z = tonumber(location.x), tonumber(location.y), tonumber(location.z)
    if not x or not y or not z or (x == 0 and y == 0 and z == 0) then
        return nil, locale("error_invalid_location")
    end

    local price = toInteger(data.price, 0, Config.Limits.maxMachinePrice)
    if not price then return nil, locale("error_invalid_price", Config.Limits.maxMachinePrice) end

    local capacity = toInteger(data.capacity, 1, Config.Limits.maxCapacity)
    if not capacity then return nil, locale("error_invalid_capacity", Config.Limits.maxCapacity) end

    local products, seen = {}, {}
    for _, item in ipairs(type(data.products) == "table" and data.products or {}) do
        if not ProductsById[item] then return nil, locale("error_invalid_products") end

        if not seen[item] then
            seen[item] = true
            products[#products + 1] = item
        end
    end
    if #products == 0 then return nil, locale("error_invalid_products") end

    local ownerId = Trim(data.ownerId)
    local forSale = data.forSale == true or ownerId == ""

    return {
        name = name,
        model = data.model,
        location = {
            label = Trim(location.label):sub(1, 64),
            x = x,
            y = y,
            z = z,
            heading = tonumber(location.heading) or 0.0,
        },
        ownerId = forSale and "" or ownerId,
        forSale = forSale,
        price = price,
        capacity = capacity,
        products = products,
    }
end

local function resolveOwner(ownerId)
    local playerId = tonumber(ownerId)

    if not playerId or not IsPlayerOnline(playerId) then
        playerId = Framework.Server.GetPlayerSource(ownerId)
    end

    if not playerId then return nil end

    local identifier = Framework.Server.GetPlayerIdentifier(playerId)
    if not identifier then return nil end

    return identifier, GetPlayerDisplayName(playerId)
end

local function nextColorSlot()
    local used = {}
    for _, row in ipairs(MySQL.query.await(Queries.GetColorSlotUsage) or {}) do
        used[row.color_slot] = row.count
    end

    local slot, least = 0, math.huge
    for index = 0, Config.Limits.colorSlots - 1 do
        local count = used[index] or 0

        if count < least then
            slot, least = index, count
        end
    end

    return slot
end

local function formatMachine(row, products, totals)
    local items, fill = {}, 0

    for index, product in ipairs(products) do
        items[index] = product.item
        fill = fill + math.min(product.stock, row.capacity) / row.capacity
    end

    return {
        id = tostring(row.id),
        colorSlot = row.color_slot,
        name = row.name,
        model = row.model,
        location = {
            label = row.area,
            x = round(row.x),
            y = round(row.y),
            z = round(row.z),
            heading = round(row.heading),
        },
        ownerId = row.owner or "",
        ownerName = row.owner_name,
        forSale = ToBoolean(row.for_sale),
        price = row.price,
        capacity = row.capacity,
        products = items,
        status = row.status,
        balance = row.balance,
        revenue = totals and tonumber(totals.revenue) or 0,
        sales = totals and tonumber(totals.sales) or 0,
        stockLevel = #products > 0 and math.floor(fill / #products * 100 + 0.5) or 0,
        createdAt = row.created_at,
    }
end

local function logAdmin(playerId, key, ...)
    SendWebhookLog("logAdminActions", locale("log_title_admin"), locale(key, FormatPlayerForLog(playerId), ...))
end

local function findMachine(data)
    local machineId = toInteger(type(data) == "table" and data.id, 1, math.maxinteger)
    return machineId and MySQL.single.await(Queries.GetMachine, { machineId })
end

local function isTooClose(location, skipId)
    return MySQL.scalar.await(Queries.GetMachineNearPosition, { skipId or 0, location.x, location.y, location.z, Config.Limits.machineSpacing }) ~= nil
end

local function insertMachine(machine)
    local location = machine.location

    local machineId = MySQL.insert.await(Queries.InsertMachine, {
        machine.name,
        machine.model,
        location.label,
        location.x,
        location.y,
        location.z,
        location.heading,
        machine.price,
        machine.capacity,
        nextColorSlot(),
        json.encode(Config.DefaultOwnerSettings),
    })

    if not machineId then return nil end

    local products = {}
    for index, item in ipairs(machine.products) do
        products[index] = { machineId, item, ProductsById[item].price }
    end

    MySQL.prepare.await(Queries.InsertProduct, products)

    return machineId
end

lib.callback.register('hype-vendingmachine:server:get-admin-data', function(source)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    local productsByMachine = {}
    for _, row in ipairs(MySQL.query.await(Queries.GetAllProducts) or {}) do
        local list = productsByMachine[row.machine_id] or {}
        list[#list + 1] = row
        productsByMachine[row.machine_id] = list
    end

    local totalsByMachine = {}
    for _, row in ipairs(MySQL.query.await(Queries.GetMachineRevenue) or {}) do
        totalsByMachine[row.machine_id] = row
    end

    local machines = {}
    for index, row in ipairs(MySQL.query.await(Queries.GetMachines) or {}) do
        machines[index] = formatMachine(row, productsByMachine[row.id] or {}, totalsByMachine[row.id])
    end

    local revenueByDay = {}
    for _, row in ipairs(MySQL.query.await(Queries.GetTotalDailyRevenue, { Config.Limits.revenueDays - 1 }) or {}) do
        revenueByDay[row.day] = tonumber(row.revenue) or 0
    end

    local revenue = {}
    for index, day in ipairs(LastDays(Config.Limits.revenueDays)) do
        revenue[index] = { date = day, revenue = revenueByDay[day] or 0 }
    end

    return {
        success = true,
        data = {
            machines = machines,
            revenue = revenue,
            settings = GetSettings(),
            products = Config.Products,
        }
    }
end)

lib.callback.register('hype-vendingmachine:server:create-machine', function(source, data)
    local playerId = source
    if not isAdmin(playerId) then return Fail(locale("error_no_permission")) end

    local machine, err = validateMachine(data)
    if not machine then return Fail(err) end

    local owner, ownerName
    if not machine.forSale then
        owner, ownerName = resolveOwner(machine.ownerId)
        if not owner then return Fail(locale("error_owner_not_found")) end
    end

    if isTooClose(machine.location) then return Fail(locale("error_machine_too_close")) end

    local machineId = insertMachine(machine)
    if not machineId then return Fail(locale("error_database")) end

    if owner then
        MySQL.update.await(Queries.SetMachineOwner, { owner, ownerName, machineId })
    end

    SyncMachine(machineId)
    logAdmin(playerId, "log_machine_created", machine.name, machineId)

    return {
        success = true,
        data = {
            id = tostring(machineId),
            ownerName = ownerName,
        }
    }
end)

lib.callback.register('hype-vendingmachine:server:update-machine', function(source, data)
    local playerId = source
    if not isAdmin(playerId) then return Fail(locale("error_no_permission")) end

    local row = findMachine(data)
    if not row then return Fail(locale("error_machine_not_found")) end

    local machineId = row.id
    local machine, err = validateMachine(data)
    if not machine then return Fail(err) end

    local owner, ownerName
    if not machine.forSale then
        if machine.ownerId == row.owner then
            owner, ownerName = row.owner, row.owner_name
        else
            owner, ownerName = resolveOwner(machine.ownerId)
            if not owner then return Fail(locale("error_owner_not_found")) end
        end
    end

    local location = machine.location

    local moved = math.abs(row.x - location.x) > 0.01 or math.abs(row.y - location.y) > 0.01
        or math.abs(row.z - location.z) > 0.01 or math.abs(row.heading - location.heading) > 0.01

    if not moved then
        location.x, location.y, location.z, location.heading = row.x, row.y, row.z, row.heading
    end

    if isTooClose(location, machineId) then return Fail(locale("error_machine_too_close")) end

    local queries = {
        {
            query = Queries.UpdateMachine,
            values = {
                machine.name,
                machine.model,
                location.label,
                location.x,
                location.y,
                location.z,
                location.heading,
                machine.price,
                machine.capacity,
                machineId,
            }
        },
        { query = Queries.DeleteRemovedProducts, values = { machineId, machine.products } },
        { query = Queries.ClampStock, values = { machine.capacity, machineId } },
    }

    for _, item in ipairs(machine.products) do
        queries[#queries + 1] = { query = Queries.InsertProduct, values = { machineId, item, ProductsById[item].price } }
    end

    if owner ~= row.owner then
        if owner then
            queries[#queries + 1] = { query = Queries.SetMachineOwner, values = { owner, ownerName, machineId } }
        else
            queries[#queries + 1] = { query = Queries.SetMachineForSale, values = { machineId } }
        end

        queries[#queries + 1] = { query = Queries.DeleteAllStaff, values = { machineId } }
    end

    if not MySQL.transaction.await(queries) then
        Debug("error", "transaction failed while updating machine %s", machineId)
        return Fail(locale("error_database"))
    end

    SyncMachine(machineId)
    SyncStock({ id = machineId, model = machine.model, x = location.x, y = location.y, z = location.z })
    logAdmin(playerId, "log_machine_updated", machine.name, machineId)

    return {
        success = true,
        data = {
            ownerName = ownerName,
        }
    }
end)

lib.callback.register('hype-vendingmachine:server:delete-machine', function(source, data)
    local playerId = source
    if not isAdmin(playerId) then return Fail(locale("error_no_permission")) end

    local row = findMachine(data)
    if not row then return Fail(locale("error_machine_not_found")) end

    if MySQL.update.await(Queries.DeleteMachine, { row.id }) == 0 then
        return Fail(locale("error_machine_not_found"))
    end

    RemoveMachine(row.id)
    logAdmin(playerId, "log_machine_deleted", row.name, row.id)

    return { success = true }
end)

lib.callback.register('hype-vendingmachine:server:import-machines', function(source, data)
    local playerId = source
    if not isAdmin(playerId) then return Fail(locale("error_no_permission")) end

    local entries = type(data) == "table" and data.machines
    if type(entries) ~= "table" or #entries == 0 then
        return Fail(locale("error_import_empty"))
    end

    if #entries > Config.Limits.maxImport then
        return Fail(locale("error_import_too_many", Config.Limits.maxImport))
    end

    local machines = {}
    for index, entry in ipairs(entries) do
        if type(entry) == "table" then
            entry.ownerId = ""
            entry.forSale = true
        end

        local machine, err = validateMachine(entry)
        if not machine then return Fail(locale("error_import_entry", index, err)) end

        local location = machine.location
        if isTooClose(location) then
            return Fail(locale("error_import_entry", index, locale("error_machine_too_close")))
        end

        local coords = vector3(location.x, location.y, location.z)
        for _, other in ipairs(machines) do
            if #(coords - vector3(other.location.x, other.location.y, other.location.z)) < Config.Limits.machineSpacing then
                return Fail(locale("error_import_entry", index, locale("error_import_duplicate")))
            end
        end

        machines[index] = machine
    end

    local ids = {}
    for index, machine in ipairs(machines) do
        local machineId = insertMachine(machine)

        if not machineId then
            for _, savedId in ipairs(ids) do
                MySQL.update.await(Queries.DeleteMachine, { savedId })
            end

            Debug("error", "import failed at entry %d, rolled back %d machine(s)", index, #ids)
            return Fail(locale("error_database"))
        end

        ids[index] = machineId
    end

    local stringIds = {}
    for index, machineId in ipairs(ids) do
        SyncMachine(machineId)
        stringIds[index] = tostring(machineId)
    end

    logAdmin(playerId, "log_machines_imported", #ids)

    return {
        success = true,
        data = {
            ids = stringIds,
        }
    }
end)

lib.callback.register('hype-vendingmachine:server:set-machine-status', function(source, data)
    local playerId = source
    if not isAdmin(playerId) then return Fail(locale("error_no_permission")) end

    local row = findMachine(data)
    if not row then return Fail(locale("error_machine_not_found")) end

    local status = data.status
    if status ~= "disabled" and status ~= "closed" then
        return Fail(locale("error_invalid_status"))
    end

    MySQL.update.await(Queries.SetMachineStatus, { status, row.id })

    SyncMachine(row.id)
    logAdmin(playerId, "log_machine_status", row.name, row.id, status)

    return { success = true }
end)

lib.callback.register('hype-vendingmachine:server:reset-machine-balance', function(source, data)
    local playerId = source
    if not isAdmin(playerId) then return Fail(locale("error_no_permission")) end

    local row = findMachine(data)
    if not row then return Fail(locale("error_machine_not_found")) end

    MySQL.update.await(Queries.ResetBalance, { row.id })
    logAdmin(playerId, "log_balance_reset", row.name, row.id, lib.math.groupdigits(row.balance))

    return { success = true }
end)

local function readSetting(key, value)
    local default = Config.DefaultSettings[key]

    if type(default) == "boolean" then
        if type(value) ~= "boolean" then return nil end
        return value
    end

    if type(default) == "number" then
        local range = settingRanges[key]
        value = tonumber(value)
        if not value or (range and (value < range.min or value > range.max)) then return nil end

        return range and range.integer and math.floor(value + 0.5) or math.floor(value * 100 + 0.5) / 100
    end
end

lib.callback.register('hype-vendingmachine:server:save-admin-settings', function(source, data)
    local playerId = source
    if not isAdmin(playerId) then return Fail(locale("error_no_permission")) end

    if type(data) ~= "table" then return Fail(locale("error_invalid_settings", "?")) end

    local values, queries = {}, {}
    for key in pairs(Config.DefaultSettings) do
        local value = readSetting(key, data[key])
        if value == nil then return Fail(locale("error_invalid_settings", key)) end

        values[key] = value
        queries[#queries + 1] = { query = Queries.SaveSetting, values = { key, json.encode(value) } }
    end

    if not MySQL.transaction.await(queries) then
        Debug("error", "transaction failed while saving the admin settings")
        return Fail(locale("error_database"))
    end

    SetSettings(values)
    logAdmin(playerId, "log_settings_saved")

    return { success = true }
end)

lib.callback.register('hype-vendingmachine:server:get-machine-position', function(source, data)
    if not isAdmin(source) then return Fail(locale("error_no_permission")) end

    local row = findMachine(data)
    if not row then return Fail(locale("error_machine_not_found")) end

    return {
        success = true,
        data = {
            x = row.x,
            y = row.y,
            z = row.z,
            heading = row.heading,
        }
    }
end)
