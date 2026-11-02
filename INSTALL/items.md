# Items

Every product in `Config.Products` (`config/config.lua`) must exist as an inventory item with the same name (`id`).
Skip the items your inventory already has.

Copy the images in `INSTALL/item-images` to your inventory's image folder:

- ox_inventory: `ox_inventory/web/images`
- qb-inventory: `qb-inventory/html/images`

## ox_inventory

Add to the `return { ... }` table in `ox_inventory/data/items.lua`.

```lua
['water'] = {
    label = 'Water',
    weight = 500,
    stack = true,
    close = true,
    description = '500ml bottled water',
},

['cola'] = {
    label = 'eCola',
    weight = 350,
    stack = true,
    close = true,
    description = 'Classic fizzy cola',
},

['sprunk'] = {
    label = 'Sprunk',
    weight = 350,
    stack = true,
    close = true,
    description = 'Lemon-lime soda',
},

['coffee'] = {
    label = 'Coffee',
    weight = 250,
    stack = true,
    close = true,
    description = 'Hot black coffee',
},

['chips'] = {
    label = 'Chips',
    weight = 100,
    stack = true,
    close = true,
    description = 'Salted potato chips',
},

['chocolate'] = {
    label = 'Chocolate',
    weight = 50,
    stack = true,
    close = true,
    description = 'Milk chocolate bar',
},

['candy'] = {
    label = 'Candy',
    weight = 50,
    stack = true,
    close = true,
    description = 'Mixed fruit candy',
},

['sandwich'] = {
    label = 'Sandwich',
    weight = 200,
    stack = true,
    close = true,
    description = 'Ham and cheese sandwich',
},

['donut'] = {
    label = 'Donut',
    weight = 100,
    stack = true,
    close = true,
    description = 'Glazed donut',
},
```

## qb-inventory

Add to the `QBShared.Items` table in `qb-core/shared/items.lua`.

```lua
water = { name = 'water', label = 'Water', weight = 500, type = 'item', image = 'water.png', unique = false, useable = false, shouldClose = true, description = '500ml bottled water' },
cola = { name = 'cola', label = 'eCola', weight = 350, type = 'item', image = 'cola.png', unique = false, useable = false, shouldClose = true, description = 'Classic fizzy cola' },
sprunk = { name = 'sprunk', label = 'Sprunk', weight = 350, type = 'item', image = 'sprunk.png', unique = false, useable = false, shouldClose = true, description = 'Lemon-lime soda' },
coffee = { name = 'coffee', label = 'Coffee', weight = 250, type = 'item', image = 'coffee.png', unique = false, useable = false, shouldClose = true, description = 'Hot black coffee' },
chips = { name = 'chips', label = 'Chips', weight = 100, type = 'item', image = 'chips.png', unique = false, useable = false, shouldClose = true, description = 'Salted potato chips' },
chocolate = { name = 'chocolate', label = 'Chocolate', weight = 50, type = 'item', image = 'chocolate.png', unique = false, useable = false, shouldClose = true, description = 'Milk chocolate bar' },
candy = { name = 'candy', label = 'Candy', weight = 50, type = 'item', image = 'candy.png', unique = false, useable = false, shouldClose = true, description = 'Mixed fruit candy' },
sandwich = { name = 'sandwich', label = 'Sandwich', weight = 200, type = 'item', image = 'sandwich.png', unique = false, useable = false, shouldClose = true, description = 'Ham and cheese sandwich' },
donut = { name = 'donut', label = 'Donut', weight = 100, type = 'item', image = 'donut.png', unique = false, useable = false, shouldClose = true, description = 'Glazed donut' },
```
