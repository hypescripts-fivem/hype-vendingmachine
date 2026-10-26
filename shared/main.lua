lib.locale()

Queries = {
    -- Machines
    GetMachines = "SELECT * FROM hype_vending_machines ORDER BY id DESC",
    GetMachine = "SELECT * FROM hype_vending_machines WHERE id = ?",
    -- What every client needs for the prop and its interaction options
    GetMachineProps = "SELECT id, model, x, y, z, heading, name, price, for_sale, owner, status FROM hype_vending_machines",
    GetMachineProp = "SELECT id, model, x, y, z, heading, name, price, for_sale, owner, status FROM hype_vending_machines WHERE id = ?",
    CountMachinesByOwner = "SELECT COUNT(*) FROM hype_vending_machines WHERE owner = ?",
    -- The first parameter is a machine id to skip (the one being edited), 0 when creating
    GetMachineNearPosition = "SELECT id FROM hype_vending_machines WHERE id <> ? AND POW(x - ?, 2) + POW(y - ?, 2) + POW(z - ?, 2) < POW(?, 2) LIMIT 1",
    GetColorSlotUsage = "SELECT color_slot, COUNT(*) AS count FROM hype_vending_machines GROUP BY color_slot",
    -- Starts for sale with no owner. Owned machines are handed over with SetMachineOwner
    InsertMachine = "INSERT INTO hype_vending_machines (name, model, area, x, y, z, heading, price, capacity, color_slot, settings) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    -- Ownership changes go through SetMachineOwner / SetMachineForSale
    UpdateMachine = "UPDATE hype_vending_machines SET name = ?, model = ?, area = ?, x = ?, y = ?, z = ?, heading = ?, price = ?, capacity = ? WHERE id = ?",
    -- An admin's `disabled` stays; the owner can still save everything else
    UpdateMachineSettings = "UPDATE hype_vending_machines SET name = ?, description = ?, status = IF(status = 'disabled', 'disabled', ?), settings = ? WHERE id = ?",
    SetMachineStatus = "UPDATE hype_vending_machines SET status = ? WHERE id = ?",
    SetMachineOwner = "UPDATE hype_vending_machines SET owner = ?, owner_name = ?, for_sale = 0 WHERE id = ?",
    -- affectedRows = 0 means someone else bought it first or an admin changed it
    BuyMachine = "UPDATE hype_vending_machines SET owner = ?, owner_name = ?, for_sale = 0 WHERE id = ? AND for_sale = 1 AND status <> 'disabled'",
    -- Keeps an admin's `disabled`. The balance is left alone; reset it separately when needed
    SetMachineForSale = "UPDATE hype_vending_machines SET owner = NULL, owner_name = NULL, for_sale = 1, status = IF(status = 'disabled', 'disabled', 'closed') WHERE id = ?",
    -- The owner selling it back. affectedRows = 0 means it's no longer theirs (already sold)
    SellMachine = "UPDATE hype_vending_machines SET owner = NULL, owner_name = NULL, for_sale = 1, status = IF(status = 'disabled', 'disabled', 'closed'), balance = 0 WHERE id = ? AND owner = ?",
    GetMachineBalance = "SELECT balance FROM hype_vending_machines WHERE id = ?",
    AddBalance ="UPDATE hype_vending_machines SET balance = balance + ? WHERE id = ?",
    -- affectedRows = 0 means the balance was too low
    RemoveBalance = "UPDATE hype_vending_machines SET balance = balance - ? WHERE id = ? AND balance >= ?",
    ResetBalance = "UPDATE hype_vending_machines SET balance = 0 WHERE id = ?",
    DeleteMachine = "DELETE FROM hype_vending_machines WHERE id = ?",

    -- Products
    GetMachineProducts = "SELECT item, price, stock, sold FROM hype_vending_products WHERE machine_id = ?",
    GetAllProducts = "SELECT machine_id, item, stock FROM hype_vending_products",
    InsertProduct = "INSERT IGNORE INTO hype_vending_products (machine_id, item, price) VALUES (?, ?, ?)",
    DeleteRemovedProducts = "DELETE FROM hype_vending_products WHERE machine_id = ? AND item NOT IN (?)",
    UpdateProductPrice = "UPDATE hype_vending_products SET price = ? WHERE machine_id = ? AND item = ?",
    -- affectedRows = 0 means there wasn't enough stock
    RemoveStock = "UPDATE hype_vending_products SET stock = stock - ?, sold = sold + ? WHERE machine_id = ? AND item = ? AND stock >= ?",
    AddStock = "UPDATE hype_vending_products SET stock = LEAST(stock + ?, ?) WHERE machine_id = ? AND item = ?",
    -- Gives back stock reserved by a checkout that couldn't finish
    RestoreStock = "UPDATE hype_vending_products SET stock = stock + ?, sold = sold - ? WHERE machine_id = ? AND item = ?",
    ClampStock ="UPDATE hype_vending_products SET stock = LEAST(stock, ?) WHERE machine_id = ?",

    -- Transactions
    InsertTransaction = "INSERT INTO hype_vending_transactions (machine_id, buyer, buyer_name, item, quantity, total, payment) VALUES (?, ?, ?, ?, ?, ?, ?)",
    GetTransactions = "SELECT id, buyer_name, item, quantity, total, created_at FROM hype_vending_transactions WHERE machine_id = ? ORDER BY id DESC LIMIT ?",
    -- The interval is days before today, so pass revenueDays - 1
    GetDailyRevenue = "SELECT DATE_FORMAT(created_at, '%Y-%m-%d') AS day, SUM(total) AS revenue, SUM(quantity) AS sales FROM hype_vending_transactions WHERE machine_id = ? AND created_at >= CURDATE() - INTERVAL ? DAY GROUP BY day ORDER BY day",
    GetTotalDailyRevenue = "SELECT DATE_FORMAT(created_at, '%Y-%m-%d') AS day, SUM(total) AS revenue FROM hype_vending_transactions WHERE created_at >= CURDATE() - INTERVAL ? DAY GROUP BY day ORDER BY day",
    GetMachineRevenue = "SELECT machine_id, SUM(total) AS revenue, SUM(quantity) AS sales FROM hype_vending_transactions GROUP BY machine_id",

    -- Cash
    InsertCashMovement = "INSERT INTO hype_vending_cash (machine_id, type, amount, `by`, by_name) VALUES (?, ?, ?, ?, ?)",
    GetCashMovements = "SELECT id, type, amount, by_name, created_at FROM hype_vending_cash WHERE machine_id = ? ORDER BY id DESC LIMIT ?",

    -- Orders
    InsertOrder = "INSERT INTO hype_vending_orders (machine_id, total, ordered_by) VALUES (?, ?, ?)",
    InsertOrderItem = "INSERT INTO hype_vending_order_items (order_id, item, quantity, unit_price) VALUES (?, ?, ?, ?)",
    GetOrders = "SELECT id, total, status, created_at FROM hype_vending_orders WHERE machine_id = ? ORDER BY id DESC LIMIT ?",
    GetOrderItems = "SELECT order_id, item, quantity FROM hype_vending_order_items WHERE order_id IN (?)",
    GetOrder = "SELECT id, machine_id, status FROM hype_vending_orders WHERE id = ?",
    -- Units ordered but not delivered yet; they count against capacity
    GetIncomingStock = "SELECT oi.item, SUM(oi.quantity) AS quantity FROM hype_vending_order_items oi JOIN hype_vending_orders o ON o.id = oi.order_id WHERE o.machine_id = ? AND o.status NOT IN ('completed', 'cancelled') GROUP BY oi.item",
    -- Only `preparing` runs on a timer; from `prepared` on the player brings the order (sv-cargo.lua)
    GetPendingOrders ="SELECT id, machine_id, status, updated_at FROM hype_vending_orders WHERE status = 'preparing'",
    -- A pickup in progress when the resource stopped starts over
    ResetShippingOrders = "UPDATE hype_vending_orders SET status = 'prepared' WHERE status = 'shipping'",
    UpdateOrderStatus = "UPDATE hype_vending_orders SET status = ? WHERE id = ?",
    DeletePendingOrders = "DELETE FROM hype_vending_orders WHERE machine_id = ? AND status NOT IN ('completed', 'cancelled')",

    -- Staff
    GetStaff = "SELECT id, identifier, name, permissions, hired_at, last_online FROM hype_vending_staff WHERE machine_id = ?",
    GetStaffMember = "SELECT id, permissions FROM hype_vending_staff WHERE machine_id = ? AND identifier = ?",
    GetStaffMemberById = "SELECT id, identifier, permissions FROM hype_vending_staff WHERE id = ? AND machine_id = ?",
    GetStaffMachines = "SELECT machine_id, permissions FROM hype_vending_staff WHERE identifier = ?",
    InsertStaff = "INSERT INTO hype_vending_staff (machine_id, identifier, name, permissions) VALUES (?, ?, ?, ?)",
    UpdateStaffPermissions = "UPDATE hype_vending_staff SET permissions = ? WHERE id = ? AND machine_id = ?",
    UpdateStaffLastOnline = "UPDATE hype_vending_staff SET last_online = CURRENT_TIMESTAMP WHERE machine_id = ? AND identifier = ?",
    DeleteStaff = "DELETE FROM hype_vending_staff WHERE id = ? AND machine_id = ?",
    DeleteAllStaff = "DELETE FROM hype_vending_staff WHERE machine_id = ?",

    -- Settings
    GetSettings = "SELECT `key`, `value` FROM hype_vending_settings",
    SaveSetting = "INSERT INTO hype_vending_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)",
}
