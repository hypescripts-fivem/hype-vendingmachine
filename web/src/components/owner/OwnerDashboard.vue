<template>
    <NoProducts v-if="!shop.products.length" />

    <div v-else class="flex flex-col gap-4">
        <div class="grid grid-cols-4 gap-3">
            <StatCard
                label="Today's revenue"
                :value="formatMoney(owner.todayRevenue)"
                :icon="DollarSign"
                :change="owner.revenueChange"
                change-label="vs yesterday"
            />
            <StatCard label="Weekly revenue" :value="formatMoney(owner.weekRevenue)" :icon="TrendingUp" change-label="Last 7 days" />
            <StatCard label="Items sold" :value="owner.weekSales" :icon="ShoppingBag" change-label="Last 7 days" />
            <StatCard label="Low stock" :value="owner.lowStock.length" suffix="products" :icon="TriangleAlert" :change-label="`${owner.settings.lowStockThreshold} or fewer left`" />
        </div>

        <div class="grid grid-cols-3 gap-3">
            <section class="col-span-2 rounded-2xl border border-border bg-bg-surface p-4">
                <header class="flex items-baseline justify-between">
                    <h3 class="text-sm font-semibold text-text-primary">Revenue</h3>
                    <span class="text-xs text-text-faint">Last 7 days</span>
                </header>
                <div class="mt-2 h-56">
                    <EChart v-if="hasRevenue" :option="revenueOption" />
                    <p v-else class="flex h-full items-center justify-center text-xs text-text-faint">No sales in the last 7 days</p>
                </div>
            </section>

            <section class="rounded-2xl border border-border bg-bg-surface p-4">
                <header class="flex items-baseline justify-between">
                    <h3 class="text-sm font-semibold text-text-primary">Top products</h3>
                    <span class="text-xs text-text-faint">Units sold</span>
                </header>
                <ul v-if="ranked.length" class="mt-2 flex flex-wrap gap-x-3 gap-y-1">
                    <li v-for="category in topCategories" :key="category" class="flex items-center gap-1.5 text-xs capitalize text-text-muted">
                        <span class="size-2 rounded-sm" :style="{ backgroundColor: categoryColor(category, theme) }" />
                        {{ category }}
                    </li>
                </ul>
                <div class="mt-1 h-50">
                    <EChart v-if="ranked.length" :option="topProductsOption" />
                    <p v-else class="flex h-full items-center justify-center text-xs text-text-faint">Nothing sold yet</p>
                </div>
            </section>
        </div>

        <section class="rounded-2xl border border-border bg-bg-surface">
            <header class="flex items-center justify-between px-4 py-3">
                <h3 class="text-sm font-semibold text-text-primary">Recent sales</h3>
                <button
                    v-if="owner.canSection('transactions')"
                    type="button"
                    class="text-xs text-text-faint transition-colors hover:text-text-primary"
                    @click="owner.section = 'transactions'"
                >
                    View all
                </button>
            </header>
            <p v-if="!owner.transactions.length" class="border-t border-border px-4 py-6 text-center text-xs text-text-faint">
                No sales yet.
            </p>
            <ul v-else class="divide-y divide-border border-t border-border">
                <li
                    v-for="transaction in owner.transactions.slice(0, 7)"
                    :key="transaction.id"
                    class="flex items-center gap-3 px-4 py-2.5 text-sm"
                >
                    <span class="w-28 shrink-0 text-xs tabular-nums text-text-faint">{{ formatDateTime(transaction.time) }}</span>
                    <span class="min-w-0 flex-1 truncate text-text-primary">
                        {{ owner.productName(transaction.productId) }}
                        <span class="text-text-faint">× {{ transaction.quantity }}</span>
                    </span>
                    <span class="w-32 truncate text-text-muted">{{ transaction.buyer }}</span>
                    <span class="w-16 text-right font-semibold tabular-nums text-text-primary">
                        {{ formatMoney(transaction.total) }}
                    </span>
                </li>
            </ul>
        </section>
    </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { DollarSign, ShoppingBag, TrendingUp, TriangleAlert } from "@lucide/vue";
