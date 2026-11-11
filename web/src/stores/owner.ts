import { defineStore } from "pinia";
import { computed, ref } from "vue";
import { asList, asNumber, asRecord, FetchNUI, isNative } from "@/utils";
import { mockTime } from "@/utils/format";
import { t } from "@/utils/locale";
import { mockProducts, useShopStore, type Product } from "@/stores";

export type OwnerSection = 'dashboard' | 'products' | 'restock' | 'transactions' | 'cash' | 'staff' | 'settings';

// `section.action`, grouped by owner panel section. Labels live in components/owner/permissions.ts
export const staffPermissions = [
    'dashboard.view',
    'products.prices',
    'restock.order',
    'transactions.view',
    'cash.deposit',
    'cash.withdraw',
    'cash.history',
    'staff.view',
    'staff.manage',
    'settings.general',
    'settings.hours',
    'settings.stock',
    'settings.payments',
] as const;

export type StaffPermission = typeof staffPermissions[number];

export type StaffRole = 'employee' | 'supervisor' | 'manager';

// Permission presets. Each set must be unique so a member's role can be read back from their permissions
export const staffRoles: { value: StaffRole; label: string; permissions: StaffPermission[] }[] = [
    { value: 'employee', label: 'owner.roles.employee', permissions: ['restock.order', 'transactions.view'] },
    {
        value: 'supervisor',
        label: 'owner.roles.supervisor',
        permissions: ['dashboard.view', 'products.prices', 'restock.order', 'transactions.view', 'cash.deposit', 'cash.history', 'staff.view'],
    },
    { value: 'manager', label: 'owner.roles.manager', permissions: [...staffPermissions] },
];

// undefined means the permissions were picked by hand and match no preset
export interface OwnerAccess {
    // The owner sees everything; staff only what `permissions` allows
    owner: boolean;
    permissions: StaffPermission[];
};

// Outside FiveM, ?role=employee|supervisor|manager previews the panel as that staff role
function previewAccess(): OwnerAccess {
    const role = staffRoles.find((entry) => entry.value === new URLSearchParams(window.location.search).get("role"));
    return role ? { owner: false, permissions: [...role.permissions] } : { owner: true, permissions: [] };
};

export function staffRoleOf(permissions: StaffPermission[]): StaffRole | undefined {
    const key = staffPermissions.filter((permission) => permissions.includes(permission)).join();
    return staffRoles.find((role) => role.permissions.join() === key)?.value;
};

export interface StaffMember {
    id: string;
    name: string;
    // Timestamps in milliseconds
    hiredAt: number;
    // Last time they opened this panel. null until they open it once
    lastOnline: number | null;
    // Connected to the server right now. Kept live by the setStaffOnline NUI message
    online: boolean;
    permissions: StaffPermission[];
};

export type CashMovementType = 'deposit' | 'withdraw' | 'order';

export interface StockOrderItem {
    productId: string;
    quantity: number;
};

export type StockOrderStatus = 'preparing' | 'prepared' | 'shipping' | 'completed' | 'cancelled';

// The steps an order goes through; `cancelled` ends it early (the player left the pickup area)
export const orderStatuses: StockOrderStatus[] = ['preparing', 'prepared', 'shipping', 'completed'];

export interface StockOrder {
    id: string;
    // Milliseconds
    time: number;
    items: StockOrderItem[];
    total: number;
    status: StockOrderStatus;
};

export interface CashMovement {
    id: string;
    // Milliseconds
    time: number;
    type: CashMovementType;
    amount: number;
    by: string;
};

export interface DailyRevenue {
    // "2026-10-24"
    date: string;
    revenue: number;
    sales: number;
};

export interface Transaction {
    id: string;
    // Milliseconds
    time: number;
    buyer: string;
    productId: string;
    quantity: number;
    total: number;
};

const mockRevenue: DailyRevenue[] = [
    { date: "2026-10-18", revenue: 412, sales: 51 },
    { date: "2026-10-19", revenue: 386, sales: 47 },
    { date: "2026-10-20", revenue: 521, sales: 63 },
    { date: "2026-10-21", revenue: 468, sales: 55 },
    { date: "2026-10-22", revenue: 604, sales: 72 },
    { date: "2026-10-23", revenue: 579, sales: 69 },
    { date: "2026-10-24", revenue: 655, sales: 78 },
];

