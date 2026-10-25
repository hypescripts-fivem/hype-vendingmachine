import { useShopStore } from "@/stores";
import { useAppStore } from "@/stores/app";
import { useOwnerStore } from "@/stores/owner";
import { debug, FetchNUI, setDebug } from ".";
import { setLocaleFormat } from "./format";

interface NuiMessage {
    action: string;
    payload: any;
};

export function messageEvent() {
    const app = useAppStore();

    const handlers: Record<string, (payload: any) => void> = {
        nuiReady: () => FetchNUI("nui-ready", {}),
        setView: (payload: { view: string }) => app.setView(payload.view),
        close: () => app.hide(),
        setConfig: (config) => {
            setDebug(config.debug);
            useShopStore().inventoryImagePath = config.inventoryImagePath;
            setLocaleFormat(config.currency, config.locale);
        },
        setOrderStatus: ({ id, status }) => useOwnerStore().setOrderStatus(id, status),
        setAccess: (access) => useOwnerStore().setAccess(access),
        setStaffOnline: ({ id, online }) => useOwnerStore().setStaffOnline(id, online),
    };

    window.addEventListener('message', ({ data }: MessageEvent<NuiMessage>) => {
        const handler = handlers[data?.action];

        if (handler) {
            handler(data.payload);
            debug(`Received action: ${data?.action}`, data?.payload);
        } else {
            console.warn(`Unknown action received: ${data?.action}`);
        }
    });
};

// Escape closes the page, unless a modal, menu or picker is open; those close themselves first
export function keydownEvent() {
    const app = useAppStore();

    window.addEventListener("keydown", ({ code }) => {
        if (code !== "Escape") return;
        if (document.querySelector('[role="dialog"], [role="listbox"], [aria-expanded="true"]')) return;

        app.close();
    });
};
