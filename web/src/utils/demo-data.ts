// Sample data for the website demo build (see utils/demo-nui.ts). Never used in game.
// Shaped like the server's answers (server/sv-main.lua, sv-owner.lua, sv-admin.lua); times are relative to now.

import type { Product, VendingData } from "@/stores";
import type { AdminData, Machine, MachineLocation } from "@/stores/admin";
import type { CashMovement, DailyRevenue, OwnerData, StaffMember, StockOrder, Transaction } from "@/stores/owner";
import type { UiConfig } from "./events";

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

/**
 * @param ms How long ago
 * @returns number Timestamp in milliseconds, like the server sends
 */
const ago = (ms: number) => Date.now() - ms;

/**
 * @param daysAgo
 * @returns string "2026-10-24", local date like os.date("%Y-%m-%d")
 */
function dayKey(daysAgo: number): string {
    const date = new Date(Date.now() - daysAgo * DAY);
    const pad = (value: number) => String(value).padStart(2, "0");

    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

// setConfig in game (client/cl-functions.lua UiConfig)
export const DEMO_CONFIG: UiConfig = {
    inventoryImagePath: "ox_inventory/web/images/",
    currency: "USD",
    locale: "en-US",
    debug: false,
};

// Config.Products, with the stock and price of the demo machine
export const DEMO_PRODUCTS: Product[] = [
    { id: "water", name: "Water", description: "500ml bottled water", category: "drinks", price: 5, stock: 24, image: "water.png" },
    { id: "cola", name: "eCola", description: "Classic fizzy cola", category: "drinks", price: 8, stock: 16, image: "cola.png" },
    { id: "sprunk", name: "Sprunk", description: "Lemon-lime soda", category: "drinks", price: 8, stock: 12, image: "sprunk.png" },
    { id: "coffee", name: "Coffee", description: "Hot black coffee", category: "drinks", price: 10, stock: 0, image: "coffee.png" },
    { id: "chips", name: "Chips", description: "Salted potato chips", category: "snacks", price: 6, stock: 19, image: "chips.png" },
    { id: "chocolate", name: "Chocolate", description: "Milk chocolate bar", category: "snacks", price: 7, stock: 4, image: "chocolate.png" },
    { id: "candy", name: "Candy", description: "Chewy candy bar", category: "snacks", price: 4, stock: 30, image: "candy.png" },
    { id: "sandwich", name: "Sandwich", description: "Ham and cheese sandwich", category: "food", price: 15, stock: 7, image: "sandwich.png" },
    { id: "donut", name: "Donut", description: "Glazed donut", category: "food", price: 9, stock: 11, image: "donut.png" },
];

/**
 * @returns Product[] Fresh copy, so purchases in one view don't leak into another
 */
export const demoProducts = (): Product[] => DEMO_PRODUCTS.map((product) => ({ ...product }));

// What the visitor "has on them" in the demo
export const DEMO_WALLET = { cash: 340, bank: 18450 };

/**
 * @returns VendingData vending:get-data
 */
export function demoVending(products: Product[]): VendingData {
    return {
        name: "Legion Square #1",
        products,
        payments: { cash: true, bank: true },
        wallet: { ...DEMO_WALLET },
    };
}

// Config.Products wholesale prices
export const DEMO_WHOLESALE: Record<string, number> = {
    water: 2, cola: 4, sprunk: 4, coffee: 5, chips: 3, chocolate: 3, candy: 2, sandwich: 8, donut: 4,
};

const BUYERS = ["John Carter", "Mia Lopez", "Ray Dawson", "Ava Brooks", "Leo Grant", "Nora Kim", "Sam Price", "Dylan Hayes", "Chloe Ward", "Marcus Bell"];

/**
 * Sales of the last two days, newest first
 * @returns Transaction[]
 */
function demoTransactions(): Transaction[] {
    const price = Object.fromEntries(DEMO_PRODUCTS.map((product) => [product.id, product.price]));
    const pattern: [string, number][] = [
        ["cola", 2], ["sandwich", 1], ["water", 3], ["chips", 2], ["donut", 2], ["chocolate", 1], ["sprunk", 4], ["candy", 5],
        ["water", 2], ["cola", 1], ["sandwich", 2], ["chips", 1], ["coffee", 2], ["sprunk", 2], ["chocolate", 3], ["donut", 1],
        ["water", 1], ["candy", 3], ["cola", 3], ["chips", 2], ["sandwich", 1], ["water", 4], ["coffee", 1], ["sprunk", 1],
        ["donut", 2], ["chocolate", 2], ["cola", 2], ["water", 2], ["candy", 4], ["chips", 1],
    ];

    let minutesAgo = 4;

    return pattern.map(([productId, quantity], index) => {
        // Busy in the evening, a gap overnight
        minutesAgo += index === 13 ? 9 * 60 : 18 + ((index * 17) % 31);

        return {
            id: `t${pattern.length - index}`,
            time: ago(minutesAgo * MINUTE),
            buyer: BUYERS[(index * 7) % BUYERS.length]!,
            productId,
            quantity,
            total: price[productId]! * quantity,
        };
    });
}

/**
 * @returns DailyRevenue[] Last 7 days, oldest first
 */
function demoRevenue(): DailyRevenue[] {
    const days: [number, number][] = [[412, 51], [386, 47], [521, 63], [468, 55], [604, 72], [579, 69], [655, 78]];

    return days.map(([revenue, sales], index) => ({ date: dayKey(days.length - 1 - index), revenue, sales }));
}

/**
 * @returns CashMovement[] Newest first
 */
function demoCashMovements(): CashMovement[] {
    return [
        { id: "c8", time: ago(40 * MINUTE), type: "order", amount: 105, by: "You" },
        { id: "c7", time: ago(5 * HOUR), type: "withdraw", amount: 1500, by: "You" },
        { id: "c6", time: ago(DAY + 3 * HOUR), type: "deposit", amount: 500, by: "Mia Lopez" },
        { id: "c5", time: ago(DAY + 9 * HOUR), type: "order", amount: 100, by: "Mia Lopez" },
        { id: "c4", time: ago(2 * DAY + 4 * HOUR), type: "withdraw", amount: 2000, by: "You" },
        { id: "c3", time: ago(3 * DAY + 2 * HOUR), type: "order", amount: 80, by: "You" },
        { id: "c2", time: ago(4 * DAY + 6 * HOUR), type: "deposit", amount: 250, by: "You" },
        { id: "c1", time: ago(6 * DAY + 5 * HOUR), type: "deposit", amount: 1000, by: "You" },
    ];
}

/**
 * The newest order is ready at the supplier, so the visitor can pick it up
 * @returns StockOrder[] Newest first
 */
function demoOrders(): StockOrder[] {
    return [
        { id: "o5", time: ago(40 * MINUTE), items: [{ productId: "coffee", quantity: 15 }, { productId: "chocolate", quantity: 10 }], total: 105, status: "prepared" },
        { id: "o4", time: ago(DAY + 9 * HOUR), items: [{ productId: "water", quantity: 20 }, { productId: "cola", quantity: 15 }], total: 100, status: "completed" },
        { id: "o3", time: ago(3 * DAY + 2 * HOUR), items: [{ productId: "sandwich", quantity: 10 }], total: 80, status: "completed" },
        { id: "o2", time: ago(4 * DAY + 7 * HOUR), items: [{ productId: "donut", quantity: 15 }], total: 60, status: "cancelled" },
        { id: "o1", time: ago(5 * DAY + 3 * HOUR), items: [{ productId: "chips", quantity: 25 }, { productId: "candy", quantity: 30 }], total: 135, status: "completed" },
    ];
}

/**
 * @returns StaffMember[] Newest hire first
 */
function demoStaff(): StaffMember[] {
    return [
        { id: "st3", name: "Nora Kim", hiredAt: ago(DAY + 5 * HOUR), lastOnline: null, online: false, permissions: ["restock.order", "transactions.view"] },
        { id: "st2", name: "Ray Dawson", hiredAt: ago(3 * DAY + 4 * HOUR), lastOnline: ago(9 * HOUR), online: false, permissions: ["dashboard.view", "products.prices", "restock.order", "transactions.view", "cash.deposit", "cash.history", "staff.view"] },
        { id: "st1", name: "Mia Lopez", hiredAt: ago(5 * DAY + 2 * HOUR), lastOnline: ago(25 * MINUTE), online: true, permissions: ["dashboard.view", "products.prices", "restock.order", "transactions.view", "cash.deposit", "cash.withdraw", "cash.history", "staff.view", "staff.manage", "settings.general", "settings.hours", "settings.stock", "settings.payments"] },
    ];
}

/**
 * @returns OwnerData owner:get-data, the visitor is the machine's owner
 */
export function demoOwner(products: Product[]): OwnerData {
    return {
        access: { owner: true, permissions: [] },
        settings: {
            name: "Legion Square #1",
            description: "Cold drinks and quick snacks, open around the clock.",
            open: true,
            schedule: { enabled: false, opensAt: "08:00", closesAt: "22:00" },
            lowStockThreshold: 5,
            autoRestock: false,
            notifyLowStock: true,
            notifySales: false,
            payments: { cash: true, bank: true },
        },
        balance: 3625,
        wallet: DEMO_WALLET.cash,
        capacity: 50,
        products,
        revenue: demoRevenue(),
        transactions: demoTransactions(),
        unitsSold: { water: 96, cola: 84, sprunk: 61, coffee: 22, chips: 73, chocolate: 48, candy: 57, sandwich: 39, donut: 33 },
        cashMovements: demoCashMovements(),
        wholesale: { ...DEMO_WHOLESALE },
        orders: demoOrders(),
        staff: demoStaff(),
        ownerMember: { name: "Alex Turner", online: true },
        selfId: "owner",
    };
}

// Server ids of players "near" the machine, for hiring, transfers and new machines
export const DEMO_PLAYERS: Record<number, string> = {
    7: "Jordan Reyes",
    12: "Ethan Cole",
    23: "Sofia Martinez",
    31: "Liam Foster",
    56: "Nora Kim",
    87: "Mia Lopez",
    142: "Alex Turner",
    203: "Ray Dawson",
    311: "Leo Grant",
};

const location = (label: string, x: number, y: number, z: number, heading = 0): MachineLocation => ({ label, x, y, z, heading });

const ALL = DEMO_PRODUCTS.map((product) => product.id);

/**
 * @returns Machine[] Newest first, like the server's list
 */
function demoMachines(): Machine[] {
    const machine = (id: string, colorSlot: number, name: string, model: string, where: MachineLocation, ownerId: string, extra: Partial<Machine>): Machine => ({
        id,
        colorSlot,
        name,
        model,
        location: where,
        ownerId,
        ownerName: ownerId ? DEMO_PLAYERS[Number(ownerId)] ?? null : null,
        forSale: !ownerId,
        price: 20000,
        capacity: 50,
        products: ALL,
        status: ownerId ? "open" : "closed",
        balance: 0,
        revenue: 0,
        sales: 0,
        stockLevel: 0,
        createdAt: Date.now(),
        ...extra,
    });

    return [
        machine("m9", 0, "Del Perro Pier", "olentrix_vend_sprunk", location("Del Perro", -1638.2, -1068.4, 13.1, 140), "", { price: 22000, products: ["water", "sprunk", "cola", "candy"], createdAt: ago(DAY + 4 * HOUR) }),
        machine("m8", 6, "Maze Bank Tower", "prop_vend_coffe_01", location("Pillbox Hill", -75.2, -818.6, 326.2, 160), "142", { price: 35000, products: ["coffee", "water", "chocolate", "donut"], balance: 2760, revenue: 5230, sales: 498, stockLevel: 81, createdAt: ago(3 * DAY) }),
        machine("m7", 5, "Paleto Bay Market", "prop_vend_snak_01", location("Paleto Bay", -324.8, 6066.9, 31.5, 45), "311", { price: 16000, capacity: 40, products: ["chips", "sandwich", "water"], status: "disabled", balance: 415, revenue: 920, sales: 117, stockLevel: 35, createdAt: ago(6 * DAY) }),
        machine("m6", 4, "Sandy Shores Gas", "prop_vend_soda_01", location("Sandy Shores", 1961.5, 3740.1, 32.3, 300), "", { price: 15000, capacity: 30, products: ["water", "cola", "chips"], createdAt: ago(9 * DAY) }),
        machine("m5", 7, "Vinewood Bowl", "olentrix_vend_ecola", location("Vinewood", 689.4, 595.2, 129.0, 70), "23", { price: 26000, products: ["cola", "water", "chips", "candy", "chocolate"], balance: 1240, revenue: 2860, sales: 352, stockLevel: 22, createdAt: ago(12 * DAY) }),
        machine("m4", 3, "Mission Row PD", "prop_vend_snak_01", location("Mission Row", 441.2, -981.9, 30.7, 90), "56", { price: 28000, products: ["chips", "chocolate", "candy", "donut", "coffee"], balance: 1980, revenue: 3410, sales: 398, stockLevel: 63, createdAt: ago(16 * DAY) }),
        machine("m3", 2, "Vespucci Beach", "prop_vend_water_01", location("Vespucci Beach", -1223.6, -1491.4, 4.4, 215), "203", { price: 18000, products: ["water", "sprunk", "cola", "candy"], status: "closed", balance: 860, revenue: 1720, sales: 241, stockLevel: 18, createdAt: ago(21 * DAY) }),
        machine("m2", 1, "Pillbox Hospital", "prop_vend_coffe_01", location("Pillbox Hill", 307.1, -595.8, 43.3, 70), "87", { price: 30000, capacity: 40, products: ["coffee", "water", "donut", "sandwich"], balance: 2140, revenue: 4980, sales: 512, stockLevel: 74, createdAt: ago(24 * DAY) }),
        machine("m1", 0, "Legion Square #1", "prop_vend_soda_01", location("Legion Square", 195.4, -933.2, 30.7, 340), "142", { price: 25000, balance: 3625, revenue: 3625, sales: 435, stockLevel: 52, createdAt: ago(27 * DAY) }),
    ];
}

/**
 * @returns AdminData admin:get-data
 */
export function demoAdmin(): AdminData {
    const revenue = [2410, 2280, 2895, 2640, 3120, 2985, 3550];

    return {
        machines: demoMachines(),
        revenue: revenue.map((value, index) => ({ date: dayKey(revenue.length - 1 - index), revenue: value })),
        settings: {
            wholesaleMultiplier: 1,
            salesTax: 8,
            maxMachinesPerPlayer: 3,
            deliveryMinutes: 5,
            defaultCapacity: 50,
            defaultPrice: 20000,
            allowPlayerPurchase: true,
            webhook: "",
            logPurchases: true,
            logAdminActions: true,
        },
        products: demoProducts(),
        customMachines: true,
    };
}