const mockTransactions: Transaction[] = [
    { id: "t12", time: mockTime("Oct 24 21:42"), buyer: "John Carter", productId: "cola", quantity: 2, total: 16 },
    { id: "t11", time: mockTime("Oct 24 21:15"), buyer: "Mia Lopez", productId: "sandwich", quantity: 1, total: 15 },
    { id: "t10", time: mockTime("Oct 24 20:58"), buyer: "Ray Dawson", productId: "water", quantity: 3, total: 15 },
    { id: "t9", time: mockTime("Oct 24 20:31"), buyer: "Ava Brooks", productId: "chips", quantity: 2, total: 12 },
    { id: "t8", time: mockTime("Oct 24 19:47"), buyer: "Leo Grant", productId: "donut", quantity: 2, total: 18 },
    { id: "t7", time: mockTime("Oct 24 19:02"), buyer: "John Carter", productId: "chocolate", quantity: 1, total: 7 },
    { id: "t6", time: mockTime("Oct 24 18:26"), buyer: "Nora Kim", productId: "sprunk", quantity: 4, total: 32 },
    { id: "t5", time: mockTime("Oct 24 17:53"), buyer: "Mia Lopez", productId: "candy", quantity: 5, total: 20 },
    { id: "t4", time: mockTime("Oct 24 17:10"), buyer: "Sam Price", productId: "water", quantity: 2, total: 10 },
    { id: "t3", time: mockTime("Oct 24 16:44"), buyer: "Ava Brooks", productId: "cola", quantity: 1, total: 8 },
    { id: "t2", time: mockTime("Oct 24 16:05"), buyer: "Ray Dawson", productId: "sandwich", quantity: 2, total: 30 },
    { id: "t1", time: mockTime("Oct 24 15:37"), buyer: "Leo Grant", productId: "chips", quantity: 1, total: 6 },
    { id: "s18", time: mockTime("Oct 23 22:48"), buyer: "Nora Kim", productId: "water", quantity: 2, total: 10 },
    { id: "s17", time: mockTime("Oct 23 22:10"), buyer: "Sam Price", productId: "donut", quantity: 1, total: 9 },
    { id: "s16", time: mockTime("Oct 23 21:37"), buyer: "John Carter", productId: "sprunk", quantity: 2, total: 16 },
    { id: "s15", time: mockTime("Oct 23 21:02"), buyer: "Ava Brooks", productId: "chocolate", quantity: 3, total: 21 },
    { id: "s14", time: mockTime("Oct 23 20:29"), buyer: "Leo Grant", productId: "cola", quantity: 1, total: 8 },
    { id: "s13", time: mockTime("Oct 23 19:55"), buyer: "Mia Lopez", productId: "chips", quantity: 2, total: 12 },
    { id: "s12", time: mockTime("Oct 23 19:14"), buyer: "Ray Dawson", productId: "candy", quantity: 4, total: 16 },
    { id: "s11", time: mockTime("Oct 23 18:40"), buyer: "Nora Kim", productId: "sandwich", quantity: 1, total: 15 },
    { id: "s10", time: mockTime("Oct 23 18:03"), buyer: "Sam Price", productId: "water", quantity: 1, total: 5 },
    { id: "s9", time: mockTime("Oct 23 17:26"), buyer: "John Carter", productId: "donut", quantity: 2, total: 18 },
    { id: "s8", time: mockTime("Oct 23 16:51"), buyer: "Ava Brooks", productId: "cola", quantity: 3, total: 24 },
    { id: "s7", time: mockTime("Oct 23 16:12"), buyer: "Leo Grant", productId: "sprunk", quantity: 1, total: 8 },
    { id: "s6", time: mockTime("Oct 23 15:38"), buyer: "Mia Lopez", productId: "chocolate", quantity: 2, total: 14 },
    { id: "s5", time: mockTime("Oct 23 14:57"), buyer: "Ray Dawson", productId: "chips", quantity: 1, total: 6 },
    { id: "s4", time: mockTime("Oct 23 14:20"), buyer: "Nora Kim", productId: "candy", quantity: 3, total: 12 },
    { id: "s3", time: mockTime("Oct 23 13:44"), buyer: "Sam Price", productId: "sandwich", quantity: 2, total: 30 },
    { id: "s2", time: mockTime("Oct 23 13:05"), buyer: "John Carter", productId: "water", quantity: 4, total: 20 },
    { id: "s1", time: mockTime("Oct 23 12:31"), buyer: "Ava Brooks", productId: "cola", quantity: 2, total: 16 },
];

