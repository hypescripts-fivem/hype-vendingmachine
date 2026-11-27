local Config <const> = require "config.config"

-- Image folder of each inventory, as "resource/path/"
local IMAGE_PATHS <const> = {
    ["ox_inventory"] = "ox_inventory/web/images/",
    ["qb-inventory"] = "qb-inventory/html/images/",
    ["ps-inventory"] = "ps-inventory/html/images/",
    ["jpr-inventory"] = "jpr-inventory/html/images/",
}

--- Returns the folder the product images are loaded from: Config.InventoryImagePath when set,
--- otherwise the image folder of the active inventory.
---@return string path
function Modules.Client.Inventory.GetImagePath()
    return Config.InventoryImagePath
        or IMAGE_PATHS[Modules.Client.Inventory.Name]
        or IMAGE_PATHS["ox_inventory"]
end
