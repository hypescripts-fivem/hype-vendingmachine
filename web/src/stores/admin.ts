import { defineStore } from "pinia";
import { computed, ref } from "vue";
import { asList, asRecord, FetchNUI } from "@/utils";
import { mockTime } from "@/utils/format";
import { mockProducts, type Product } from "@/stores";
import { seriesSlots } from "@/utils/chart";

export type AdminSection = 'dashboard' | 'machines' | 'settings';

export type MachineStatus = 'open' | 'closed' | 'disabled';

// What the panel shows: a machine nobody owns reads as for sale unless an admin disabled it
export type MachineDisplayStatus = MachineStatus | 'forSale';

export function displayStatus(machine: Pick<Machine, 'status' | 'forSale'>): MachineDisplayStatus {
    if (machine.status === "disabled") return "disabled";
    return machine.forSale ? "forSale" : machine.status;
};

export interface MachineLocation {
    label: string;
    x: number;
    y: number;
    z: number;
    heading: number;
};

// Editable fields, shared by the create form and the machine settings page
export interface MachineConfig {
    name: string;
    model: string;
    location: MachineLocation;
    ownerId: string;
    forSale: boolean;
    price: number;
    capacity: number;
    products: string[];
};

export interface Machine extends MachineConfig {
    id: string;
    // Chart color slot, assigned once so the machine keeps its color when rankings change
    colorSlot: number;
    ownerName: string | null;
    status: MachineStatus;
    balance: number;
    revenue: number;
    sales: number;
    stockLevel: number;
    // Milliseconds
    createdAt: number;
};

export interface AdminSettings {
    wholesaleMultiplier: number;
    salesTax: number;
    maxMachinesPerPlayer: number;
    deliveryMinutes: number;
    defaultCapacity: number;
    defaultPrice: number;
    allowPlayerPurchase: boolean;
    webhook: string;
    logPurchases: boolean;
    logAdminActions: boolean;
};

export const machineModels = [
    { label: "Soda machine", value: "prop_vend_soda_01" },
    { label: "Snack machine", value: "prop_vend_snak_01" },
    { label: "Coffee machine", value: "prop_vend_coffe_01" },
    { label: "Water machine", value: "prop_vend_water_01" },
];

const location = (label: string, x: number, y: number, z: number, heading = 0): MachineLocation => ({ label, x, y, z, heading });

const allProducts = ["water", "cola", "sprunk", "coffee", "chips", "chocolate", "candy", "sandwich", "donut"];

const mockMachines: Machine[] = [
    { id: "m1", colorSlot: 0, name: "Legion Square #1", model: "prop_vend_soda_01", location: location("Legion Square", 195.4, -933.2, 30.7), ownerId: "142", ownerName: "Alex Turner", forSale: false, price: 25000, capacity: 50, products: allProducts, status: "open", balance: 3625, revenue: 3625, sales: 435, stockLevel: 52, createdAt: mockTime("Sep 02") },
    { id: "m2", colorSlot: 1, name: "Pillbox Hospital", model: "prop_vend_coffe_01", location: location("Pillbox Hill", 307.1, -595.8, 43.3), ownerId: "87", ownerName: "Mia Lopez", forSale: false, price: 30000, capacity: 40, products: ["coffee", "water", "donut", "sandwich"], status: "open", balance: 2140, revenue: 4980, sales: 512, stockLevel: 74, createdAt: mockTime("Sep 05") },
    { id: "m3", colorSlot: 2, name: "Vespucci Beach", model: "prop_vend_water_01", location: location("Vespucci Beach", -1223.6, -1491.4, 4.4), ownerId: "203", ownerName: "Ray Dawson", forSale: false, price: 18000, capacity: 50, products: ["water", "sprunk", "cola", "candy"], status: "closed", balance: 860, revenue: 1720, sales: 241, stockLevel: 18, createdAt: mockTime("Sep 11") },
    { id: "m4", colorSlot: 3, name: "Mission Row PD", model: "prop_vend_snak_01", location: location("Mission Row", 441.2, -981.9, 30.7), ownerId: "56", ownerName: "Nora Kim", forSale: false, price: 28000, capacity: 50, products: ["chips", "chocolate", "candy", "donut", "coffee"], status: "open", balance: 1980, revenue: 3410, sales: 398, stockLevel: 63, createdAt: mockTime("Sep 14") },
    { id: "m5", colorSlot: 4, name: "Sandy Shores Gas", model: "prop_vend_soda_01", location: location("Sandy Shores", 1961.5, 3740.1, 32.3), ownerId: "", ownerName: null, forSale: true, price: 15000, capacity: 30, products: ["water", "cola", "chips"], status: "closed", balance: 0, revenue: 0, sales: 0, stockLevel: 0, createdAt: mockTime("Oct 01") },
    { id: "m6", colorSlot: 5, name: "Paleto Bay Market", model: "prop_vend_snak_01", location: location("Paleto Bay", -324.8, 6066.9, 31.5), ownerId: "311", ownerName: "Leo Grant", forSale: false, price: 16000, capacity: 40, products: ["chips", "sandwich", "water"], status: "disabled", balance: 415, revenue: 920, sales: 117, stockLevel: 35, createdAt: mockTime("Oct 06") },
    { id: "m7", colorSlot: 7, name: "Del Perro Pier", model: "prop_vend_water_01", location: location("Del Perro", -1638.2, -1068.4, 13.1), ownerId: "", ownerName: null, forSale: true, price: 22000, capacity: 50, products: ["water", "sprunk", "candy"], status: "closed", balance: 0, revenue: 0, sales: 0, stockLevel: 0, createdAt: mockTime("Oct 12") },
    { id: "m8", colorSlot: 6, name: "Maze Bank Tower", model: "prop_vend_coffe_01", location: location("Pillbox Hill", -75.2, -818.6, 326.2), ownerId: "142", ownerName: "Alex Turner", forSale: false, price: 35000, capacity: 50, products: ["coffee", "water", "chocolate"], status: "open", balance: 2760, revenue: 5230, sales: 498, stockLevel: 81, createdAt: mockTime("Oct 15") },
];