const mockCashMovements: CashMovement[] = [
    { id: "c6", time: mockTime("Oct 24 14:10"), type: "withdraw", amount: 1500, by: "You" },
    { id: "c5", time: mockTime("Oct 23 22:35"), type: "deposit", amount: 500, by: "You" },
    { id: "c4", time: mockTime("Oct 22 19:02"), type: "withdraw", amount: 2000, by: "You" },
    { id: "c3", time: mockTime("Oct 21 11:48"), type: "deposit", amount: 250, by: "You" },
    { id: "c2", time: mockTime("Oct 20 09:15"), type: "withdraw", amount: 1200, by: "You" },
    { id: "c1", time: mockTime("Oct 18 16:30"), type: "deposit", amount: 1000, by: "You" },
];

const mockUnitsSold: Record<string, number> = {
    water: 96, cola: 84, sprunk: 61, coffee: 22, chips: 73, chocolate: 48, candy: 57, sandwich: 39, donut: 33,
};

// What the owner pays the supplier per unit
const mockWholesale: Record<string, number> = {
    water: 2, cola: 4, sprunk: 4, coffee: 5, chips: 3, chocolate: 3, candy: 2, sandwich: 8, donut: 4,
};

const mockOrders: StockOrder[] = [
    { id: "o4", time: mockTime("Oct 24 13:40"), items: [{ productId: "donut", quantity: 15 }, { productId: "coffee", quantity: 20 }], total: 160, status: "shipping" },
    { id: "o3", time: mockTime("Oct 23 10:20"), items: [{ productId: "water", quantity: 20 }, { productId: "cola", quantity: 15 }], total: 100, status: "completed" },
    { id: "o2", time: mockTime("Oct 21 09:45"), items: [{ productId: "sandwich", quantity: 10 }], total: 80, status: "completed" },
    { id: "o1", time: mockTime("Oct 19 12:05"), items: [{ productId: "chips", quantity: 25 }, { productId: "candy", quantity: 30 }], total: 135, status: "completed" },
];

const mockStaff: StaffMember[] = [
    { id: "st3", name: "Nora Kim", hiredAt: mockTime("Oct 23 09:30"), lastOnline: null, online: false, permissions: ["restock.order", "cash.deposit", "cash.withdraw"] },
    { id: "st2", name: "Ray Dawson", hiredAt: mockTime("Oct 21 10:12"), lastOnline: mockTime("Oct 22 17:05"), online: false, permissions: ["restock.order", "transactions.view"] },
    { id: "st1", name: "Mia Lopez", hiredAt: mockTime("Oct 19 18:40"), lastOnline: mockTime("Oct 24 20:48"), online: true, permissions: [...staffPermissions] },
];

export interface OwnerSettings {
    name: string;
    description: string;
    open: boolean;
    // In-game times as "HH:MM", 24 hour
    schedule: { enabled: boolean; opensAt: string; closesAt: string };
    lowStockThreshold: number;
    autoRestock: boolean;
    notifyLowStock: boolean;
    notifySales: boolean;
    payments: { cash: boolean; bank: boolean };
};

const mockSettings: OwnerSettings = {
    name: "Legion Square #1",
    description: "Cold drinks and quick snacks, open around the clock.",
    open: true,
    schedule: { enabled: false, opensAt: "08:00", closesAt: "22:00" },
    lowStockThreshold: 5,
    autoRestock: false,
    notifyLowStock: true,
    notifySales: false,
    payments: { cash: true, bank: true },
};

const blankSettings: OwnerSettings = {
    name: "",
    description: "",
    open: false,
    schedule: { enabled: false, opensAt: "08:00", closesAt: "22:00" },
    lowStockThreshold: 5,
    autoRestock: false,
    notifyLowStock: false,
    notifySales: false,
    payments: { cash: true, bank: true },
};

