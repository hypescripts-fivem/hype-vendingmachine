---@meta

---@alias MachineStatus "open" | "closed" | "disabled"
---@alias StockOrderStatus "preparing" | "prepared" | "shipping" | "completed" | "cancelled"
---@alias CashMovementType "deposit" | "withdraw" | "order"
---@alias View "vending" | "purchase" | "owner" | "admin" | "screen"
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
---@field model? string Prop shown on the shelves of machines with an arm

---@class MachineModel A Config.Machines entry
---@field label string
---@field value string Prop model
---@field arm? boolean An olentrix_vending machine: stock is shown on its shelves and the arm vends each unit

---@class MachineStock
---@field item string
---@field stock integer

---@class SaleLine One product of a checkout
---@field item string
---@field quantity integer
---@field total integer
---@field stockBefore integer

---@class PendingVend A paid-for checkout on an arm machine, waiting for the buyer's arm to drop it
---@field playerId integer
---@field row MachineRow
---@field lines SaleLine[] Stock is already reserved
---@field account PaymentMethod
---@field total integer Taken when the buyer collects

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
---@field products MachineStock[] In Config.Products order, the order the shelves are filled in

---@class MachineEntry Client-side state of one machine
---@field data MachineProp
---@field point table ox_lib point that spawns the prop
---@field textPoint? table ox_lib point for the TextUI, only without a target resource
---@field entity? integer
---@field inside boolean
---@field shelf? Shelf Only on arm machines while the prop is spawned
---@field hidden? boolean Taken away while an admin places its ghost

---@class PlacementState The ghost machine an admin is placing
---@field ghost integer
---@field machineId? integer The machine being moved, when editing
---@field cursor boolean The gizmo has the mouse; off while the admin looks around

---@class ScreenCorners Offsets from the machine prop to the corners of its screen
---@field topLeft vector3
---@field topRight vector3
---@field bottomLeft vector3

---@class ScreenCamera
---@field offset vector3 From the machine prop
---@field fov number

---@class ScreenConfig Config.Screen: arm machines open their own screen instead of the menu
---@field texture string Screen texture in the model, its dictionary is the model name
---@field width integer DUI size in pixels
---@field height integer
---@field camera ScreenCamera
---@field corners ScreenCorners

---@class ScreenState The machine screen this player is using
---@field machineId integer
---@field entity integer
---@field cam integer
---@field pressed boolean The left button went down on the screen and hasn't been released yet
---@field position vector3 The camera, in the world
---@field forward vector3 Where the camera looks, unit length
---@field right vector3
---@field up vector3
---@field topLeft vector3 The screen's corners, in the world
---@field topRight vector3
---@field bottomLeft vector3

---@class UiConfig What the UI needs from the config
---@field inventoryImagePath string
---@field currency string
---@field locale string
---@field debug boolean

---@class ShelfLane One product's lane in an arm machine
---@field slot string olentrix_vending slot, "A1" to "E4"
---@field model integer
---@field front vector3 Offset from the machine of the front position
---@field lift number Raises the prop so its bottom sits on the belt
---@field pitch number Distance between two props in the lane
---@field capacity integer Props that fit in the lane
---@field entities integer[] Front to back

---@class VendStep
---@field vendId integer
---@field item? string A unit for the arm to vend
---@field collect? boolean The buyer's last step: asks the server for the items

---@class Shelf
---@field key string The products the lanes were built for
---@field lanes table<string, ShelfLane> By item
---@field queue VendStep[]
---@field pending table<string, integer> Units sold but not vended yet, still shown in their lane
---@field vending boolean

---@class CargoBox One box on the cart: an order line
---@field item string
---@field quantity integer

---@class CargoJob Server-side state of a player's order pickup
---@field orderId integer
---@field machineId integer
---@field boxes CargoBox[] Delivered in this order
---@field loaded integer Boxes put in a vehicle straight from the cart
---@field delivered integer
---@field shipping boolean The cart was grabbed, the order is `shipping`
---@field props integer[] Net ids of the client's cart and boxes

---@class CargoState Client-side state of the pickup
---@field spawn vector4
---@field arrived boolean The player reached the spawn and the cart was put there
---@field cart? integer Spawned on arrival, gone once it's brought back or left behind
---@field cartBoxes integer[] Boxes still on the cart
---@field carrying? integer Box in the player's hands
---@field fromCart boolean The carried box came from the cart, not out of the vehicle
---@field holding boolean Holding the cart
---@field vehicle? integer Bound by the first box loaded
---@field inVehicle integer
---@field total integer
---@field loaded integer
---@field delivered integer

---@class CargoOption
---@field label string
---@field icon? string
---@field canInteract fun(): boolean
---@field onSelect fun()

---@class CargoPoint Something the player uses during the pickup: an entity, or a position
---@field entity? integer
---@field coords? vector3 Used instead of an entity
---@field offset? vector3 From the entity, where the option is
---@field bones? string[] Entity bones the option is on, e.g. a vehicle's "boot"; the TextUI uses the nearest
---@field options CargoOption[] TextUI: the first takes the primary key, the second the secondary

---@class CargoAttach
---@field bone integer Ped bone id
---@field offset vector3
---@field rotation vector3

---@class CargoAnim
---@field dict string
---@field name string
---@field time? number 0-1, held still at this point of the animation instead of playing it

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

---@class StockOrderLine One product of a stock order being placed
---@field item string
---@field quantity integer
---@field unitPrice integer Wholesale price per unit

---@class GameTime The in-game time, from hype-core's GetGameTime
---@field hour integer
---@field minute integer

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
