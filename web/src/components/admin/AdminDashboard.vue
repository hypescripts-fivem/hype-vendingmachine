<template>
    <!-- A fresh server has nothing to chart, so the page points at the first step instead -->
    <EmptyState
        v-if="!admin.machines.length"
        :title="t('admin.dashboard.empty_title')"
        :description="t('admin.dashboard.empty_description')"
        :icon="Boxes"
        class="h-full"
    >
        <div class="mt-4 flex items-center gap-2">
            <Button variant="outline" size="sm" @click="importing = true">
                <Upload class="size-3.5" />
                {{ t("admin.common.import") }}
            </Button>
            <Button variant="solid" size="sm" @click="creating = true">
                <Plus class="size-3.5" />
                {{ t("admin.common.new_machine") }}
            </Button>
        </div>

        <AdminCreateMachine v-if="creating" @close="creating = false" />
        <MachineImportModal v-if="importing" @close="importing = false" />
    </EmptyState>

    <div v-else class="flex flex-col gap-4">
        <div class="grid grid-cols-4 gap-3">
            <StatCard :label="t('admin.dashboard.stat_machines')" :value="admin.stats.total" :icon="Boxes" :change-label="t('admin.dashboard.stat_machines_open', admin.stats.open)" />
            <StatCard :label="t('admin.dashboard.stat_revenue')" :value="formatMoney(admin.stats.revenue)" :icon="DollarSign" :change-label="t('admin.dashboard.stat_all_machines')" />
            <StatCard :label="t('admin.dashboard.stat_items_sold')" :value="admin.stats.sales" :icon="ShoppingBag" :change-label="t('admin.dashboard.stat_all_machines')" />
            <StatCard :label="t('admin.dashboard.stat_owners')" :value="admin.stats.owners" :icon="Users" :change-label="t(admin.stats.forSale === 1 ? 'admin.dashboard.stat_for_sale_one' : 'admin.dashboard.stat_for_sale_other', admin.stats.forSale)" />
        </div>

        <div class="grid grid-cols-3 gap-3">
            <section class="col-span-2 rounded-2xl border border-border bg-bg-surface p-4">
                <header class="flex items-baseline justify-between">
                    <h3 class="text-sm font-semibold text-text-primary">{{ t("admin.dashboard.server_revenue") }}</h3>
                    <span class="text-xs text-text-faint">{{ t("admin.dashboard.last_7_days") }}</span>
                </header>
                <div class="mt-2 h-56">
                    <EChart v-if="hasRevenue" :option="revenueOption" />
                    <p v-else class="flex h-full items-center justify-center text-xs text-text-faint">{{ t("admin.dashboard.no_sales") }}</p>
                </div>
            </section>

            <section class="rounded-2xl border border-border bg-bg-surface p-4">
                <header class="flex items-baseline justify-between">
                    <h3 class="text-sm font-semibold text-text-primary">{{ t("admin.dashboard.top_machines") }}</h3>
                    <span class="text-xs text-text-faint">{{ t("admin.dashboard.revenue_currency", currencySymbol()) }}</span>
                </header>
                <div class="mt-2 h-56">
                    <EChart v-if="ranked.length" :option="topMachinesOption" />
                    <p v-else class="flex h-full items-center justify-center text-xs text-text-faint">{{ t("admin.dashboard.no_top_machines") }}</p>
                </div>
            </section>
        </div>

        <div class="grid grid-cols-2 gap-3">
            <section class="rounded-2xl border border-border bg-bg-surface">
                <header class="flex items-baseline justify-between px-4 py-3">
                    <h3 class="text-sm font-semibold text-text-primary">{{ t("admin.dashboard.needs_attention") }}</h3>
                    <span class="text-xs text-text-faint">{{ t("admin.dashboard.machine_count", attention.length) }}</span>
                </header>
                <p v-if="!attention.length" class="border-t border-border px-4 py-6 text-center text-xs text-text-faint">
                    {{ t("admin.dashboard.all_fine") }}
                </p>
                <ul v-else class="divide-y divide-border border-t border-border">
                    <li v-for="{ machine, reason } in attention" :key="machine.id" class="flex items-center gap-3 px-4 py-2.5">
                        <TriangleAlert class="size-4 shrink-0" :class="machine.status === 'disabled' ? 'text-danger' : 'text-warning'" />
                        <div class="min-w-0 flex-1 leading-tight">
                            <p class="truncate text-sm font-medium text-text-primary">{{ machine.name }}</p>
                            <p class="text-xs text-text-faint">{{ reason }}</p>
                        </div>
                        <Button variant="outline" size="sm" @click="admin.openMachine(machine.id)">{{ t("admin.dashboard.open") }}</Button>
                    </li>
                </ul>
            </section>

            <section class="rounded-2xl border border-border bg-bg-surface">
                <header class="flex items-baseline justify-between px-4 py-3">
                    <h3 class="text-sm font-semibold text-text-primary">{{ t("admin.dashboard.newest_machines") }}</h3>
                    <button
                        type="button"
                        class="text-xs text-text-faint transition-colors hover:text-text-primary"
                        @click="admin.section = 'machines'"
                    >
                        {{ t("admin.dashboard.view_all") }}
                    </button>
                </header>
                <ul class="divide-y divide-border border-t border-border">
                    <li v-for="machine in newest" :key="machine.id" class="flex items-center gap-3 px-4 py-2.5">
                        <div class="min-w-0 flex-1 leading-tight">
                            <p class="truncate text-sm font-medium text-text-primary">{{ machine.name }}</p>
                            <p class="text-xs text-text-faint">{{ machine.location.label }} · {{ machine.ownerName ?? t("admin.common.for_sale") }}</p>
                        </div>
                        <span class="text-xs tabular-nums text-text-faint">{{ formatDate(machine.createdAt) }}</span>
                        <MachineStatusPill :status="displayStatus(machine)" />
                    </li>
                </ul>
            </section>
        </div>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { Boxes, DollarSign, Plus, ShoppingBag, TriangleAlert, Upload, Users } from "@lucide/vue";
