import { machineModels, type AdminSettings, type Machine, type MachineConfig } from "@/stores/admin";

const format = "hype-vendingmachine";
const version = 1;

// Only what it takes to place the machine on another server; owners, money, sales and stock never leave this one
export interface SharedMachine {
    name: string;
    model: string;
    location: { label: string; x: number; y: number; z: number; heading: number };
    price: number;
    capacity: number;
    products: string[];
};

export function exportMachines(machines: Machine[]): string {
    const shared: SharedMachine[] = machines.map(({ name, model, location, price, capacity, products }) => ({
        name,
        model,
        location: { label: location.label, x: location.x, y: location.y, z: location.z, heading: location.heading },
        price,
        capacity,
        products: [...products],
    }));

    return JSON.stringify({ format, version, exportedAt: new Date().toISOString(), machines: shared }, null, 2);
};

export interface ImportContext {
    settings: AdminSettings;
    existing: Machine[];
    // Item ids this server sells; anything else in the file is dropped
    products: string[];
};

export interface ImportResult {
    machines: MachineConfig[];
    skipped: { name: string; reason: string }[];
    error?: string;
};

// Closer than this (in game units) counts as the same spot
const SAME_SPOT = 1;

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null && !Array.isArray(value);
const isNumber = (value: unknown): value is number => typeof value === "number" && Number.isFinite(value);

function sameSpot(a: { x: number; y: number; z: number }, b: { x: number; y: number; z: number }): boolean {
    return Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z) < SAME_SPOT;
};

export function parseMachineImport(text: string, context: ImportContext): ImportResult {
    let data: unknown;

    try {
        data = JSON.parse(text);
    } catch {
        return { machines: [], skipped: [], error: "This isn't valid JSON." };
    }

    // A bare array is accepted too, in case someone trimmed the file down by hand
    const entries = Array.isArray(data) ? data : isRecord(data) && Array.isArray(data.machines) ? data.machines : undefined;
    if (!entries?.length) return { machines: [], skipped: [], error: "No machines found in this JSON." };

    const result: ImportResult = { machines: [], skipped: [] };
    const models = machineModels.map((model) => model.value);

    entries.forEach((entry, index) => {
        const name = isRecord(entry) && typeof entry.name === "string" ? entry.name.trim() : "";
        const label = name || `Machine ${index + 1}`;
        const skip = (reason: string) => result.skipped.push({ name: label, reason });

        if (!isRecord(entry) || !name) return skip("Missing a name.");

        const location = isRecord(entry.location) ? entry.location : undefined;
        if (!location || !isNumber(location.x) || !isNumber(location.y) || !isNumber(location.z)) return skip("Missing a location.");

        const spot = { x: location.x, y: location.y, z: location.z };
        if (context.existing.some((machine) => sameSpot(machine.location, spot))) return skip("A machine already stands here.");
        if (result.machines.some((machine) => sameSpot(machine.location, spot))) return skip("Listed twice in this JSON.");

        const products = Array.isArray(entry.products)
            ? [...new Set(entry.products.filter((id): id is string => typeof id === "string" && context.products.includes(id)))]
            : [];
        if (!products.length) return skip("None of its products exist on this server.");

        result.machines.push({
            name,
            model: typeof entry.model === "string" && models.includes(entry.model) ? entry.model : models[0]!,
            location: {
                label: typeof location.label === "string" ? location.label.trim() : "",
                ...spot,
                heading: isNumber(location.heading) ? location.heading : 0,
            },
            // Nobody on this server owns it yet
            ownerId: "",
            forSale: true,
            price: isNumber(entry.price) && entry.price >= 0 ? Math.floor(entry.price) : context.settings.defaultPrice,
            capacity: isNumber(entry.capacity) && entry.capacity > 0 ? Math.floor(entry.capacity) : context.settings.defaultCapacity,
            products,
        });
    });

    return result;
};
