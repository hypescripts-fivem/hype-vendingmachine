local Config <const> = require 'config.config'

--- @type table<string, CatalogProduct>
ProductsById = {}
for _, product in ipairs(Config.Products) do
    ProductsById[product.id] = product
end

--- @param message string
--- @return CallbackResponse
function Fail(message)
    Debug("warning", "request failed: %s", message)
    return { success = false, error = message }
end

--- @param value any
--- @return string
function Trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

--- TINYINT(1) can come back as a boolean or a number depending on oxmysql's type casting
--- @param value any
--- @return boolean
function ToBoolean(value)
    return value == true or value == 1
end

--- JSON columns can come back decoded or as a string
--- @param value any
--- @return any
function DecodeJson(value)
    if type(value) ~= "string" then return value end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or nil
end

--- Global settings from the database on top of the config defaults
--- @return AdminSettings
function GetSettings()
    local settings = lib.table.deepclone(Config.DefaultSettings)

    for _, row in ipairs(MySQL.query.await(Queries.GetSettings) or {}) do
        local value = DecodeJson(row.value)
        if value ~= nil and settings[row.key] ~= nil then
            settings[row.key] = value
        end
    end

    return settings
end

--- Name, description and open/closed come from their own columns, the rest from `settings`
--- @param row MachineRow
--- @return OwnerSettings
function GetOwnerSettings(row)
    local settings = lib.table.deepclone(Config.DefaultOwnerSettings)
    local stored = DecodeJson(row.settings)

    if type(stored) == "table" then
        for key, value in pairs(stored) do
            if settings[key] ~= nil then
                settings[key] = value
            end
        end
    end

    settings.name = row.name
    settings.description = row.description
    settings.open = row.status == "open"

    return settings
end

--- Reads an item list from the UI, e.g. [{ id, quantity }], into item -> quantity. Repeated items are added up
--- @param list any
--- @param idKey string Field holding the item name ("id" for checkout, "productId" for stock orders)
--- @param maxQuantity integer Most units of one item in a single request
--- @return table<string, integer>? items
--- @return string? error
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

--- @param playerId integer
--- @param message string
--- @param type? "success" | "error" | "info" | "warning" Defaults to "success"
function Notify(playerId, message, type)
    exports['hype-core']:SendNotify(playerId, locale("notify_title"), message, 5000, type or "success")
end

--- Posts to the admin panel's Discord webhook, if one is set and that kind of log is turned on
--- @param kind "logPurchases" | "logAdminActions" Admin setting that turns this log on
--- @param title string
--- @param message string
function SendWebhookLog(kind, title, message)
    local settings = GetSettings()
    if not settings[kind] or settings.webhook == "" then return end

    PerformHttpRequest(settings.webhook, function() end, "POST", json.encode({
        username = locale("notify_title"),
        embeds = {
            {
                title = title,
                description = message,
                footer = { text = os.date("%d.%m.%Y %H:%M:%S") },
            },
        },
    }), { ["Content-Type"] = "application/json" })

    Debug("info", "webhook log sent: %s", title)
end

--- @param playerId integer
--- @return string
function GetPlayerDisplayName(playerId)
    return exports['hype-core']:GetCharacterName(playerId) or GetPlayerName(playerId) or "Unknown"
end

--- @param row MachineRow
--- @return MachineProp
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

--- Sends the machine to every player. Clients respawn the prop only if its model or position changed
--- @param machineId integer
function SyncMachine(machineId)
    local row = MySQL.single.await(Queries.GetMachineProp, { machineId })
    if not row then
        Debug("warning", "sync skipped, machine %s not found", machineId)
        return
    end

    TriggerClientEvent("hype-vendingmachine:client:set-machine", -1, formatMachine(row))
    Debug("info", "synced machine %s to all players", machineId)
end

--- @param machineId integer
function RemoveMachine(machineId)
    TriggerClientEvent("hype-vendingmachine:client:remove-machine", -1, machineId)
    Debug("info", "removed machine %s from all players", machineId)
end

--- Loads a machine the player is standing at
--- @param playerId integer
--- @param machineId any
--- @return MachineRow? row
--- @return string? error
function GetNearbyMachine(playerId, machineId)
    machineId = math.tointeger(tonumber(machineId))
    local row = machineId and MySQL.single.await(Queries.GetMachine, { machineId })
    if not row then
        Debug("warning", "player %s asked for unknown machine %s", playerId, machineId)
        return nil, locale("error_machine_not_found")
    end

    if not exports['hype-core']:IsPlayerNearCoords(playerId, vector3(row.x, row.y, row.z), Config.Interaction.maxDistance) then
        Debug("warning", "player %s is too far from machine %s", playerId, row.id)
        return nil, locale("error_too_far")
    end

    return row
