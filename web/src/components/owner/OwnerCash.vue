<template>
    <div class="flex flex-col gap-4">
        <div v-if="owner.can('cash.history')" class="grid grid-cols-3 gap-3">
            <StatCard :label="t('owner.cash.balance')" :value="formatMoney(owner.balance)" :icon="Banknote" :change-label="t('owner.cash.balance_hint')" />
            <StatCard :label="t('owner.cash.deposited')" :value="formatMoney(owner.totalDeposited)" :icon="ArrowDownLeft" :change-label="t('owner.cash.all_time')" />
            <StatCard :label="t('owner.cash.withdrawn')" :value="formatMoney(owner.totalWithdrawn)" :icon="ArrowUpRight" :change-label="t('owner.cash.all_time')" />
        </div>

        <div class="grid grid-cols-5 gap-3">
            <section v-if="tabs.length" class="col-span-2 flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <Tabs v-if="tabs.length > 1" v-model="mode" :tabs="tabs" />
                <h3 v-else class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <component :is="tabs[0]!.icon" class="size-4 text-text-muted" /> {{ tabs[0]!.label }}
                </h3>

                <label class="grid gap-1.5 text-sm text-text-muted">
                    {{ t("owner.cash.amount", currencySymbol()) }}
                    <Inputs v-model="amount" type="number" :min="1" placeholder="0" />
                </label>

                <!-- Presets add to what's typed, so $1,000 then +$100 makes $1,100 -->
                <div class="grid grid-cols-4 gap-2">
                    <Button
                        v-for="preset in presets"
                        :key="preset"
                        variant="outline"
                        size="sm"
                        :disabled="parsedAmount + preset > available"
                        @click="amount = parsedAmount + preset"
                    >
                        +{{ formatMoney(preset) }}
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        :disabled="available < 1"
                        @click="amount = available"
                    >
                        {{ t("owner.cash.all") }}
                    </Button>
                </div>

                <p v-if="error" class="flex items-center gap-1.5 text-xs text-danger">
                    <CircleAlert class="size-3.5 shrink-0" />
                    {{ error }}
                </p>
                <p v-else class="text-xs text-text-faint">
                    {{ mode === "withdraw"
                        ? t("owner.cash.withdraw_hint", formatMoney(owner.balance))
                        : t("owner.cash.deposit_hint", formatMoney(owner.wallet)) }}
                </p>

                <Button class="mt-auto w-full" :disabled="!canSubmit" @click="submit">
                    <component :is="mode === 'withdraw' ? ArrowUpRight : ArrowDownLeft" class="size-4" />
                    {{ owner.cashBusy ? t("owner.cash.processing") : mode === "withdraw" ? t("owner.cash.withdraw") : t("owner.cash.deposit") }}
                </Button>
            </section>

            <section
                v-if="owner.can('cash.history')"
                class="flex flex-col rounded-2xl border border-border bg-bg-surface"
                :class="tabs.length ? 'col-span-3' : 'col-span-5'"
            >
                <header class="flex items-baseline justify-between px-4 py-3">
                    <h3 class="text-sm font-semibold text-text-primary">{{ t("owner.cash.history") }}</h3>
                    <span class="text-xs text-text-faint">{{ t("owner.cash.movements", owner.cashMovements.length) }}</span>
                </header>

                <EmptyState
                    v-if="!owner.cashMovements.length"
                    :title="t('owner.cash.no_movements')"
                    :icon="Banknote"
                    class="border-none bg-transparent"
                />

                <ul v-else class="max-h-80 divide-y divide-border overflow-y-auto border-t border-border">
                    <li v-for="movement in owner.cashMovements" :key="movement.id" class="flex items-center gap-3 px-4 py-2.5">
                        <span
                            class="flex size-8 shrink-0 items-center justify-center rounded-lg"
                            :class="movement.type === 'deposit' ? 'bg-success/10 text-success' : 'bg-danger/10 text-danger'"
                        >
                            <component :is="movementMeta[movement.type].icon" class="size-4" />
                        </span>
                        <div class="min-w-0 flex-1 leading-tight">
                            <p class="text-sm font-medium text-text-primary">{{ t(movementMeta[movement.type].label) }}</p>
                            <p class="text-xs tabular-nums text-text-faint">{{ formatDateTime(movement.time) }} · {{ movement.by }}</p>
                        </div>
                        <span
                            class="text-sm font-semibold tabular-nums"
                            :class="movement.type === 'deposit' ? 'text-success' : 'text-danger'"
                        >
                            {{ movement.type === "deposit" ? "+" : "−" }}{{ formatMoney(movement.amount) }}
                        </span>
                    </li>
                </ul>
            </section>
        </div>
    </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { ArrowDownLeft, ArrowUpRight, Banknote, CircleAlert, Truck } from "@lucide/vue";
import { Button, EmptyState, Inputs, StatCard, Tabs } from "@vezironi/veyra-ui";
import { useOwnerStore, type CashMovementType } from "@/stores/owner";
import { currencySymbol, formatDateTime, formatMoney } from "@/utils/format";
import { t } from "@/utils/locale";

const owner = useOwnerStore();

const allTabs = [
    { label: "owner.cash.withdraw", value: "withdraw", icon: ArrowUpRight, permission: "cash.withdraw" as const },
    { label: "owner.cash.deposit", value: "deposit", icon: ArrowDownLeft, permission: "cash.deposit" as const },
];

const tabs = computed(() => allTabs
    .filter((tab) => owner.can(tab.permission))
    .map((tab) => ({ ...tab, label: t(tab.label) })));

const presets = [100, 500, 1000];

const movementMeta = {
    deposit: { label: "owner.cash.deposit", icon: ArrowDownLeft },
    withdraw: { label: "owner.cash.withdraw", icon: ArrowUpRight },
    order: { label: "owner.cash.stock_order", icon: Truck },
};

const mode = ref<string | undefined>();

watch(tabs, (available) => {
    if (!available.some((tab) => tab.value === mode.value)) mode.value = available[0]?.value;
}, { immediate: true });
const amount = ref<string | number | undefined>();
const error = ref<string>();

const parsedAmount = computed(() => {
    const value = Math.floor(Number(amount.value));
    return Number.isFinite(value) ? value : 0;
});

// The most this tab can move: the machine balance when withdrawing, the player's cash when depositing
const available = computed(() => (mode.value === "withdraw" ? owner.balance : owner.wallet));

const canSubmit = computed(() =>
    !owner.cashBusy &&
    parsedAmount.value > 0 &&
    parsedAmount.value <= available.value
);

watch([mode, amount], () => {
    error.value = undefined;

    if (parsedAmount.value > available.value) {
        error.value = mode.value === "withdraw" ? t("owner.cash.not_enough_balance") : t("owner.cash.not_enough_cash");
    }
});

async function submit() {
    if (!canSubmit.value) return;

    const response = await owner.moveCash(mode.value as CashMovementType, parsedAmount.value);

    if (response?.success) {
        amount.value = undefined;
    } else if (response) {
        error.value = response.error ?? t("owner.cash.failed");
    }
};
</script>
