import { color } from "echarts/core";

// ECharts draws on canvas and can't read CSS variables, so resolve veyra tokens to real colors
export function token(name: string): string {
    return getComputedStyle(document.documentElement).getPropertyValue(`--color-${name}`).trim();
};

export function chartTheme() {
    return {
        primary: token("text-primary"),
        muted: token("text-muted"),
        faint: token("text-faint"),
        border: token("border"),
        surface: token("bg-surface"),
        elevated: token("bg-elevated"),
        font: getComputedStyle(document.body).fontFamily,
    };
};

// Categorical palette (dataviz reference order: blue, orange, aqua, yellow, magenta, green, violet, red).
// Assign a slot to an entity once and keep it; never pick a slot from a ranking.
const seriesPalette = [
    { dark: "#3987e5", light: "#2a78d6" },
    { dark: "#d95926", light: "#eb6834" },
    { dark: "#199e70", light: "#1baf7a" },
    { dark: "#c98500", light: "#eda100" },
    { dark: "#d55181", light: "#e87ba4" },
    { dark: "#008300", light: "#008300" },
    { dark: "#9085e9", light: "#6250d6" },
    { dark: "#e66767", light: "#e34948" },
];

export const seriesSlots = seriesPalette.length;

export function seriesColor(slot: number): string {
    const colors = seriesPalette[((slot % seriesSlots) + seriesSlots) % seriesSlots]!;
    return document.documentElement.dataset.theme === "light" ? colors.light : colors.dark;
};

// Fixed per category so a color always means the same thing; validated for CVD and contrast on veyra surfaces
const categorySlots: Record<string, number> = { drinks: 0, food: 1, snacks: 2 };

export function categoryColor(category: string, theme = chartTheme()): string {
    const slot = categorySlots[category];
    return slot === undefined ? theme.muted : seriesColor(slot);
};

// Tokens can be short hex (#fff) or rgb(), so never build alpha colors by string concatenation
export function alpha(value: string, opacity: number): string {
    return color.modifyAlpha(value, opacity) ?? value;
};

export function tooltipStyle(theme = chartTheme()) {
    return {
        backgroundColor: theme.elevated,
        borderColor: theme.border,
        borderWidth: 1,
        padding: [6, 10],
        textStyle: { color: theme.primary, fontFamily: theme.font, fontSize: 12 },
        extraCssText: "border-radius: 8px; box-shadow: none;",
    };
};
