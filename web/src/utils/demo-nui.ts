import { ref, watchEffect } from "vue";

import { useShopStore, type PaymentMethod, type Product } from "@/stores";
import { useAppStore, type View } from "@/stores/app";
import { useOwnerStore, type StaffMember, type StaffPermission, type StockOrderItem } from "@/stores/owner";
import { usePlacementStore, type PlacementPosition } from "@/stores/placement";
import type { MachineConfig } from "@/stores/admin";

import type { NuiResponse } from ".";
import { demoNui, demoView, type DemoView } from "./demo";
import { DEMO_CONFIG, DEMO_PLAYERS, demoAdmin, demoOwner, demoProducts, demoVending } from "./demo-data";
import { applyConfig } from "./events";

// Website demo build only (see utils/demo.ts): mock NUI answers, the server's pushes, and opening the page

// Toolbar on top, a little room on the sides and below
const TOOLBAR = 64;
const GUTTER = 24;

// Size of each page in px: the vending menu is w-7xl h-180, the panels h-225, the screen is Config.Screen (900x1600)
const SIZES: Record<DemoView, { width: number; height: number }> = {
    shop: { width: 1280, height: 720 },
    screen: { width: 900, height: 1600 },
    owner: { width: 1280, height: 900 },
    admin: { width: 1280, height: 900 },
};

// The page each demo view opens, as the client's setView would
const PAGES: Record<DemoView, View> = {
    shop: 'vending',
    screen: 'screen',
    owner: 'owner',
    admin: 'admin',
};

/**
 * @param ms
 * @returns Promise<void>
 */
const wait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/**
 * In game the client sends these with SendNUIMessage, they go through the same handlers (utils/events.ts)
 * @param action
 * @param payload
 * @returns void
 */
function push(action: string, payload?: unknown) {
    window.postMessage({ action, payload }, '*');
}

// Stock of the machine, shared by the shop, the screen and the owner panel like the database row
let stock: Product[] = demoProducts();

/**
 * checkout: the server takes the stock and the money and answers with both
 * @param data
 * @returns NuiResponse
 */
function checkout(data: { items?: { id: string; quantity: number }[]; payment?: PaymentMethod }): NuiResponse<unknown> {
    const shop = useShopStore();
    const payment = data.payment ?? 'cash';
    let total = 0;

    for (const { id, quantity } of data.items ?? []) {
        const product = stock.find((entry) => entry.id === id);
        if (!product || product.stock < quantity) return { success: false, error: `${product?.name ?? id} is out of stock.` };

        total += product.price * quantity;
    }

    if (shop.wallet[payment] < total) return { success: false, error: "You don't have enough money." };

    for (const { id, quantity } of data.items ?? []) {
        stock.find((entry) => entry.id === id)!.stock -= quantity;
    }

    return {
        success: true,
        data: {
            products: stock.map((product) => ({ ...product })),
            wallet: { ...shop.wallet, [payment]: shop.wallet[payment] - total },
        },
    };
}

/**
 * The warehouse prepares a new order after Config's delivery time, shortened for the demo
 * @param orderId
 * @returns void
 */
function prepareOrder(orderId: string) {
    setTimeout(() => push('setOrderStatus', { id: orderId, status: 'prepared' }), 8000);
}

/**
 * In game the owner drives the cart to the machine and unloads it box by box; the stock lands when the last box is in
 * @param orderId
 * @returns void
 */
function deliverOrder(orderId: string) {
    setTimeout(() => push('setOrderStatus', { id: orderId, status: 'shipping' }), 1000);

    setTimeout(() => {
        const owner = useOwnerStore();
        const order = owner.orders.find((entry) => entry.id === orderId);

        for (const item of order?.items ?? []) {
            const product = stock.find((entry) => entry.id === item.productId);
            if (product) product.stock += item.quantity;
        }

        // The panel reads the machine's products from the shop store
        useShopStore().products = stock.map((product) => ({ ...product }));
        push('setOrderStatus', { id: orderId, status: 'completed' });
    }, 9000);
}

let nextId = 100;

/**
 * Where the camera stands while placing: behind and above the ghost machine, looking at it
 * @param position
 * @returns void
 */
function placementFrame(position: PlacementPosition) {
    const camera = { x: position.x + 3.2, y: position.y - 3.6, z: position.z + 1.8 };
    const forward = { x: position.x - camera.x, y: position.y - camera.y, z: position.z + 0.6 - camera.z };
    const length = Math.hypot(forward.x, forward.y, forward.z);

    push('placement:frame', {
        camera: { ...camera, forward: { x: forward.x / length, y: forward.y / length, z: forward.z / length }, fov: 50 },
        entity: position,
        cursor: true,
    });
}

/**
 * Mock NUI callback answers for the website demo. Anything not listed gets the page's own preview data (`mock`)
 * @param event
 * @param data
 * @param mock
 * @returns Promise<NuiResponse>
 */