end

--- The machine's products in the UI's shape. Items removed from the config are skipped
--- @param machineId integer
--- @return Product[] products
--- @return table<string, integer> sold Units sold per product id
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

--- The last `count` days as "2026-10-24", oldest first. The UI formats them with Config.NumberAndDateFormat
--- @param count integer
--- @return string[]
function LastDays(count)
    local days, now = {}, os.time()

    for offset = count - 1, 0, -1 do
        days[#days + 1] = os.date("%Y-%m-%d", now - offset * 86400) --[[@as string]]
    end

    return days
end

-- Every machine, plus who the player is and where they work, asked for when the player loads in
lib.callback.register("hype-vendingmachine:server:get-machines", function(source)
    if not source then return end
    local playerId = source

    local machines = {}
    for index, row in ipairs(MySQL.query.await(Queries.GetMachineProps) or {}) do
        machines[index] = formatMachine(row)
    end

    -- nil until the character is loaded; the client asks again on player-loaded
    local identifier = exports['hype-core']:GetPlayerIdentifier(playerId)

    local staff = {}
    if identifier then
        for _, row in ipairs(MySQL.query.await(Queries.GetStaffMachines, { identifier }) or {}) do
            staff[#staff + 1] = row.machine_id
        end
    end

    Debug("info", "sent %d machine(s) to player %s (identifier: %s, staff at %d)", #machines, playerId, identifier, #staff)

    return {
        identifier = identifier,
        staff = staff,
        machines = machines,
    }
end)

-- Checked before the purchase modal opens; the result is what purchase:get-data hands to the UI
lib.callback.register("hype-vendingmachine:server:get-purchase-data", function(source, machineId)
    if not source then return Fail(locale("error_machine_not_found")) end
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err --[[@as string]]) end

    if not ToBoolean(row.for_sale) or row.status == "disabled" then return Fail(locale("error_not_for_sale")) end
    if not GetSettings().allowPlayerPurchase then return Fail(locale("error_purchase_disabled")) end

    local modelLabel = row.model
    for _, model in ipairs(Config.Machines) do
        if model.value == row.model then
            modelLabel = model.label
            break
        end
    end

    Debug("info", "player %s opened the purchase menu of machine %s", playerId, row.id)

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
            balance = exports['hype-core']:GetPlayerMoney(playerId, Config.PurchaseAccount) or 0,
        }
    }
end)

lib.callback.register("hype-vendingmachine:server:buy-machine", function(source, machineId)
    if not source then return Fail(locale("error_machine_not_found")) end
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err --[[@as string]]) end

    if not ToBoolean(row.for_sale) or row.status == "disabled" then return Fail(locale("error_not_for_sale")) end

    local settings = GetSettings()
    if not settings.allowPlayerPurchase then return Fail(locale("error_purchase_disabled")) end

    local identifier = exports['hype-core']:GetPlayerIdentifier(playerId)
    if not identifier then return Fail(locale("error_no_permission")) end

    if (MySQL.scalar.await(Queries.CountMachinesByOwner, { identifier }) or 0) >= settings.maxMachinesPerPlayer then
        return Fail(locale("error_max_machines", settings.maxMachinesPerPlayer))
    end

    if row.price > 0 and not exports['hype-core']:RemovePlayerMoney(playerId, Config.PurchaseAccount, row.price) then
        return Fail(locale("error_not_enough_money"))
    end

    -- Someone else got it first: give the money back
    if MySQL.update.await(Queries.BuyMachine, { identifier, GetPlayerDisplayName(playerId), row.id }) == 0 then
        if row.price > 0 then
            exports['hype-core']:AddPlayerMoney(playerId, Config.PurchaseAccount, row.price)
        end

        Debug("warning", "player %s lost machine %s to another buyer, refunded %s", playerId, row.id, row.price)
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

--- The player's money in both accounts, shown on the checkout modal
--- @param playerId integer
--- @return { cash: integer, bank: integer }
local function getWallet(playerId)
    return {
        cash = exports['hype-core']:GetPlayerMoney(playerId, "cash") or 0,
        bank = exports['hype-core']:GetPlayerMoney(playerId, "bank") or 0,
    }
end

-- Checked before the vending menu opens; the result is what vending:get-data hands to the UI
lib.callback.register("hype-vendingmachine:server:get-vending-data", function(source, machineId)
    if not source then return Fail(locale("error_machine_not_found")) end
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err --[[@as string]]) end

    if ToBoolean(row.for_sale) or row.status ~= "open" then return Fail(locale("error_machine_closed")) end

    Debug("info", "player %s opened the vending menu of machine %s", playerId, row.id)

    return {
        success = true,
        data = {
            name = row.name,
            products = GetProducts(row.id),
            payments = GetOwnerSettings(row).payments,
            wallet = getWallet(playerId),
        }
    }
