return {
    Debug = false,
    AutoRunSQL = true, -- automatically runs install/insert-me.sql on resource start, if it exists

    -- Money and dates in the UI, e.g. "USD" with "en-US" shows $1,250 and Oct 24, "EUR" with "de-DE" shows 1.250 € and 24. Okt.
    Currency = "USD",              -- ISO 4217 currency code
    NumberAndDateFormat = "en-US", -- BCP 47 locale

    Commands = {
        AdminMenu = {
            name = "vendingmenu",
            help = "Open the vending machine admin menu",
            permission = "group.admin",
        }
    },

    Interaction = {
        target = true,        -- use ox_target / qb-target through hype-core when one is running, TextUI otherwise
        distance = 1.5,       -- how close the player must be to open a machine
        maxDistance = 3.0,    -- the server rejects requests from players further than this
        spawnDistance = 75.0, -- machine props are spawned within this range
        -- TextUI only. Control ids: https://docs.fivem.net/docs/game-references/controls/
        keys = {
            primary = { control = 38, label = "E" },   -- buy, or open the vending menu
            secondary = { control = 47, label = "G" }, -- owner menu, for the owner and staff
        },
    },

    -- Account the machine price is taken from when a player buys one: "bank" or "cash"
    PurchaseAccount = "bank",

    -- Account the owner panel's deposits come from and withdrawals go to: "bank" or "cash"
    CashAccount = "cash",

    -- Fallback for hype_vending_settings. The values in the database (admin panel) take priority
    DefaultSettings = {
        wholesaleMultiplier = 1,
        salesTax = 8,
        maxMachinesPerPlayer = 3,
        deliveryMinutes = 5,
        defaultCapacity = 50,
        defaultPrice = 20000,
        allowPlayerPurchase = true,
        webhook = "",
        logPurchases = true,
        logAdminActions = true,
    },

    -- Stored in the machine's `settings` column when it is created. Name, description and open/closed have their own columns
    DefaultOwnerSettings = {
        schedule = { enabled = false, opensAt = "08:00", closesAt = "22:00" },
        lowStockThreshold = 5,
        autoRestock = false,
        notifyLowStock = false,
        notifySales = false,
        payments = { cash = true, bank = true },
    },

    Limits = {
        nameLength = 64,
        descriptionLength = 120,
        maxCapacity = 500,
        maxMachinePrice = 10000000,
        machineSpacing = 1.0,     -- metres, two machines can't be placed closer than this
        maxPrice = 10000,         -- highest price an owner can set for a product
        maxOrderQuantity = 500,   -- per product, per stock order
        revenueDays = 7,
        historyLength = 50,       -- owner panel: sales, cash movements and orders shown
        maxCashTransfer = 1000000, -- largest single deposit or withdrawal
        maxImport = 100,          -- machines per admin import
        colorSlots = 8,
    },

    -- Percentage of the machine price paid back to the owner on owner:sell
    SellRefund = 50,

    -- Stock orders are `preparing` for deliveryMinutes (admin setting), then `prepared` until a player picks them up.
    -- The cart spawns at one of `spawns` with one box per product on it; boxes go into any vehicle's trunk, then into the machine
    Cargo = {
        model = "hype_cargo_box",
        boxModel = "prop_cs_cardbox_01",
        spawns = {
            vec4(1199.8463, -3245.6299, 5.7318, 0.2289),
            vec4(1197.4340, -3245.6760, 5.7297, 4.5689),
        },
        -- The cart spawns once the player is within Interaction.spawnDistance of its spawn. From then on,
        -- going further than this from the spawn before every box is loaded cancels the order
        cancelDistance = 150.0,
        handleOffset = vec3(-0.6, 0.0, 1.0), -- from the cart, where its grab option is
        -- Ped bone ids: 24818 = upper spine, 60309 = left hand. The cart and box are attached to them, tune in game.
        -- The spine moves with the upper body only, so the cart doesn't bob with the legs. On it x is up/down and y forward/back
        cartAttach = { bone = 24818, offset = vec3(-0.24, 1.6, 0.0), rotation = vec3(88.0, 236.0, 173.0) },
        -- Upper body only, held still at `time` (0-1 through the animation) so the arms stay in the pushing pose
        cartAnim = { dict = "missfinale_c2ig_11", name = "pushcar_offcliff_f", time = 0.3 },
        boxAttach = { bone = 60309, offset = vec3(0.025, 0.08, 0.255), rotation = vec3(-145.0, 290.0, 0.0) },
        boxAnim = { dict = "anim@heists@box_carry@", name = "idle" },
        boxOffset = vec3(0.0, 0.0, 0.5), -- first box, from the cart
        boxStep = vec3(0.0, 0.0, 0.3),   -- each next box is stacked this much further
    },

    StaffPermissions = {
        "dashboard.view",
        "products.prices",
        "restock.order",
        "transactions.view",
        "cash.deposit",
        "cash.withdraw",
        "cash.history",
        "staff.view",
        "staff.manage",
        "settings.general",
        "settings.hours",
        "settings.stock",
        "settings.payments",
    },

    Machines = {
        { label = "Soda machine", value = "prop_vend_soda_01" },
        { label = "Snack machine", value = "prop_vend_snak_01" },
        { label = "Coffee machine", value = "prop_vend_coffe_01" },
        { label = "Water machine", value = "prop_vend_water_01" },
    },

    -- `price` is the starting sale price, `wholesale` is what the owner pays the supplier per unit
    Products = {
        { id = "water", name = "Water", description = "500ml bottled water", category = "drinks", price = 5, wholesale = 2, image = "water.png" },
        { id = "cola", name = "eCola", description = "Classic fizzy cola", category = "drinks", price = 8, wholesale = 4, image = "cola.png" },
        { id = "sprunk", name = "Sprunk", description = "Lemon-lime soda", category = "drinks", price = 8, wholesale = 4, image = "sprunk.png" },
        { id = "coffee", name = "Coffee", description = "Hot black coffee", category = "drinks", price = 10, wholesale = 5, image = "coffee.png" },
        { id = "chips", name = "Chips", description = "Salted potato chips", category = "snacks", price = 6, wholesale = 3, image = "chips.png" },
        { id = "chocolate", name = "Chocolate", description = "Milk chocolate bar", category = "snacks", price = 7, wholesale = 3, image = "chocolate.png" },
        { id = "candy", name = "Candy", description = "Mixed fruit candy", category = "snacks", price = 4, wholesale = 2, image = "candy.png" },
        { id = "sandwich", name = "Sandwich", description = "Ham and cheese sandwich", category = "food", price = 15, wholesale = 8, image = "sandwich.png" },
        { id = "donut", name = "Donut", description = "Glazed donut", category = "food", price = 9, wholesale = 4, image = "donut.png" },
    }
}
