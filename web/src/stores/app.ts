import { defineStore } from "pinia";
import { ref } from "vue";
import { debug, FetchNUI, isNative } from "@/utils";
import { useShopStore } from "@/stores";
import { useOwnerStore } from "@/stores/owner";
import { usePurchaseStore } from "@/stores/purchase";

export type View = 'vending' | 'purchase' | 'owner' | 'admin';

export const views: View[] = ['vending', 'purchase', 'owner', 'admin'];

const defaultView: View = 'vending';

function isView(value: unknown): value is View {
    return views.includes(value as View);
};

function viewFromUrl(): View {
    const view = new URLSearchParams(window.location.search).get('view');

    return isView(view) ? view : defaultView;
};

export const useAppStore = defineStore("app", () => {
    // Outside FiveM there is no game to pick the page, so the ?view= query param decides
    const view = ref<View>(isNative ? defaultView : viewFromUrl());
    // In game nothing is on screen until the client sends setView
    const visible = ref(false);
    // Pages copy store data into their forms when they mount, so they only mount once the data is in
    const ready = ref(false);

    // Each page asks the server for its data every time it opens
    const loaders: Record<View, () => Promise<unknown>> = {
        vending: () => useShopStore().load(),
        purchase: () => usePurchaseStore().load(),
        owner: () => useOwnerStore().load(),
        // Imported on demand: the admin store pulls in echarts, which the vending page shouldn't load
        admin: async () => (await import("@/stores/admin")).useAdminStore().load(),
    };

    async function load(target: View) {
        ready.value = false;

        try {
            await loaders[target]();
        } finally {
            // A newer setView may have arrived while this one was loading
            if (view.value === target) ready.value = true;
        };

        debug(`setView(${target}) finished loading`, { ready: ready.value, view: view.value });
    };

    function setView(next: unknown) {
        if (!isView(next)) return;

        view.value = next;
        visible.value = true;

        if (!isNative) {
            const url = new URL(window.location.href);
            url.searchParams.set('view', next);
            window.history.pushState(null, '', url);
        };

        debug(`setView(${next})`);

        return load(next);
    };

    // Hides the page right away; the client releases NUI focus when it gets the close callback
    function close() {
        // The browser preview has no game to come back from, so it stays on screen
        if (!isNative) return;
        if (!visible.value) return;

        visible.value = false;
        ready.value = false;
        FetchNUI("close");
    };

    // Sent by the client when it closes the page itself (walked away, died, machine removed)
    function hide() {
        visible.value = false;
        ready.value = false;
    };

    if (!isNative) {
        visible.value = true;
        load(view.value);

        window.addEventListener('popstate', () => {
            view.value = viewFromUrl();
            load(view.value);
        });
    }

    return {
        view,
        visible,
        ready,
        setView,
        close,
        hide,
    };
});
