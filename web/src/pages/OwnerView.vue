<template>
    <main class="flex h-225 w-7xl overflow-hidden rounded-[1rem] border border-border bg-bg-base">
        <PanelSidebar
            v-model="owner.section"
            :icon="Store"
            :sections="visibleSections"
            :alerts="owner.lowStock.length && owner.canSection('restock') ? ['restock'] : []"
        />

        <div class="relative flex min-w-0 flex-1 flex-col">
            <header class="flex h-16 shrink-0 items-center gap-4 border-b border-border px-5">
                <div v-if="current" class="leading-tight">
                    <h2 class="text-sm font-semibold text-text-primary">{{ current.label }}</h2>
                    <p class="text-xs text-text-faint">{{ current.description }}</p>
                </div>

                <div class="ml-auto flex items-center gap-4">
                    <div class="text-right leading-tight">
                        <p class="text-sm font-medium text-text-primary">{{ owner.settings.name }}</p>
                        <p class="flex items-center justify-end gap-1.5 text-xs" :class="owner.settings.open ? 'text-success' : 'text-text-faint'">
                            <span class="size-1.5 rounded-full bg-current" />
                            {{ owner.settings.open ? "Open" : "Closed" }}
                        </p>
                    </div>

                    <template v-if="owner.can('cash.history')">
                        <Separator orientation="vertical" class="h-8" />

                        <div class="text-right leading-tight">
                            <p class="text-[10px] uppercase tracking-wider text-text-faint">Balance</p>
                            <p class="text-sm font-semibold tabular-nums text-text-primary">
                                {{ formatMoney(owner.balance) }}
                            </p>
                        </div>
                    </template>
                </div>
            </header>

            <section class="min-h-0 flex-1 overflow-y-auto p-5">
                <component :is="pages[current.value]" v-if="current" />
                <EmptyState
                    v-else
                    title="No access"
                    description="Ask the owner to give you permissions for this machine."
                    :icon="Lock"
                />
            </section>
        </div>
    </main>
</template>

<script setup lang="ts">
import { computed, watch, type Component } from "vue";
import { Lock, Store } from "@lucide/vue";
import { EmptyState, Separator } from "@vezironi/veyra-ui";
import PanelSidebar from "@/components/PanelSidebar.vue";
import OwnerDashboard from "@/components/owner/OwnerDashboard.vue";
import OwnerProducts from "@/components/owner/OwnerProducts.vue";
import OwnerRestock from "@/components/owner/OwnerRestock.vue";
import OwnerTransactions from "@/components/owner/OwnerTransactions.vue";
import OwnerCash from "@/components/owner/OwnerCash.vue";
import OwnerStaff from "@/components/owner/OwnerStaff.vue";
import OwnerSettings from "@/components/owner/OwnerSettings.vue";
import { sections } from "@/components/owner/sections";
import { useOwnerStore, type OwnerSection } from "@/stores/owner";
import { formatMoney } from "@/utils/format";

const owner = useOwnerStore();

const pages: Record<OwnerSection, Component> = {
    dashboard: OwnerDashboard,
    products: OwnerProducts,
    restock: OwnerRestock,
    transactions: OwnerTransactions,
    cash: OwnerCash,
    staff: OwnerStaff,
    settings: OwnerSettings,
};

// A section shows up when the viewer has at least one of its permissions
const visibleSections = computed(() => sections.filter((section) => owner.canSection(section.value)));

const current = computed(() => visibleSections.value.find((section) => section.value === owner.section));

// Staff without dashboard access would otherwise open on a hidden page
watch(visibleSections, (visible) => {
    if (!current.value && visible[0]) owner.section = visible[0].value;
}, { immediate: true });
</script>