import { Button, EmptyState, StatCard } from "@vezironi/veyra-ui";
import EChart, { type ChartOption } from "@/components/EChart.vue";
import { displayStatus, useAdminStore } from "@/stores/admin";
import { alpha, chartTheme, seriesColor, tooltipStyle } from "@/utils/chart";
import AdminCreateMachine from "./AdminCreateMachine.vue";
import MachineImportModal from "./MachineImportModal.vue";
import MachineStatusPill from "./MachineStatusPill.vue";
import { currencySymbol, formatDate, formatDay, formatMoney } from "@/utils/format";
import { t } from "@/utils/locale";

const admin = useAdminStore();

const creating = ref(false);
const importing = ref(false);

const theme = chartTheme();

const axisLabel = { color: theme.faint, fontFamily: theme.font, fontSize: 11 };

const attention = computed(() => [
    ...admin.machines
        .filter((machine) => machine.status === "disabled")
        .map((machine) => ({ machine, reason: t("admin.dashboard.reason_disabled") })),
    ...admin.lowStockMachines
        .filter((machine) => machine.status !== "disabled")
        .map((machine) => ({ machine, reason: t("admin.dashboard.reason_low_stock", machine.stockLevel) })),
].slice(0, 5));

const newest = computed(() => admin.machines.slice(0, 5));

// An all-zero chart is just empty axes, so these decide when to show a note instead
const hasRevenue = computed(() => admin.revenue.some((day) => day.revenue > 0));
const ranked = computed(() => admin.topMachines.filter((machine) => machine.revenue > 0));

const revenueOption = computed<ChartOption>(() => ({
    grid: { left: 8, right: 12, top: 12, bottom: 4, containLabel: true },
    tooltip: {
        ...tooltipStyle(theme),
        trigger: "axis",
        axisPointer: { type: "line", lineStyle: { color: theme.faint, width: 1 } },
        formatter: (params: any) => {
            const day = admin.revenue[params[0].dataIndex]!;
            return `<div style="color:${theme.muted}">${formatDay(day.date)}</div><b>${formatMoney(day.revenue)}</b>`;
        },
    },
    xAxis: {
        type: "category",
        boundaryGap: false,
        data: admin.revenue.map((day) => formatDay(day.date)),
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
        name: t("admin.dashboard.series_revenue"),
        data: admin.revenue.map((day) => day.revenue),
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

const topMachinesOption = computed<ChartOption>(() => ({
    grid: { left: 4, right: 44, top: 4, bottom: 4, containLabel: true },
    tooltip: {
        ...tooltipStyle(theme),
        trigger: "item",
        formatter: (params: any) => {
            const machine = ranked.value[params.dataIndex]!;
            return `${machine.name}<br/><b>${formatMoney(machine.revenue)}</b> <span style="color:${theme.muted}">· ${t("admin.dashboard.tooltip_sales", machine.sales)}</span>`;
        },
    },
    xAxis: { type: "value", show: false },
    yAxis: {
        type: "category",
        inverse: true,
        data: ranked.value.map((machine) => machine.name),
        axisLine: { show: false },
        axisTick: { show: false },
        axisLabel: { ...axisLabel, color: theme.muted, width: 110, overflow: "truncate" },
    },
    series: [{
        type: "bar",
        name: t("admin.dashboard.series_revenue"),
        data: ranked.value.map((machine) => ({
            value: machine.revenue,
            itemStyle: { color: seriesColor(machine.colorSlot) },
        })),
        barWidth: 12,
        itemStyle: { borderRadius: [0, 4, 4, 0] },
        emphasis: { disabled: true },
        label: {
            show: true,
            position: "right",
            color: theme.muted,
            fontFamily: theme.font,
            fontSize: 11,
            formatter: (params: any) => formatMoney(Number(params.value)),
        },
    }],
}));
</script>
