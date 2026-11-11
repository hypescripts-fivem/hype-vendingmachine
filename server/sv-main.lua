local Config <const> = require 'config.config'

local VEND_SECONDS_PER_UNIT <const> = 15
local VEND_GRACE_SECONDS <const> = 30
local STOCK_SYNC_RANGE <const> = Config.Interaction.spawnDistance + 10.0

ProductsById = {}
for _, product in ipairs(Config.Products) do
    ProductsById[product.id] = product
end

function Fail(message)
    Debug("warning", "request failed: %s", message)
    return { success = false, error = message }
end

function Trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

function ToBoolean(value)
    return value == true or value == 1
end

function DecodeJson(value)
    if type(value) ~= "string" then return value end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or nil
end

local settings

function GetSettings()
    if settings then return settings end

    settings = lib.table.deepclone(Config.DefaultSettings)

    for _, row in ipairs(MySQL.query.await(Queries.GetSettings) or {}) do
        local value = DecodeJson(row.value)
        if value ~= nil and settings[row.key] ~= nil then
            settings[row.key] = value
        end
    end

    return settings
end

function SetSettings(values)
    settings = values
end

function GetOwnerSettings(row)
    local ownerSettings = lib.table.deepclone(Config.DefaultOwnerSettings)
    local stored = DecodeJson(row.settings)

    if type(stored) == "table" then
        for key, value in pairs(stored) do
            if ownerSettings[key] ~= nil then
                ownerSettings[key] = value
            end
        end
    end

    ownerSettings.name = row.name
    ownerSettings.description = row.description
    ownerSettings.open = row.status == "open"

    return ownerSettings
end

function ReadItems(list, idKey, maxQuantity)
    if type(list) ~= "table" then return nil, locale("error_invalid_items") end

    local items, count = {}, 0

    for _, entry in ipairs(list) do
        local item = type(entry) == "table" and entry[idKey]
        local quantity = type(entry) == "table" and math.tointeger(tonumber(entry.quantity))

        if type(item) ~= "string" or not quantity or quantity < 1 then
            return nil, locale("error_invalid_items")
        end

        items[item] = (items[item] or 0) + quantity
        count = count + 1

        if items[item] > maxQuantity then
            return nil, locale("error_too_many_items", maxQuantity)
        end
    end

    if count == 0 then return nil, locale("error_invalid_items") end

    return items
end

function Notify(playerId, message, type)
    exports['hype-core']:SendNotify(playerId, locale("notify_title"), message, 5000, type or "success")
end

function SendWebhookLog(kind, title, message)
    local current = GetSettings()
    if not current[kind] or current.webhook == "" then return end

    PerformHttpRequest(current.webhook, function() end, "POST", json.encode({
        username = locale("notify_title"),
        embeds = {
            {
                title = title,
                description = message,
                footer = { text = os.date("%d.%m.%Y %H:%M:%S") },
            },
        },
    }), { ["Content-Type"] = "application/json" })
end

function GetPlayerDisplayName(playerId)
    return exports['hype-core']:GetCharacterName(playerId) or GetPlayerName(playerId) or "Unknown"
end

