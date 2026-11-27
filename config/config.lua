return {
    Debug = false,
    AutoRunSQL = true, -- automatically runs install/insert-me.sql on resource start, if it exists

    -- Bridges. "auto" picks the first one that is running
    Framework = "auto",     -- "auto" | "qbx" | "qb" | "esx"
    Inventory = "auto",     -- "auto" | "ox_inventory" | "qb-inventory" | "ps-inventory" | "jpr-inventory" | "codem-inventory" | "core_inventory" | "origen_inventory" | "tgiann-inventory"
    Notifications = "auto", -- "auto" | "okokNotify" | "ps-ui" | "ox_lib"
    TextUI = "auto",        -- "auto" | "jg-textui" | "okokTextUI" | "ps-ui" | "ox_lib" | "qb-core"
    -- Folder the product images are loaded from, as "resource/path/". nil picks the inventory's own image folder
    InventoryImagePath = nil,

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
        target = true,        -- use ox_target / qb-target when one is running, TextUI otherwise
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
        cartAttach = { bone = 24818, offset = vec3(-0.2107, 1.7693, -0.2852), rotation = vec3(79.47, 73.39, -21.31) },
        -- Upper body only, held still at `time` (0-1 through the animation) so the arms stay in the pushing pose
        cartAnim = { dict = "missfinale_c2ig_11", name = "pushcar_offcliff_f", time = 0.3 },
        boxAttach = { bone = 60309, offset = vec3(0.025, 0.08, 0.255), rotation = vec3(-145.0, 290.0, 0.0) },
        boxAnim = { dict = "anim@heists@box_carry@", name = "idle" },
        -- Boxes are stacked in two rows: odd boxes at boxOffset, even boxes boxFront in front of them,
        -- and every pair goes boxStep higher (1: back, 2: front, 3: back + up, 4: front + up, ...)
        boxOffset = vec3(-0.2, 0.0, 0.4), -- first box, from the cart
        boxFront = vec3(0.3, 0.0, 0.0),   -- the front row, from the back row
        boxStep = vec3(0.0, 0.0, 0.3),    -- each next layer is stacked this much higher
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

    -- `arm` machines come from olentrix_vending: their stock sits on the shelves behind the glass and the arm
    -- carries each unit sold to the tray. The items reach the buyer's inventory once the arm drops them.
    -- The admin panel's model lists are in web/src/stores/admin.ts (machineModels, customMachineModels for `arm`), keep them the same
    Machines = {
        { label = "Soda machine", value = "prop_vend_soda_01" },
        { label = "Snack machine", value = "prop_vend_snak_01" },
        { label = "Coffee machine", value = "prop_vend_coffe_01" },
        { label = "Water machine", value = "prop_vend_water_01" },
        { label = "Glass machine", value = "olentrix_vend", arm = true },
        { label = "Glass machine (eCola)", value = "olentrix_vend_ecola", arm = true },
        { label = "Glass machine (Sprunk)", value = "olentrix_vend_sprunk", arm = true },
        { label = "Glass machine (Raine)", value = "olentrix_vend_raine", arm = true },
        { label = "Glass machine (Junk)", value = "olentrix_vend_junk", arm = true },
        { label = "Glass machine (Bean Machine)", value = "olentrix_vend_beanmachine", arm = true },
        { label = "Glass machine (Phat Chips)", value = "olentrix_vend_phatchips", arm = true },
        { label = "Glass machine (Ego Chaser)", value = "olentrix_vend_egochaser", arm = true },
        { label = "Glass machine (Cluckin' Bell)", value = "olentrix_vend_cluckinbell", arm = true },
        { label = "Glass machine (Burger Shot)", value = "olentrix_vend_burgershot", arm = true },
        { label = "Glass machine (24/7)", value = "olentrix_vend_247", arm = true },
    },

    -- Admin panel, "Set machine position": an existing machine can only be moved by an admin this close to it
    Placement = {
        editDistance = 10.0,
    },

    -- Arm machines open their own screen instead of the menu: the `vend_screen` texture shows the shop and the camera looks at it.
    -- Every olentrix model shares the same body, so one set of offsets (from the machine prop) fits all of them. Tune them in game
    Screen = {
        texture = "vend_screen", -- texture name in the model; its dictionary is the model name
        width = 900,             -- DUI size in pixels, 9:16 like the screen
        height = 1600,
        -- The front of the machine faces -y (the glass is at y -0.358, see olentrix_vending's config); x is left/right, z is up.
        -- Move y further negative to pull the camera back, lower fov to zoom in
        camera = { offset = vec3(0.456, -1.3, 1.361), fov = 30.0 }, -- looks at the middle of the screen
        corners = {              -- the screen's corners; clicks are mapped from them
            topLeft = vec3(0.339, -0.37, 1.564),
            topRight = vec3(0.573, -0.37, 1.564),
            bottomLeft = vec3(0.339, -0.37, 1.164),
        },
    },

    -- `price` is the starting sale price, `wholesale` is what the owner pays the supplier per unit.
    -- `model` is the prop on the shelves of `arm` machines, one lane per product (20 lanes, in this order)
    Products = {
        { id = "water", name = "Water", description = "500ml bottled water", category = "drinks", price = 5, wholesale = 2, image = "water.png", model = "prop_ld_flow_bottle" },
        { id = "cola", name = "eCola", description = "Classic fizzy cola", category = "drinks", price = 8, wholesale = 4, image = "cola.png", model = "prop_ecola_can" },
        { id = "sprunk", name = "Sprunk", description = "Lemon-lime soda", category = "drinks", price = 8, wholesale = 4, image = "sprunk.png", model = "prop_ld_can_01" },
        { id = "coffee", name = "Coffee", description = "Hot black coffee", category = "drinks", price = 10, wholesale = 5, image = "coffee.png", model = "p_amb_coffeecup_01" },
        { id = "chips", name = "Chips", description = "Salted potato chips", category = "snacks", price = 6, wholesale = 3, image = "chips.png", model = "v_ret_ml_chips4" },
        { id = "chocolate", name = "Chocolate", description = "Milk chocolate bar", category = "snacks", price = 7, wholesale = 3, image = "chocolate.png", model = "prop_choc_ego" },
        { id = "candy", name = "Candy", description = "Mixed fruit candy", category = "snacks", price = 4, wholesale = 2, image = "candy.png", model = "prop_candy_pqs" },
        { id = "sandwich", name = "Sandwich", description = "Ham and cheese sandwich", category = "food", price = 15, wholesale = 8, image = "sandwich.png", model = "prop_sandwich_01" },
        { id = "donut", name = "Donut", description = "Glazed donut", category = "food", price = 9, wholesale = 4, image = "donut.png", model = "prop_donut_01" },
    }
}
