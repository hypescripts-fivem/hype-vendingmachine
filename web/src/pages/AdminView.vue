<template>
    <main class="flex h-225 w-7xl overflow-hidden rounded-[1rem] border border-border bg-bg-base">
        <PanelSidebar
            :model-value="admin.section"
            :icon="ShieldCheck"
            :sections="sections"
            :alerts="admin.lowStockMachines.length ? ['machines'] : []"
            @update:model-value="navigate"
        />

        <div class="relative flex min-w-0 flex-1 flex-col">
            <header class="flex h-16 shrink-0 items-center gap-4 border-b border-border px-5">
                <div class="leading-tight">
                    <h2 class="text-sm font-semibold text-text-primary">{{ admin.editing ? "Machine settings" : current.label }}</h2>
                    <p class="text-xs text-text-faint">{{ admin.editing ? `Editing ${admin.editing.name}` : current.description }}</p>
                </div>

                <div class="ml-auto flex items-center gap-4">
                    <div class="text-right leading-tight">
                        <p class="text-[10px] uppercase tracking-wider text-text-faint">Machines</p>
                        <p class="text-sm font-semibold tabular-nums text-text-primary">
                            {{ admin.stats.total }} <span class="font-normal text-text-faint">· {{ admin.stats.open }} open</span>
                        </p>
                    </div>

                    <Separator orientation="vertical" class="h-8" />

                    <span class="inline-flex items-center gap-1.5 rounded-full border border-border bg-bg-muted px-2.5 py-1 text-xs font-medium text-text-primary">
                        <ShieldCheck class="size-3.5" />
                        Admin
                    </span>
                </div>
            </header>

            <section class="min-h-0 flex-1 overflow-y-auto p-5">
                <component :is="pages[admin.section]" />
            </section>
        </div>
    </main>
</template>

<script setup lang="ts">
import { computed, type Component } from "vue";
import { ShieldCheck } from "@lucide/vue";
import { Separator } from "@vezironi/veyra-ui";
import PanelSidebar from "@/components/PanelSidebar.vue";
import AdminDashboard from "@/components/admin/AdminDashboard.vue";
import AdminMachines from "@/components/admin/AdminMachines.vue";
import AdminSettings from "@/components/admin/AdminSettings.vue";
import { sections } from "@/components/admin/sections";
import { useAdminStore, type AdminSection } from "@/stores/admin";

const admin = useAdminStore();

const pages: Record<AdminSection, Component> = {
    dashboard: AdminDashboard,
    machines: AdminMachines,
    settings: AdminSettings,
};

const current = computed(() => sections.find((section) => section.value === admin.section)!);

// Clicking a section in the sidebar always lands on its top level, closing any open machine page
function navigate(section: AdminSection) {
    admin.section = section;
    admin.editingId = undefined;
};
</script>
