import { shallowRef } from "vue";
import fallbackLocales from "../../../locales/en.json";

type Dictionary = Record<string, unknown>;

const fallback = fallbackLocales.ui as Dictionary;
const active = shallowRef<Dictionary>({});

export function setLocales(locales: unknown) {
    if (locales && typeof locales === "object" && !Array.isArray(locales)) active.value = locales as Dictionary;
};

function lookup(source: Dictionary, key: string): string | undefined {
    const value = key.split(".").reduce<unknown>((node, part) => (node && typeof node === "object" ? (node as Dictionary)[part] : undefined), source);

    return typeof value === "string" ? value : undefined;
};

export function t(key: string, ...args: (string | number)[]): string {
    const value = lookup(active.value, key) ?? lookup(fallback, key) ?? key;
    let index = 0;

    return value.replace(/%%|%s/g, (match) => (match === "%%" ? "%" : String(args[index++] ?? match)));
};
