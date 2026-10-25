---@meta

---@alias MachineStatus "open" | "closed" | "disabled"
---@alias StockOrderStatus "preparing" | "prepared" | "shipping" | "completed"
---@alias CashMovementType "deposit" | "withdraw" | "order"
---@alias View "vending" | "purchase" | "owner" | "admin"
---@alias PaymentMethod "cash" | "bank"

---@class CallbackResponse
---@field success boolean
---@field error? string Shown to the player as is
---@field data? table

---@class MachineLocation
---@field label string Area name
---@field x number
---@field y number
---@field z number
---@field heading number

---@class MachineConfig
---@field name string
---@field model string
---@field location MachineLocation
---@field ownerId string Server id or citizen id, empty while for sale
---@field forSale boolean
---@field price integer Purchase price of the machine
---@field capacity integer Max stock per product
---@field products string[] Product ids

---@class AdminMachine : MachineConfig Machine shape the admin panel lists
---@field id string
---@field colorSlot integer
---@field ownerName string?
---@field status MachineStatus
---@field balance integer
---@field revenue number
---@field sales number
---@field stockLevel integer 0-100
---@field createdAt number Milliseconds

---@class MachineRow A hype_vending_machines row
---@field id integer
---@field name string
---@field description string
---@field model string
---@field area string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field owner string? Framework identifier, nil while for sale
---@field owner_name string?
---@field for_sale boolean|integer
---@field price integer
---@field capacity integer
---@field status MachineStatus
---@field balance integer
---@field color_slot integer
---@field settings string|table? JSON
---@field created_at number Milliseconds

---@class ProductRow A hype_vending_products row
---@field machine_id integer
---@field item string
---@field price integer
---@field stock integer
---@field sold integer

---@class CatalogProduct A Config.Products entry
---@field id string Inventory item name
---@field name string
---@field description string
---@field category string
---@field price integer Starting sale price
---@field wholesale integer What the owner pays the supplier per unit
---@field image string

---@class Product Product shape the UI uses
---@field id string
---@field name string
---@field description? string
---@field category string
---@field price integer
---@field stock integer
---@field image? string

---@class MachineProp What every client gets for a machine's prop and interaction options
---@field id integer
---@field model string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field name string
---@field price integer
---@field forSale boolean
---@field owner string?
---@field status MachineStatus

---@class MachineEntry Client-side state of one machine
---@field data MachineProp
---@field point table ox_lib point that spawns the prop
---@field textPoint? table ox_lib point for the TextUI, only without a target resource
---@field entity? integer
---@field inside boolean

---@class OwnerAccess
---@field owner boolean
---@field permissions string[] Staff permissions, empty for the owner

---@class OwnerSchedule
---@field enabled boolean
---@field opensAt string "HH:MM", in-game time
---@field closesAt string

---@class OwnerSettings
---@field name string
---@field description string
---@field open boolean
---@field schedule OwnerSchedule
---@field lowStockThreshold integer
---@field autoRestock boolean
---@field notifyLowStock boolean
---@field notifySales boolean
---@field payments table<PaymentMethod, boolean>

---@class AdminSettings
---@field wholesaleMultiplier number
---@field salesTax integer Percent
---@field maxMachinesPerPlayer integer
---@field deliveryMinutes integer Minutes per order stage
---@field defaultCapacity integer
---@field defaultPrice integer
---@field allowPlayerPurchase boolean
---@field webhook string
---@field logPurchases boolean
---@field logAdminActions boolean

---@class DailyRevenue
---@field date string "2026-10-24"
---@field revenue number
---@field sales number

---@class Transaction
---@field id string
---@field time number Milliseconds
---@field buyer string
---@field productId string
---@field quantity integer
---@field total integer

---@class CashMovement
---@field id string
---@field time number Milliseconds
---@field type CashMovementType
---@field amount integer
---@field by string

---@class StockOrderItem
---@field productId string
---@field quantity integer

---@class StockOrder
---@field id string
---@field time number Milliseconds
---@field items StockOrderItem[]
---@field total integer
---@field status StockOrderStatus

---@class StaffMember
---@field id string
---@field name string
---@field hiredAt number Milliseconds
---@field lastOnline number? Milliseconds
---@field online boolean
---@field permissions string[]
