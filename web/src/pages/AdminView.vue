<template>
    <!-- Hidden, not unmounted, while placing a machine: the form keeps everything that was filled in -->
    <main v-show="!placement.active" class="flex h-225 w-7xl overflow-hidden rounded-[1rem] border border-border bg-bg-base">
        <PanelSidebar
            :model-value="admin.section"
            :icon="ShieldCheck"
            :sections="localizedSections"
            :alerts="admin.lowStockMachines.length ? ['machines'] : []"
            @update:model-value="navigate"
        />

        <div class="relative flex min-w-0 flex-1 flex-col">
            <header class="flex h-16 shrink-0 items-center gap-4 border-b border-border px-5">
                <div class="leading-tight">
                    <h2 class="text-sm font-semibold text-text-primary">{{ admin.editing ? t("admin.header.machine_settings") : t(current.label) }}</h2>
                    <p class="text-xs text-text-faint">{{ admin.editing ? t("admin.header.editing", admin.editing.name) : t(current.description) }}</p>
                </div>

                <div class="ml-auto flex items-center gap-4">
                    <div class="text-right leading-tight">
                        <p class="text-[10px] uppercase tracking-wider text-text-faint">{{ t("admin.header.machines") }}</p>
                        <p class="text-sm font-semibold tabular-nums text-text-primary">
                            {{ admin.stats.total }} <span class="font-normal text-text-faint">· {{ t("admin.header.open_count", admin.stats.open) }}</span>
                        </p>
                    </div>

                    <Separator orientation="vertical" class="h-8" />

                    <span class="inline-flex items-center gap-1.5 rounded-full border border-border bg-bg-muted px-2.5 py-1 text-xs font-medium text-text-primary">
                        <ShieldCheck class="size-3.5" />
                        {{ t("admin.header.badge") }}
                    </span>
                </div>
            </header>

            <section class="min-h-0 flex-1 overflow-y-auto p-5">
                <component :is="pages[admin.section]" />
            </section>
        </div>
    </main>

    <template v-if="placement.active">
        <PlacementOverlay />
        <PlacementPanel />
    </template>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, watch, type Component } from "vue";
import { ShieldCheck } from "@lucide/vue";
import { Separator } from "@vezironi/veyra-ui";
import PanelSidebar from "@/components/PanelSidebar.vue";
import AdminDashboard from "@/components/admin/AdminDashboard.vue";
import AdminMachines from "@/components/admin/AdminMachines.vue";
import AdminSettings from "@/components/admin/AdminSettings.vue";
import PlacementOverlay from "@/components/admin/PlacementOverlay.vue";
import PlacementPanel from "@/components/admin/PlacementPanel.vue";
import { sections } from "@/components/admin/sections";
import { useAdminStore, type AdminSection } from "@/stores/admin";
import { usePlacementStore } from "@/stores/placement";
import { t } from "@/utils/locale";

const admin = useAdminStore();
const placement = usePlacementStore();

// Modals are teleported to <body>, outside this page: the class hides them (still mounted) while placing
watch(() => placement.active, (active) => document.body.classList.toggle("placing", active));
onBeforeUnmount(() => document.body.classList.remove("placing"));

const pages: Record<AdminSection, Component> = {
    dashboard: AdminDashboard,
    machines: AdminMachines,
    settings: AdminSettings,
};

const current = computed(() => sections.find((section) => section.value === admin.section)!);

const localizedSections = computed(() => sections.map((section) => ({ ...section, label: t(section.label), description: t(section.description) })));

// Clicking a section in the sidebar always lands on its top level, closing any open machine page
function navigate(section: AdminSection) {
    admin.section = section;
    admin.editingId = undefined;
};
</script>