export async function demoResponse<T>(event: string, data: unknown, mock: T | undefined): Promise<NuiResponse<T>> {
    const body = (data ?? {}) as Record<string, any>;
    // A short round trip, so buttons show their busy state like in game
    const answer = async (value?: unknown, ms = 250): Promise<NuiResponse<T>> => {
        await wait(ms);
        return { success: true, data: value as T };
    };
    const reject = async (error: string): Promise<NuiResponse<T>> => {
        await wait(400);
        return { success: false, error };
    };

    switch (event) {
        case 'screen:ready':
            return answer(DEMO_CONFIG, 0);
        case 'screen:idle':
            return answer(stock.filter((product) => product.stock > 0).map((product) => product.image), 0);
        case 'vending:get-data':
            return answer(demoVending(stock.map((product) => ({ ...product }))), 150);
        case 'checkout': {
            await wait(600);
            return checkout(body) as NuiResponse<T>;
        }

        case 'owner:get-data':
            return answer(demoOwner(stock.map((product) => ({ ...product }))), 150);
        case 'owner:update-price': {
            const product = stock.find((entry) => entry.id === body.id);
            if (product) product.price = Number(body.price);
            return answer();
        }
        case 'owner:order-stock': {
            const id = `o${nextId++}`;
            const total = (body.items as StockOrderItem[]).reduce((sum, item) => sum + (useOwnerStore().wholesale[item.productId] ?? 0) * item.quantity, 0);
            prepareOrder(id);
            return answer({ orderId: id, balance: useOwnerStore().balance - total }, 500);
        }
        case 'owner:pickup-order':
            deliverOrder(String(body.id));
            return answer(undefined, 400);
        case 'owner:hire-staff': {
            const playerId = Number(body.playerId);
            const name = DEMO_PLAYERS[playerId];
            if (!name) return reject("No player with that ID is near the machine. Try 7, 12, 23 or 31.");
            if (useOwnerStore().staff.some((member) => member.name === name)) return reject("That player is already on your staff.");

            const member: StaffMember = { id: `st${nextId++}`, name, hiredAt: Date.now(), lastOnline: null, online: true, permissions: [...(body.permissions as StaffPermission[])] };
            return answer({ member }, 400);
        }
        case 'owner:transfer':
        case 'owner:sell':
            return reject("Disabled in the demo: the machine would leave your hands.");

        case 'admin:get-data':
            return answer(demoAdmin(), 150);
        case 'admin:create-machine':
            return answer({ id: `m${nextId++}`, ownerName: DEMO_PLAYERS[Number((body as MachineConfig).ownerId)] }, 500);
        case 'admin:update-machine':
            return answer({ ownerName: DEMO_PLAYERS[Number((body as MachineConfig).ownerId)] }, 400);
        case 'admin:import-machine':
            return answer({ ids: (body.machines as MachineConfig[]).map(() => `m${nextId++}`) }, 500);

        case 'placement:start': {
            const position: PlacementPosition = { x: 215.86, y: -926.53, z: 30.69, heading: 145 };
            setTimeout(() => placementFrame(position));
            return answer(position, 0);
        }
        case 'placement:snap': {
            const placement = usePlacementStore();
            placement.position = { ...placement.position, z: 30.69 };
            return answer(undefined, 0);
        }
        case 'placement:confirm':
            push('placement:finish', { location: { label: 'Legion Square', ...usePlacementStore().position } });
            return answer(undefined, 0);
        case 'placement:cancel':
            push('placement:finish', {});
            return answer(undefined, 0);

        default:
            return answer(mock, event.startsWith('placement:') ? 0 : 250);
    }
}

/**
 * Scales the page down on screens smaller than it, and keeps it clear of the toolbar.
 * Not while placing a machine: the gizmo is drawn over the whole window, like over the game
 * @param view
 * @returns void
 */
function scaleToFit(view: DemoView) {
    const root = document.getElementById('app')!;
    const placement = usePlacementStore();
    const scale = ref(1);

    const update = () => {
        const { width, height } = SIZES[view];
        scale.value = Math.min(1, (window.innerWidth - GUTTER * 2) / width, (window.innerHeight - TOOLBAR - GUTTER * 2) / height);
    };

    update();
    window.addEventListener('resize', update);

    // App's page box is the window and clips what's taller (the 1600px screen) before the scale brings it back in view
    (root.firstElementChild as HTMLElement | null)?.style.setProperty('overflow', 'visible');

    watchEffect(() => {
        root.style.transform = placement.active ? '' : `translateY(${TOOLBAR / 2}px) scale(${scale.value})`;
        // For what opens outside #app and should still match the page's size (the touchscreen's checkout)
        document.documentElement.style.setProperty('--demo-scale', String(scale.value));
    });
}

/**
 * Opens the demo page the way the game does: setConfig, then setView
 * @returns void
 */
export function startDemo() {
    if (!demoView) return;

    // In game the UI sits on top of the game, on the website it needs a page background
    document.body.style.background = '#0a0a0a';

    demoNui.respond = demoResponse;
    scaleToFit(demoView);

    stock = demoProducts();
    applyConfig(DEMO_CONFIG);
    useAppStore().setView(PAGES[demoView]);

    // The client cancels a placement on Escape. keyup: the page swallows the keydown while placing (utils/events.ts)
    window.addEventListener('keyup', (event) => {
        if (event.code === 'Escape' && usePlacementStore().active) usePlacementStore().cancel();
    });

    // A staff member logs in while the panel is open (server: setStaffOnline)
    if (demoView === 'owner') setTimeout(() => push('setStaffOnline', { id: 'st2', online: true }), 12000);
}