end)

--- Tells the owner about the sale and about products that just dropped to the low stock threshold,
--- if they're online and turned those notifications on
--- @param row MachineRow
--- @param sold { item: string, quantity: integer, stockBefore: integer }[]
--- @param paid integer
local function notifyOwner(row, sold, paid)
    local ownerSource = row.owner and exports['hype-core']:GetPlayerSource(row.owner)
    if not ownerSource then return end

    local settings = GetOwnerSettings(row)

    if settings.notifySales then
        Notify(ownerSource, locale("notify_sale", row.name, lib.math.groupdigits(paid)))
    end

    if not settings.notifyLowStock then return end

    for _, line in ipairs(sold) do
        local stockLeft = line.stockBefore - line.quantity

        -- Only when it crosses the threshold, not on every sale below it
        if line.stockBefore > settings.lowStockThreshold and stockLeft <= settings.lowStockThreshold then
            Notify(ownerSource, locale("notify_low_stock", ProductsById[line.item].name, row.name, stockLeft), "warning")
        end
    end
end

-- Stock is reserved first, then the money is taken, then the items are handed over.
-- Anything that fails on the way is undone, so the buyer never pays for what they didn't get
lib.callback.register("hype-vendingmachine:server:checkout", function(source, machineId, items, payment)
    if not source then return Fail(locale("error_machine_not_found")) end
    local playerId = source

    local row, err = GetNearbyMachine(playerId, machineId)
    if not row then return Fail(err --[[@as string]]) end

    if ToBoolean(row.for_sale) or row.status ~= "open" then return Fail(locale("error_machine_closed")) end

    local requested, itemsError = ReadItems(items, "id", row.capacity)
    if not requested then return Fail(itemsError --[[@as string]]) end

    --- @type table<string, ProductRow>
    local stock = {}
    for _, product in ipairs(MySQL.query.await(Queries.GetMachineProducts, { row.id }) or {}) do
        stock[product.item] = product
    end

    -- Prices come from the database, never from the UI
    --- @type { item: string, quantity: integer, total: integer, stockBefore: integer }[]
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

    -- The method the buyer picked, if the owner accepts it
    if (payment ~= "cash" and payment ~= "bank") or not GetOwnerSettings(row).payments[payment] then
        return Fail(locale("error_payment_not_accepted"))
    end

    local account = payment --[[@as PaymentMethod]]

    if (exports['hype-core']:GetPlayerMoney(playerId, account) or 0) < total then
        return Fail(locale("error_not_enough_money"))
    end

    local reserved = {}

    --- Gives back the stock reserved so far
    local function release()
        for _, line in ipairs(reserved) do
            MySQL.update.await(Queries.RestoreStock, { line.quantity, line.quantity, row.id, line.item })
        end

        Debug("warning", "released %d reserved line(s) on machine %s", #reserved, row.id)
    end

    for _, line in ipairs(lines) do
        -- Someone else bought the last ones a moment ago
        if MySQL.update.await(Queries.RemoveStock, { line.quantity, line.quantity, row.id, line.item, line.quantity }) == 0 then
            release()
            return Fail(locale("error_out_of_stock", ProductsById[line.item].name))
        end

        reserved[#reserved + 1] = line
    end

    if total > 0 and not exports['hype-core']:RemovePlayerMoney(playerId, account, total) then
        release()
        return Fail(locale("error_not_enough_money"))
    end

    local identifier = exports['hype-core']:GetPlayerIdentifier(playerId) or tostring(playerId)
    local buyerName = GetPlayerDisplayName(playerId)

    -- A line the inventory refuses is given back: stock to the machine, money to the buyer
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

    if #sales == 0 then return Fail(locale("error_cannot_carry", ProductsById[lines[1].item].name)) end

    -- Sales tax comes out of the owner's share, so the buyer pays the price shown
    local tax = math.floor(paid * GetSettings().salesTax / 100 + 0.5)

    MySQL.update.await(Queries.AddBalance, { paid - tax, row.id })
    MySQL.prepare.await(Queries.InsertTransaction, sales)

    Debug("success", "player %s bought %d line(s) from machine %s for %s via %s (tax %s)", playerId, #sales, row.id, paid, account, tax)

    notifyOwner(row, sold, paid)

    return {
        success = true,
        data = {
            products = GetProducts(row.id),
            wallet = getWallet(playerId),
        }
    }
end)

AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        initSQL()
    end
end)