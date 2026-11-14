import type { NuiResponse } from ".";

// Website demo (hypescripts.net/demo/vendingmachine), only in the `vite build --mode demo` build. That build starts
// from src/demo-main.ts instead of main.ts (vite.config.ts), the demo itself is utils/demo-nui.ts.
// No app imports on purpose: the stores read demoView while they load, and the game build must not pull in the demo

export type DemoView = 'shop' | 'screen' | 'owner' | 'admin';

// Toolbar order; the first one opens when ?view= is missing or unknown
export const DEMO_VIEWS: DemoView[] = ['shop', 'screen', 'owner', 'admin'];

/**
 * The demo screen picked with ?view=, null outside the demo build
 */
export const demoView: DemoView | null = (() => {
    if (import.meta.env.MODE !== 'demo') return null;

    const view = new URLSearchParams(window.location.search).get('view') as DemoView | null;
    return view && DEMO_VIEWS.includes(view) ? view : DEMO_VIEWS[0]!;
})();

// "Demos" button of the toolbar, the demo list on the website
export const DEMO_BACK_URL = '/demo';

// Set by the demo entry: answers the NUI callbacks in place of the game. Never set in game
export const demoNui: { respond?: <T>(event: string, data: unknown, mock: T | undefined) => Promise<NuiResponse<T>> } = {};