// Everything the panel shows, sent by owner:get-data when it opens
export interface OwnerData {
    access: OwnerAccess;
    settings: OwnerSettings;
    balance: number;
    // The viewer's own money in the account deposits come from, for the Deposit tab's "All"
    wallet: number;
    // Max units of each product the machine holds
    capacity: number;
    products: Product[];
    // Last 7 days, oldest first
    revenue: DailyRevenue[];
    // Newest first, like the lists below
    transactions: Transaction[];
    unitsSold: Record<string, number>;
    cashMovements: CashMovement[];
    wholesale: Record<string, number>;
    orders: StockOrder[];
    staff: StaffMember[];
    // The machine's owner, shown above the staff. Not a StaffMember: can't be edited or fired
    ownerMember: OwnerMember | null;
    // Who is looking at the panel: "owner", or their staff member id
    selfId: string | null;
};

export interface OwnerMember {
    name: string;
    online: boolean;
};

const mockData = (): OwnerData => ({
    access: previewAccess(),
    settings: mockSettings,
    balance: 3625,
    wallet: 5200,
    capacity: 50,
    products: mockProducts,
    revenue: mockRevenue,
    transactions: mockTransactions,
    unitsSold: mockUnitsSold,
    cashMovements: mockCashMovements,
    wholesale: mockWholesale,
    orders: mockOrders,
    staff: mockStaff,
    ownerMember: { name: "Alex Turner", online: true },
    selfId: "owner",
});