const mockRevenue = [
    { date: "2026-10-18", revenue: 2410 },
    { date: "2026-10-19", revenue: 2280 },
    { date: "2026-10-20", revenue: 2895 },
    { date: "2026-10-21", revenue: 2640 },
    { date: "2026-10-22", revenue: 3120 },
    { date: "2026-10-23", revenue: 2985 },
    { date: "2026-10-24", revenue: 3550 },
];

const mockSettings: AdminSettings = {
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
};

// Everything the admin panel shows, sent by admin:getData when it opens
export interface AdminData {
    machines: Machine[];
    // Last 7 days across every machine, oldest first
    revenue: { date: string; revenue: number }[];
    settings: AdminSettings;
    // Every item a machine can be set to sell. Only id, name, category and image are used
    products: Product[];
};

export function emptyMachineConfig(settings: AdminSettings): MachineConfig {
    return {
        name: "",
        model: machineModels[0]!.value,
        location: location("", 0, 0, 0),
        ownerId: "",
        forSale: true,
        price: settings.defaultPrice,
        capacity: settings.defaultCapacity,
        products: [],
    };
};

export function validateMachine(config: MachineConfig): string | undefined {
    if (!config.name.trim()) return "Machine name can't be empty.";
    if (!config.location.x && !config.location.y && !config.location.z) return "Set a location for the machine.";
    if (!config.products.length) return "Pick at least one product.";
    return undefined;
};

// A machine left without an owner goes up for sale
function withOwnership(config: MachineConfig): MachineConfig {
    const ownerId = config.ownerId.trim();
    const forSale = config.forSale || !ownerId;

    return { ...config, ownerId: forSale ? "" : ownerId, forSale };
};

