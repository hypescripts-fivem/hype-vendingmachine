const resourceName = (): string => (window as any).GetParentResourceName?.() ?? 'hype-vendingmachine';

export const isNative = !!(window as any).invokeNative;

// Config.Debug, sent by the client in setConfig
let debugEnabled = false;

export function setDebug(enabled: unknown) {
    debugEnabled = enabled === true;
};

export function debug(message: string, ...data: unknown[]) {
    if (!debugEnabled) return;

    console.log(`[DEBUG:WEB] ${message}`, ...data);
};

interface NuiResponse<T = unknown> {
    success: boolean;
    error?: string;
    data?: T;
};

export async function FetchNUI<T = unknown>(event: string, data?: unknown, mock?: T): Promise<NuiResponse<T>> {
    debug(`FetchNUI(${event})`, data);

    if (!isNative) {
        return { success: true, data: mock };
    }

    // A missing callback, or one that answers with cb() / a bare value, must not throw in the page
    try {
        const response = await fetch(`https://${resourceName()}/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data ?? {}),
        });

        const text = await response.text();
        const body = text ? JSON.parse(text) : undefined;

        debug(`FetchNUI(${event}) answered`, body);

        if (body && typeof body === 'object' && typeof body.success === 'boolean') return body;

        console.warn(`NUI callback "${event}" answered without { success, data }:`, text || '(empty)');
        return { success: false, error: 'No response from the server.' };
    } catch (error) {
        console.warn(`NUI callback "${event}" failed:`, error);
        return { success: false, error: 'No response from the server.' };
    }
};

// Lua can't tell an empty list from an empty object, and placeholders like 0 slip through,
// so data from the client is read through these instead of trusted as typed
export const asList = <T>(value: unknown): T[] => (Array.isArray(value) ? value : []);

export const asRecord = <T extends object>(value: unknown): Partial<T> =>
    (typeof value === 'object' && value !== null && !Array.isArray(value) ? value : {}) as Partial<T>;

export const asNumber = (value: unknown, fallback = 0): number =>
    typeof value === 'number' && Number.isFinite(value) ? value : fallback;