export const useOwnerStore = defineStore("owner", () => {
    const shop = useShopStore();

    const section = ref<OwnerSection>('dashboard');
    // Nothing is shown until owner:get-data (or a setAccess message) says what the viewer may see
    const access = ref<OwnerAccess>({ owner: false, permissions: [] });

    // UI only: hides what the viewer can't use. The server must check every callback itself
    function can(permission: StaffPermission): boolean {
        return access.value.owner || access.value.permissions.includes(permission);
    };

    function canSection(target: OwnerSection): boolean {
        return access.value.owner || access.value.permissions.some((permission) => permission.startsWith(`${target}.`));
    };

    function setAccess(next: { owner?: unknown; permissions?: unknown }) {
        const granted = Array.isArray(next?.permissions) ? next.permissions : [];

        access.value = {
            owner: next?.owner === true,
            permissions: staffPermissions.filter((permission) => granted.includes(permission)),
        };
    };
    const settings = ref<OwnerSettings>(blankSettings);
    const balance = ref(0);
    const wallet = ref(0);
    const capacity = ref(50);
    const revenue = ref<DailyRevenue[]>([]);
    const transactions = ref<Transaction[]>([]);
    const unitsSold = ref<Record<string, number>>({});
    const cashMovements = ref<CashMovement[]>([]);
    const wholesale = ref<Record<string, number>>({});
    const orders = ref<StockOrder[]>([]);
    const staff = ref<StaffMember[]>([]);
    const ownerMember = ref<OwnerMember | null>(null);
    const selfId = ref<string | null>(null);
    const saving = ref(false);
    const cashBusy = ref(false);
    const ordering = ref(false);

    const weekRevenue = computed(() => revenue.value.reduce((sum, day) => sum + day.revenue, 0));
    const weekSales = computed(() => revenue.value.reduce((sum, day) => sum + day.sales, 0));
    const todayRevenue = computed(() => revenue.value.at(-1)?.revenue ?? 0);

    const revenueChange = computed(() => {
        const [previous, today] = [revenue.value.at(-2)?.revenue, revenue.value.at(-1)?.revenue];
        if (!previous || today === undefined) return undefined;
        return Math.round(((today - previous) / previous) * 1000) / 10;
    });

    const lowStock = computed(() => shop.products.filter((product) => isLowStock(product.stock)));

    function isLowStock(stock: number): boolean {
        return stock <= settings.value.lowStockThreshold;
    };

    const topProducts = computed(() =>
        shop.products
            .map((product) => ({ product, units: unitsSold.value[product.id] ?? 0 }))
            .sort((a, b) => b.units - a.units)
            .slice(0, 5)
    );

    function productName(productId: string): string {
        return shop.products.find((product) => product.id === productId)?.name ?? productId;
    };

    async function updatePrice(productId: string, price: number) {
        const product = shop.products.find((entry) => entry.id === productId);
        if (!product) return;

        const response = await FetchNUI("owner:update-price", { id: productId, price });
        if (response.success) product.price = price;

        return response;
    };

    function orderTotal(items: StockOrderItem[]): number {
        return items.reduce((sum, item) => sum + (wholesale.value[item.productId] ?? 0) * item.quantity, 0);
    };

    const activeOrders = computed(() => orders.value.filter((order) => order.status !== "completed" && order.status !== "cancelled"));

    // Units already ordered but not delivered yet, so they still count against capacity
    const incoming = computed(() => {
        const result: Record<string, number> = {};

        for (const order of activeOrders.value) {
            for (const item of order.items) {
                result[item.productId] = (result[item.productId] ?? 0) + item.quantity;
            }
        }

        return result;
    });

    // Paid from the machine balance up front; stock only lands once the warehouse completes the order.
    // The server must re-check prices, capacity and balance.
    async function orderStock(items: StockOrderItem[]) {
        const order = items.filter((item) => item.quantity > 0);
        const total = orderTotal(order);

        if (ordering.value || !order.length || total > balance.value) return;

        ordering.value = true;

        try {
            const response = await FetchNUI<{ balance?: number; orderId?: string }>("owner:order-stock", { items: order });

            if (response.success) {
                balance.value = response.data?.balance ?? balance.value - total;

                const id = response.data?.orderId ?? `o${Date.now()}`;
                const time = Date.now();

                orders.value.unshift({ id, time, items: order, total, status: "preparing" });
                cashMovements.value.unshift({ id: `c${Date.now()}`, time, type: "order", amount: total, by: t("owner.cash.by_you") });

                if (!isNative) simulateDelivery(id);
            }

            return response;
        } finally {
            ordering.value = false;
        }
    };

    // Driven by the server in game (setOrderStatus NUI message). The stock itself is added by the server, box by box
    function setOrderStatus(orderId: string, status: StockOrderStatus) {
        const order = activeOrders.value.find((entry) => entry.id === orderId);
        if (!order || (!orderStatuses.includes(status) && status !== "cancelled")) return;

        order.status = status;
    };

    // In game the client closes the panel and spawns the cart
    async function pickupOrder(orderId: string) {
        return FetchNUI("owner:pickup-order", { id: orderId });
    };

    // Browser-only stand-in for the warehouse so the flow can be previewed without FiveM
    function simulateDelivery(orderId: string, stepMs = 6000) {
        const advance = () => {
            const order = orders.value.find((entry) => entry.id === orderId);
            if (!order || order.status === "completed") return;

            setOrderStatus(orderId, orderStatuses[orderStatuses.indexOf(order.status) + 1]!);
            setTimeout(advance, stepMs);
        };

        setTimeout(advance, stepMs);
    };

    // Fresh copies, so edits made in the browser preview don't leak into the mock data
    async function load() {
        const response = await FetchNUI<OwnerData>("owner:get-data", {}, JSON.parse(JSON.stringify(mockData())));
        const data = response.data;

        if (response.success && data) {
            setAccess(asRecord<OwnerAccess>(data.access));
            settings.value = { ...blankSettings, ...asRecord<OwnerSettings>(data.settings) };
            balance.value = asNumber(data.balance);
            wallet.value = asNumber(data.wallet);
            capacity.value = asNumber(data.capacity, 50);
            shop.products = asList(data.products);
            revenue.value = asList(data.revenue);
            transactions.value = asList(data.transactions);
            unitsSold.value = asRecord<Record<string, number>>(data.unitsSold) as Record<string, number>;
            cashMovements.value = asList(data.cashMovements);
            wholesale.value = asRecord<Record<string, number>>(data.wholesale) as Record<string, number>;
            orders.value = asList(data.orders);
            staff.value = asList(data.staff);
            ownerMember.value = typeof data.ownerMember?.name === "string" ? data.ownerMember : null;
            selfId.value = typeof data.selfId === "string" ? data.selfId : null;

            if (!isNative) {
                for (const order of activeOrders.value) simulateDelivery(order.id);
            }
        }

        return response;
    };

    const totalDeposited = computed(() => cashMovements.value
        .filter((movement) => movement.type === "deposit")
        .reduce((sum, movement) => sum + movement.amount, 0));

    const totalWithdrawn = computed(() => cashMovements.value
        .filter((movement) => movement.type === "withdraw")
        .reduce((sum, movement) => sum + movement.amount, 0));

    // UI-side checks only improve feedback; the server must re-check the balance and the player's cash
    async function moveCash(type: CashMovementType, amount: number) {
        if (cashBusy.value || amount < 1) return;
        if (type === "withdraw" && amount > balance.value) return;
        if (type === "deposit" && amount > wallet.value) return;

        cashBusy.value = true;

        try {
            const response = await FetchNUI<{ balance?: number; wallet?: number }>(`owner:${type}`, { amount });

            if (response.success) {
                balance.value = response.data?.balance ?? balance.value + (type === "deposit" ? amount : -amount);
                wallet.value = response.data?.wallet ?? wallet.value + (type === "deposit" ? -amount : amount);

                cashMovements.value.unshift({
                    id: `c${Date.now()}`,
                    time: Date.now(),
                    type,
                    amount,
                    by: t("owner.cash.by_you"),
                });
            }

            return response;
        } finally {
            cashBusy.value = false;
        }
    };

    async function saveSettings(next: OwnerSettings) {
        saving.value = true;

        try {
            const response = await FetchNUI("owner:save-settings", next);
            // JSON copy: structuredClone throws on Vue proxies
            if (response.success) settings.value = JSON.parse(JSON.stringify(next));

            return response;
        } finally {
            saving.value = false;
        }
    };

    // The server resolves the player, checks they're nearby and not already staff, and sends back the member
    async function hireStaff(playerId: number, permissions: StaffPermission[]) {
        const response = await FetchNUI<{ member?: StaffMember }>("owner:hire-staff", { playerId, permissions });

        if (response.success) {
            staff.value.unshift(response.data?.member ?? {
                id: `st${Date.now()}`,
                name: t("owner.staff.player_fallback", playerId),
                hiredAt: Date.now(),
                lastOnline: null,
                // Hiring needs the player nearby, so they're online
                online: true,
                permissions: [...permissions],
            });
        }

        return response;
    };

    async function updateStaffPermissions(memberId: string, permissions: StaffPermission[]) {
        const member = staff.value.find((entry) => entry.id === memberId);
        if (!member) return;

        const response = await FetchNUI("owner:update-staff", { id: memberId, permissions });
        if (response.success) member.permissions = [...permissions];

        return response;
    };

    // Driven by the server when a staff member joins or drops while the panel is open
    function setStaffOnline(memberId: string, online: boolean) {
        const member = staff.value.find((entry) => entry.id === memberId);
        if (member) member.online = online === true;
    };

    async function fireStaff(memberId: string) {
        const response = await FetchNUI("owner:fire-staff", { id: memberId });
        if (response.success) staff.value = staff.value.filter((entry) => entry.id !== memberId);

        return response;
    };

    async function transferOwnership(playerId: number) {
        return FetchNUI("owner:transfer", { playerId });
    };

    async function sellMachine() {
        return FetchNUI("owner:sell");
    };

    return {
        section,
        access,
        can,
        canSection,
        setAccess,
        settings,
        balance,
        wallet,
        capacity,
        revenue,
        transactions,
        unitsSold,
        cashMovements,
        wholesale,
        orders,
        staff,
        ownerMember,
        selfId,
        saving,
        cashBusy,
        ordering,
        totalDeposited,
        totalWithdrawn,
        weekRevenue,
        weekSales,
        todayRevenue,
        revenueChange,
        lowStock,
        topProducts,
        productName,
        updatePrice,
        orderTotal,
        orderStock,
        setOrderStatus,
        pickupOrder,
        incoming,
        activeOrders,
        moveCash,
        saveSettings,
        hireStaff,
        updateStaffPermissions,
        setStaffOnline,
        fireStaff,
        transferOwnership,
        sellMachine,
        isLowStock,
        load,
    };
});
