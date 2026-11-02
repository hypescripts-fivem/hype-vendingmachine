import { useShopStore } from "@/stores";
import { useAppStore } from "@/stores/app";
import { useOwnerStore } from "@/stores/owner";
import { usePlacementStore } from "@/stores/placement";
import { debug, FetchNUI, setDebug } from ".";
import { setLocaleFormat } from "./format";

interface NuiMessage {
    action: string;
    payload: any;
};

export interface UiConfig {
    inventoryImagePath: string;
    currency: string;
    locale: string;
    debug: boolean;
};

// Sent to the menu in setConfig, and to the machine's screen by the screen:ready callback
export function applyConfig(config: UiConfig) {
    setDebug(config.debug);
    useShopStore().inventoryImagePath = config.inventoryImagePath;
    setLocaleFormat(config.currency, config.locale);
};

export function messageEvent() {
    const app = useAppStore();

    const handlers: Record<string, (payload: any) => void> = {
        nuiReady: () => FetchNUI("nui-ready", {}),
        setView: (payload: { view: string }) => app.setView(payload.view),
        close: () => app.hide(),
        setConfig: applyConfig,
        setOrderStatus: ({ id, status }) => useOwnerStore().setOrderStatus(id, status),
        setAccess: (access) => useOwnerStore().setAccess(access),
        setStaffOnline: ({ id, online }) => useOwnerStore().setStaffOnline(id, online),
        "placement:frame": (frame) => usePlacementStore().setFrame(frame),
        "placement:finish": ({ location }) => usePlacementStore().finish(location),
    };

    window.addEventListener('message', ({ data }: MessageEvent<NuiMessage>) => {
        const handler = handlers[data?.action];

        if (handler) {
            handler(data.payload);
            // Sent every frame while placing a machine
            if (data.action !== "placement:frame") debug(`Received action: ${data?.action}`, data?.payload);
        } else {
            console.warn(`Unknown action received: ${data?.action}`);
        }
    });
};

// Escape closes the page, unless a modal, menu or picker is open; those close themselves first
export function keydownEvent() {
    const app = useAppStore();

    // The client cancels a placement on Escape. Caught first, so neither the page nor an open modal (the
    // create form) closes and loses what was filled in
    window.addEventListener("keydown", (event) => {
        if (event.code === "Escape" && usePlacementStore().active) event.stopImmediatePropagation();
    }, true);

    window.addEventListener("keydown", ({ code }) => {
        if (code !== "Escape") return;
        if (document.querySelector('[role="dialog"], [role="listbox"], [aria-expanded="true"]')) return;

        app.close();
    });
};