export const useAdminStore = defineStore("admin", () => {
    const section = ref<AdminSection>("dashboard");
    // Machine whose settings page is open inside the Machines section
    const editingId = ref<string>();
    const machines = ref<Machine[]>([]);
    const revenue = ref<AdminData["revenue"]>([]);
    const settings = ref<AdminSettings>(mockSettings);
    const products = ref<Product[]>([]);
    const saving = ref(false);

    // Least-used slot first, so new machines spread across the palette
    function nextColorSlot(): number {
        const used = Array.from({ length: seriesSlots }, (_, slot) => machines.value.filter((machine) => machine.colorSlot === slot).length);
        return used.indexOf(Math.min(...used));
    };

    const editing = computed(() => machines.value.find((machine) => machine.id === editingId.value));

    const stats = computed(() => ({
        total: machines.value.length,
        open: machines.value.filter((machine) => machine.status === "open").length,
        forSale: machines.value.filter((machine) => machine.forSale).length,
        disabled: machines.value.filter((machine) => machine.status === "disabled").length,
        revenue: machines.value.reduce((sum, machine) => sum + machine.revenue, 0),
        sales: machines.value.reduce((sum, machine) => sum + machine.sales, 0),
        owners: new Set(machines.value.filter((machine) => machine.ownerName).map((machine) => machine.ownerId)).size,
    }));

    const topMachines = computed(() => [...machines.value].sort((a, b) => b.revenue - a.revenue).slice(0, 5));

    const lowStockMachines = computed(() => machines.value.filter((machine) => !machine.forSale && machine.stockLevel < 25));

    async function load() {
        const response = await FetchNUI<AdminData>("admin:get-data", {}, JSON.parse(JSON.stringify({
            machines: mockMachines,
            revenue: mockRevenue,
            settings: mockSettings,
            products: mockProducts,
        })));

        const data = response.data;

        if (response.success && data) {
            machines.value = asList(data.machines);
            revenue.value = asList(data.revenue);
            settings.value = { ...mockSettings, ...asRecord<AdminSettings>(data.settings) };
            products.value = asList(data.products);

            // The machine that was open may have been deleted since
            if (!machines.value.some((machine) => machine.id === editingId.value)) editingId.value = undefined;
        };

        return response;
    };

    function openMachine(id: string) {
        editingId.value = id;
        section.value = "machines";
    };

    async function getPosition() {
        return FetchNUI<MachineLocation>("admin:get-position", {}, location("Legion Square", 195.4 + Math.random() * 10, -933.2, 30.7, 90));
    };

    async function teleport(id: string) {
        return FetchNUI("admin:teleport", { id });
    };

    // A machine the server just created: no money or stock yet, closed until stocked
    function addMachine(config: MachineConfig, id: string, ownerName?: string) {
        machines.value.unshift({
            ...JSON.parse(JSON.stringify(config)),
            id,
            colorSlot: nextColorSlot(),
            ownerName: config.forSale ? null : ownerName ?? `Player ${config.ownerId}`,
            status: "closed",
            balance: 0,
            revenue: 0,
            sales: 0,
            stockLevel: 0,
            createdAt: Date.now(),
        });
    };

    async function createMachine(input: MachineConfig) {
        const config = withOwnership(input);
        saving.value = true;

        try {
            const response = await FetchNUI<{ id: string; ownerName?: string }>("admin:create-machine", config, { id: `m${Date.now()}` });

            if (response.success && response.data) addMachine(config, response.data.id, response.data.ownerName);

            return response;
        } finally {
            saving.value = false;
        }
    };

    // The server answers with one id per machine, in the same order
    async function importMachines(configs: MachineConfig[]) {
        saving.value = true;

        try {
            const response = await FetchNUI<{ ids: string[] }>("admin:import-machine", { machines: configs }, {
                ids: configs.map((_, index) => `m${Date.now()}-${index}`),
            });

            if (response.success && response.data) {
                configs.forEach((config, index) => {
                    const id = response.data!.ids[index];
                    if (id) addMachine(config, id);
                });
            }

            return response;
        } finally {
            saving.value = false;
        }
    };

    async function updateMachine(id: string, input: MachineConfig) {
        const config = withOwnership(input);
        saving.value = true;

        try {
            const response = await FetchNUI<{ ownerName?: string }>("admin:update-machine", { id, ...config });
            const machine = machines.value.find((entry) => entry.id === id);

            if (response.success && machine) {
                const ownerChanged = machine.ownerId !== config.ownerId || machine.forSale !== config.forSale;

                Object.assign(machine, JSON.parse(JSON.stringify(config)));

                if (config.forSale) {
                    machine.ownerName = null;
                } else if (ownerChanged) {
                    machine.ownerName = response.data?.ownerName ?? `Player ${config.ownerId}`;
                }
            }

            return response;
        } finally {
            saving.value = false;
        }
    };

    async function setStatus(id: string, status: MachineStatus) {
        const response = await FetchNUI("admin:set-status", { id, status });
        const machine = machines.value.find((entry) => entry.id === id);

        if (response.success && machine) machine.status = status;

        return response;
    };

    async function resetBalance(id: string) {
        const response = await FetchNUI("admin:reset-balance", { id });
        const machine = machines.value.find((entry) => entry.id === id);

        if (response.success && machine) machine.balance = 0;

        return response;
    };

    async function deleteMachine(id: string) {
        const response = await FetchNUI("admin:delete-machine", { id });

        if (response.success) {
            machines.value = machines.value.filter((machine) => machine.id !== id);
            if (editingId.value === id) editingId.value = undefined;
        }

        return response;
    };

    async function saveSettings(next: AdminSettings) {
        saving.value = true;

        try {
            const response = await FetchNUI("admin:save-settings", next);
            if (response.success) settings.value = JSON.parse(JSON.stringify(next));

            return response;
        } finally {
            saving.value = false;
        }
    };

    return {
        section,
        editingId,
        editing,
        machines,
        revenue,
        settings,
        products,
        saving,
        stats,
        topMachines,
        lowStockMachines,
        openMachine,
        getPosition,
        teleport,
        createMachine,
        importMachines,
        updateMachine,
        setStatus,
        resetBalance,
        deleteMachine,
        saveSettings,
        load,
    };
});
