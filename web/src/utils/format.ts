import { reactive } from "vue";

// Config.Currency and Config.NumberAndDateFormat, sent by the client in setConfig
const localeFormat = reactive({ currency: "USD", locale: "en-US" });

const dateOptions = {
    date: { month: "short", day: "numeric" },
    dateTime: { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" },
} satisfies Record<string, Intl.DateTimeFormatOptions>;

const cache = new Map<string, Intl.NumberFormat | Intl.DateTimeFormat>();

function moneyFormatter(): Intl.NumberFormat {
    const key = `money|${localeFormat.locale}|${localeFormat.currency}`;

    if (!cache.has(key)) {
        cache.set(key, new Intl.NumberFormat(localeFormat.locale, {
            style: "currency",
            currency: localeFormat.currency,
            minimumFractionDigits: 0,
            maximumFractionDigits: 0,
        }));
    };

    return cache.get(key) as Intl.NumberFormat;
};

function dateFormatter(kind: keyof typeof dateOptions): Intl.DateTimeFormat {
    const key = `${kind}|${localeFormat.locale}`;

    if (!cache.has(key)) cache.set(key, new Intl.DateTimeFormat(localeFormat.locale, dateOptions[kind]));

    return cache.get(key) as Intl.DateTimeFormat;
};

// A bad currency code or locale in the config would make Intl throw, so those keep the defaults
export function setLocaleFormat(currency: unknown, locale: unknown) {
    if (typeof currency !== "string" || typeof locale !== "string") return;

    try {
        new Intl.NumberFormat(locale, { style: "currency", currency });
        localeFormat.currency = currency;
        localeFormat.locale = locale;
    } catch {
        console.warn(`Invalid Config.Currency "${currency}" or Config.NumberAndDateFormat "${locale}", using ${localeFormat.currency} / ${localeFormat.locale}`);
    };
};

export function formatMoney(value: number): string {
    return moneyFormatter().format(value);
};

// Just the symbol, for labels like "Price ($)"
export function currencySymbol(): string {
    return moneyFormatter().formatToParts(0).find((part) => part.type === "currency")?.value ?? localeFormat.currency;
};

// Timestamps from the server are milliseconds
export function formatDate(time: number): string {
    return dateFormatter("date").format(time);
};

export function formatDateTime(time: number): string {
    return dateFormatter("dateTime").format(time);
};

// Revenue days come as "2026-10-24", read as a local date so the day never shifts with the timezone
export function formatDay(day: string): string {
    const [year, month, date] = day.split("-").map(Number);
    return formatDate(new Date(year!, month! - 1, date).getTime());
};

const mockMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Browser preview only: mock data is written as "Oct 24 21:42" or "Oct 24", this year
export function mockTime(label: string): number {
    const [month, date, time = "12:00"] = label.split(" ");
    const [hours, minutes] = time.split(":").map(Number);
    return new Date(new Date().getFullYear(), mockMonths.indexOf(month!), Number(date), hours, minutes).getTime();
};