local function formatStock(rows)
    local stock = {}
    for _, row in ipairs(rows) do
        stock[row.item] = row.stock
    end

    local products = {}
    for _, product in ipairs(Config.Products) do
        if stock[product.id] then
            products[#products + 1] = { item = product.id, stock = stock[product.id] }
        end
    end

    return products
end

local function getStock(machineId)
    return formatStock(MySQL.query.await(Queries.GetMachineProducts, { machineId }) or {})
end

local function formatMachine(row)
    return {
        id = row.id,
        model = row.model,
        x = row.x,
        y = row.y,
        z = row.z,
        heading = row.heading,
        name = row.name,
        price = row.price,
        forSale = ToBoolean(row.for_sale),
        owner = row.owner,
        status = row.status,
    }
end

local function playersNear(row)
    return lib.getNearbyPlayers(vec3(row.x, row.y, row.z), STOCK_SYNC_RANGE)
end

function SyncMachine(machineId)
    local row = MySQL.single.await(Queries.GetMachineProp, { machineId })
    if not row then return end

    TriggerClientEvent("hype-vendingmachine:client:set-machine", -1, formatMachine(row))
    Debug("info", "synced machine %s", machineId)
end

function SyncStock(row)
    if not ArmModels[row.model] then return end

    local nearby = playersNear(row)
    if #nearby == 0 then return end

    local stock = getStock(row.id)
    for _, player in ipairs(nearby) do
        TriggerClientEvent("hype-vendingmachine:client:set-stock", player.id, row.id, stock)
    end
end

function RemoveMachine(machineId)
    TriggerClientEvent("hype-vendingmachine:client:remove-machine", -1, machineId)
end

function GetNearbyMachine(playerId, machineId)
    machineId = math.tointeger(tonumber(machineId))
    local row = machineId and MySQL.single.await(Queries.GetMachine, { machineId })
    if not row then return nil, locale("error_machine_not_found") end

    if not exports['hype-core']:IsPlayerNearCoords(playerId, vector3(row.x, row.y, row.z), Config.Interaction.maxDistance) then
        return nil, locale("error_too_far")
    end

    return row
end

function GetProducts(machineId)
    local products, sold = {}, {}

    for _, product in ipairs(MySQL.query.await(Queries.GetMachineProducts, { machineId }) or {}) do
        local catalog = ProductsById[product.item]

        if catalog then
            products[#products + 1] = {
                id = catalog.id,
                name = catalog.name,
                description = catalog.description,
                category = catalog.category,
                price = product.price,
                stock = product.stock,
                image = catalog.image,
            }

            sold[catalog.id] = product.sold
        end
    end

    return products, sold
end

function LastDays(count)
    local days, now = {}, os.time()

    for offset = count - 1, 0, -1 do
        days[#days + 1] = os.date("%Y-%m-%d", now - offset * 86400)
    end

    return days
end

lib.callback.register("hype-vendingmachine:server:get-machines", function(source)
    local machines = {}
    for index, row in ipairs(MySQL.query.await(Queries.GetMachineProps) or {}) do
        machines[index] = formatMachine(row)
    end

    local identifier = exports['hype-core']:GetPlayerIdentifier(source)

    local staff = {}
    if identifier then
        for _, row in ipairs(MySQL.query.await(Queries.GetStaffMachines, { identifier }) or {}) do
            staff[#staff + 1] = row.machine_id
        end
    end

    return {
        identifier = identifier,
        staff = staff,
        machines = machines,
    }
end)

lib.callback.register("hype-vendingmachine:server:get-stock", function(source, machineId)
    machineId = math.tointeger(tonumber(machineId))
    return machineId and getStock(machineId) or {}
end)

lib.callback.register("hype-vendingmachine:server:get-purchase-data", function(source, machineId)
    local row, err = GetNearbyMachine(source, machineId)
    if not row then return Fail(err) end

    if not ToBoolean(row.for_sale) or row.status == "disabled" then return Fail(locale("error_not_for_sale")) end
    if not GetSettings().allowPlayerPurchase then return Fail(locale("error_purchase_disabled")) end

    local modelLabel = row.model
    for _, model in ipairs(Config.Machines) do
        if model.value == row.model then
            modelLabel = model.label
            break
        end
    end

    return {
        success = true,
        data = {
            name = row.name,
            area = row.area,
            model = modelLabel,
            price = row.price,
            capacity = row.capacity,
            products = GetProducts(row.id),
            account = Config.PurchaseAccount,
            balance = exports['hype-core']:GetPlayerMoney(source, Config.PurchaseAccount) or 0,
        }
    }
end)

lib.callback.register("hype-vendingmachine:server:buy-machine", function(source, machineId)
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err) end

    if not ToBoolean(row.for_sale) or row.status == "disabled" then return Fail(locale("error_not_for_sale")) end

    local current = GetSettings()
    if not current.allowPlayerPurchase then return Fail(locale("error_purchase_disabled")) end

    local identifier = exports['hype-core']:GetPlayerIdentifier(playerId)
    if not identifier then return Fail(locale("error_no_permission")) end

    if (MySQL.scalar.await(Queries.CountMachinesByOwner, { identifier }) or 0) >= current.maxMachinesPerPlayer then
        return Fail(locale("error_max_machines", current.maxMachinesPerPlayer))
    end

    if row.price > 0 and not exports['hype-core']:RemovePlayerMoney(playerId, Config.PurchaseAccount, row.price) then
        return Fail(locale("error_not_enough_money"))
    end

    if MySQL.update.await(Queries.BuyMachine, { identifier, GetPlayerDisplayName(playerId), row.id }) == 0 then
        if row.price > 0 then
            exports['hype-core']:AddPlayerMoney(playerId, Config.PurchaseAccount, row.price)
        end

        return Fail(locale("error_not_for_sale"))
    end

    Debug("success", "player %s (%s) bought machine %s for %s", playerId, identifier, row.id, row.price)

    SyncMachine(row.id)

    SendWebhookLog("logPurchases", locale("log_title_purchase"),
        locale("log_machine_bought", exports['hype-core']:FormatPlayerForLog(playerId), row.name, row.id, lib.math.groupdigits(row.price)))

    return {
        success = true,
        data = {
            message = locale("success_machine_bought", row.name, lib.math.groupdigits(row.price)),
        }
    }
end)

local function getWallet(playerId)
    return {
        cash = exports['hype-core']:GetPlayerMoney(playerId, "cash") or 0,
        bank = exports['hype-core']:GetPlayerMoney(playerId, "bank") or 0,
    }
end

lib.callback.register("hype-vendingmachine:server:get-vending-data", function(source, machineId)
    local row, err = GetNearbyMachine(source, machineId)
    if not row then return Fail(err) end

    if ToBoolean(row.for_sale) or row.status ~= "open" then return Fail(locale("error_machine_closed")) end

    return {
        success = true,
        data = {
            name = row.name,
            products = GetProducts(row.id),
            payments = GetOwnerSettings(row).payments,
            wallet = getWallet(source),
        }
    }
end)

local function notifyOwner(row, sold, paid)
    local ownerSource = row.owner and exports['hype-core']:GetPlayerSource(row.owner)
    if not ownerSource then return end

    local ownerSettings = GetOwnerSettings(row)

    if ownerSettings.notifySales then
        Notify(ownerSource, locale("notify_sale", row.name, lib.math.groupdigits(paid)))
    end

    if not ownerSettings.notifyLowStock then return end

    local threshold = ownerSettings.lowStockThreshold
    for _, line in ipairs(sold) do
        local stockLeft = line.stockBefore - line.quantity

        if line.stockBefore > threshold and stockLeft <= threshold then
            Notify(ownerSource, locale("notify_low_stock", ProductsById[line.item].name, row.name, stockLeft), "warning")
        end
    end
end

local pendingVends = {}
local lastVendId = 0

local function pendingUnits(machineId)
    local units = 0

    for _, vend in pairs(pendingVends) do
        if vend.row.id == machineId then
            for _, line in ipairs(vend.lines) do
                units = units + line.quantity
            end
        end
    end

    return units
end

local function releaseStock(machineId, lines)
    for _, line in ipairs(lines) do
        MySQL.update.await(Queries.RestoreStock, { line.quantity, line.quantity, machineId, line.item })
    end
end

local function handOver(playerId, row, lines, account)
    local identifier = exports['hype-core']:GetPlayerIdentifier(playerId) or tostring(playerId)
    local buyerName = GetPlayerDisplayName(playerId)

    local sold, sales, paid = {}, {}, 0
    for _, line in ipairs(lines) do
        if exports['hype-core']:AddItem(playerId, line.item, line.quantity) then
            sold[#sold + 1] = line
            sales[#sales + 1] = { row.id, identifier, buyerName, line.item, line.quantity, line.total, account }
            paid = paid + line.total
        else
            MySQL.update.await(Queries.RestoreStock, { line.quantity, line.quantity, row.id, line.item })

            if line.total > 0 then
                exports['hype-core']:AddPlayerMoney(playerId, account, line.total)
            end

            Debug("warning", "player %s could not receive %sx %s from machine %s, refunded %s", playerId, line.quantity, line.item, row.id, line.total)
        end
    end

    if #sales == 0 then return sold end

    local tax = math.floor(paid * GetSettings().salesTax / 100 + 0.5)

    MySQL.update.await(Queries.AddBalance, { paid - tax, row.id })
    MySQL.prepare.await(Queries.InsertTransaction, sales)

    notifyOwner(row, sold, paid)
    AutoRestock(row)

    return sold
end

local function completeVend(vendId)
    local vend = pendingVends[vendId]
    if not vend then return end

    pendingVends[vendId] = nil
    local playerId, row = vend.playerId, vend.row

    if vend.total > 0 and not exports['hype-core']:RemovePlayerMoney(playerId, vend.account, vend.total) then
        releaseStock(row.id, vend.lines)
        SyncStock(row)
        Notify(playerId, locale("error_not_enough_money"), "error")
        return
    end

    local sold = handOver(playerId, row, vend.lines, vend.account)

    if #sold < #vend.lines then
        SyncStock(row)
    end

    if #sold == 0 then
        Notify(playerId, locale("error_cannot_carry", ProductsById[vend.lines[1].item].name), "error")
    end
end

local function startVend(playerId, row, lines, account, total)
    lastVendId = lastVendId + 1
    local vendId = lastVendId
    pendingVends[vendId] = { playerId = playerId, row = row, lines = lines, account = account, total = total }

    SetTimeout((pendingUnits(row.id) * VEND_SECONDS_PER_UNIT + VEND_GRACE_SECONDS) * 1000, function()
        if pendingVends[vendId] then
            Debug("warning", "vend %s was not collected in time, completing it on the server", vendId)
            completeVend(vendId)
        end
    end)

    local stock = getStock(row.id)
    for _, player in ipairs(playersNear(row)) do
        TriggerClientEvent("hype-vendingmachine:client:vend", player.id, row.id, vendId, playerId, lines, stock)
    end
end

lib.callback.register("hype-vendingmachine:server:checkout", function(source, machineId, items, payment)
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err) end

    if ToBoolean(row.for_sale) or row.status ~= "open" then return Fail(locale("error_machine_closed")) end

    local requested, itemsError = ReadItems(items, "id", row.capacity)
    if not requested then return Fail(itemsError) end

    if (payment ~= "cash" and payment ~= "bank") or not GetOwnerSettings(row).payments[payment] then
        return Fail(locale("error_payment_not_accepted"))
    end

    local stock = {}
    for _, product in ipairs(MySQL.query.await(Queries.GetMachineProducts, { row.id }) or {}) do
        stock[product.item] = product
    end

    local lines, total = {}, 0
    for item, quantity in pairs(requested) do
        local product, catalog = stock[item], ProductsById[item]
        if not product or not catalog then return Fail(locale("error_invalid_products")) end

        if product.stock < quantity then return Fail(locale("error_out_of_stock", catalog.name)) end

        if not exports['hype-core']:CanCarryItem(playerId, item, quantity) then
            return Fail(locale("error_cannot_carry", catalog.name))
        end

        local line = { item = item, quantity = quantity, total = product.price * quantity, stockBefore = product.stock }
        lines[#lines + 1] = line
        total = total + line.total
    end

    if (exports['hype-core']:GetPlayerMoney(playerId, payment) or 0) < total then
        return Fail(locale("error_not_enough_money"))
    end

    local reserved = {}
    for _, line in ipairs(lines) do
        if MySQL.update.await(Queries.RemoveStock, { line.quantity, line.quantity, row.id, line.item, line.quantity }) == 0 then
            releaseStock(row.id, reserved)
            return Fail(locale("error_out_of_stock", ProductsById[line.item].name))
        end

        reserved[#reserved + 1] = line
    end

    if ArmModels[row.model] then
        startVend(playerId, row, lines, payment, total)
        return { success = true, data = { products = GetProducts(row.id) } }
    end

    if total > 0 and not exports['hype-core']:RemovePlayerMoney(playerId, payment, total) then
        releaseStock(row.id, lines)
        return Fail(locale("error_not_enough_money"))
    end

    if #handOver(playerId, row, lines, payment) == 0 then
        return Fail(locale("error_cannot_carry", ProductsById[lines[1].item].name))
    end

    return {
        success = true,
        data = {
            products = GetProducts(row.id),
            wallet = getWallet(playerId),
        }
    }
end)

RegisterNetEvent("hype-vendingmachine:server:vend-collect", function(vendId)
    local vend = pendingVends[vendId]
    if not vend or vend.playerId ~= source then return end

    completeVend(vendId)
end)

AddEventHandler("playerDropped", function()
    local playerId = source

    for vendId, vend in pairs(pendingVends) do
        if vend.playerId == playerId then
            pendingVends[vendId] = nil
            releaseStock(vend.row.id, vend.lines)
            SyncStock(vend.row)
        end
    end
end)

AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        InitSQL()
    end
end)