import { StatCard } from "@vezironi/veyra-ui";
import EChart, { type ChartOption } from "@/components/EChart.vue";
import { useShopStore } from "@/stores";
import { useOwnerStore } from "@/stores/owner";
import { alpha, categoryColor, chartTheme, tooltipStyle } from "@/utils/chart";
import NoProducts from "./NoProducts.vue";
import { formatDateTime, formatDay, formatMoney } from "@/utils/format";

const shop = useShopStore();
const owner = useOwnerStore();

// An all-zero chart is just empty axes, so these decide when to show a note instead
const hasRevenue = computed(() => owner.revenue.some((day) => day.revenue > 0));
const ranked = computed(() => owner.topProducts.filter(({ units }) => units > 0));

const theme = chartTheme();

const axisLabel = { color: theme.faint, fontFamily: theme.font, fontSize: 11 };

const revenueOption = computed<ChartOption>(() => ({
    grid: { left: 8, right: 12, top: 12, bottom: 4, containLabel: true },
    tooltip: {
        ...tooltipStyle(theme),
        trigger: "axis",
        axisPointer: { type: "line", lineStyle: { color: theme.faint, width: 1 } },
        formatter: (params: any) => {
            const day = owner.revenue[params[0].dataIndex]!;
            return `<div style="color:${theme.muted}">${formatDay(day.date)}</div>`
                + `<b>${formatMoney(day.revenue)}</b> <span style="color:${theme.muted}">· ${day.sales} sales</span>`;
        },
    },
    xAxis: {
        type: "category",
        boundaryGap: false,
        data: owner.revenue.map((day) => formatDay(day.date)),
        axisLine: { lineStyle: { color: theme.border } },
        axisTick: { show: false },
        axisLabel,
    },
    yAxis: {
        type: "value",
        splitNumber: 4,
        splitLine: { lineStyle: { color: theme.border } },
        axisLabel: { ...axisLabel, formatter: (value: number) => formatMoney(value) },
    },
    series: [{
        type: "line",
        name: "Revenue",
        data: owner.revenue.map((day) => day.revenue),
        smooth: 0.3,
        symbol: "circle",
        symbolSize: 8,
        showSymbol: false,
        lineStyle: { width: 2, color: theme.primary },
        itemStyle: { color: theme.primary, borderColor: theme.surface, borderWidth: 2 },
        emphasis: { scale: false },
        areaStyle: {
            color: {
                type: "linear", x: 0, y: 0, x2: 0, y2: 1,
                colorStops: [
                    { offset: 0, color: alpha(theme.primary, 0.16) },
                    { offset: 1, color: alpha(theme.primary, 0) },
                ],
            },
        },
    }],
}));

const topCategories = computed(() => [...new Set(ranked.value.map(({ product }) => product.category))]);

const topProductsOption = computed<ChartOption>(() => ({
    grid: { left: 4, right: 32, top: 4, bottom: 4, containLabel: true },
    tooltip: {
        ...tooltipStyle(theme),
        trigger: "item",
        formatter: (params: any) => {
            const { product } = ranked.value[params.dataIndex]!;
            return `${product.name} <span style="color:${theme.muted};text-transform:capitalize">· ${product.category}</span>`
                + `<br/><b>${params.value}</b> <span style="color:${theme.muted}">units sold</span>`;
        },
    },
    xAxis: { type: "value", show: false },
    yAxis: {
        type: "category",
        inverse: true,
        data: ranked.value.map(({ product }) => product.name),
        axisLine: { show: false },
        axisTick: { show: false },
        axisLabel: { ...axisLabel, color: theme.muted },
    },
    series: [{
        type: "bar",
        name: "Units sold",
        data: ranked.value.map(({ product, units }) => ({
            value: units,
            itemStyle: { color: categoryColor(product.category, theme) },
        })),
        barWidth: 12,
        itemStyle: { borderRadius: [0, 4, 4, 0] },
        emphasis: { disabled: true },
        label: { show: true, position: "right", color: theme.muted, fontFamily: theme.font, fontSize: 11 },
    }],
}));
</script>
