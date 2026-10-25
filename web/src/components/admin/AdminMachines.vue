<template>
    <AdminMachineDetail v-if="admin.editing" :key="admin.editing.id" :machine="admin.editing" />

    <!-- Table on the left, the map runs the full height on the right -->
    <div v-else class="flex h-full gap-3">
        <div class="flex min-w-0 flex-1 flex-col gap-3">
            <div class="flex items-center gap-2">
                <div class="relative min-w-0 flex-1 mr-20">
                    <Search class="pointer-events-none absolute top-1/2 left-3 z-10 size-4 -translate-y-1/2 text-text-faint" />
                    <Inputs v-model="search" size="sm" class="py-2 pl-9 text-sm" placeholder="Search name, owner or area..." />
                </div>
                <Button size="sm" variant="outline" class="shrink-0 py-2.5" @click="importing = true">
                    <Upload class="size-3.5" />
                    Import
                </Button>
                <Button size="sm" variant="solid" class="shrink-0 py-2.5" @click="creating = true">
                    <Plus class="size-3.5" />
                    New machine
                </Button>
            </div>

            <!-- The table gets whatever height is left; rows that don't fit go to the next page instead of scrolling -->
            <div ref="tableArea" class="min-h-0 flex-1">
                <DataTable
                    v-model:sort="sort"
                    v-model:page="page"
                    :columns="columns"
                    :rows="rows"
                    :page-size="pageSize"
                    :empty-text="admin.machines.length ? 'No machines match your search' : 'No machines yet. Create one or import them.'"
                >
                    <template #cell="{ column, row }">
                        <div v-if="column.key === 'name'" class="whitespace-nowrap leading-tight">
                            <p class="font-medium text-text-primary">{{ row.name }}</p>
                            <p class="text-xs text-text-faint">{{ row.area }}</p>
                        </div>
                        <span v-else-if="column.key === 'owner'" class="whitespace-nowrap" :class="row.owner ? 'text-text-muted' : 'text-text-faint'">
                            {{ row.owner ?? "For sale" }}
                        </span>
                        <MachineStatusPill v-else-if="column.key === 'status'" :status="row.status as MachineDisplayStatus" />
                        <span v-else-if="column.key === 'balance'" class="tabular-nums text-text-primary">
                            {{ formatMoney(Number(row.balance)) }}
                        </span>
                        <div v-else-if="column.key === 'actions'" class="flex items-center justify-end gap-1.5">
                            <Tooltip content="Show on map" side="top">
                                <Button variant="secondary" size="sm" class="p-2" aria-label="Show on map" @click="locate(String(row.id))">
                                    <MapPin class="size-3.5" />
                                </Button>
                            </Tooltip>
                            <Tooltip content="Teleport" side="top">
                                <Button variant="secondary" size="sm" class="p-2" aria-label="Teleport" @click="admin.teleport(String(row.id))">
                                    <Navigation class="size-3.5" />
                                </Button>
                            </Tooltip>
                            <Tooltip content="Manage" side="top">
                                <Button size="sm" class="p-2" aria-label="Manage" @click="admin.openMachine(String(row.id))">
                                    <Settings class="size-3.5" />
                                </Button>
                            </Tooltip>
                        </div>
                        <template v-else>{{ row[column.key] }}</template>
                    </template>
                </DataTable>
            </div>
        </div>

        <section class="flex w-[26rem] shrink-0 flex-col overflow-hidden rounded-2xl border border-border bg-bg-surface">
            <header class="flex items-center justify-between gap-3 px-4 py-3">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <MapPin class="size-4 text-text-muted" /> Map
                </h3>
                <ul class="flex items-center gap-3">
                    <li v-for="item in mapLegend" :key="item.status" class="flex items-center gap-1.5 text-xs text-text-muted">
                        <span class="size-2 rounded-full" :style="{ background: item.color }" />
                        {{ item.label }}
                    </li>
                </ul>
            </header>
            <!-- isolate keeps Leaflet's pane z-indexes (400+) from leaking over the rest of the panel -->
            <div class="relative isolate min-h-0 flex-1 border-t border-border">
                <GameMap ref="map" :blips="blips" @blip-click="admin.openMachine" />
            </div>
            <p class="border-t border-border px-4 py-2 text-xs text-text-faint">Click a blip to manage the machine</p>
        </section>

        <AdminCreateMachine v-if="creating" @close="creating = false" />
        <MachineImportModal v-if="importing" @close="importing = false" />
    </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { MapPin, Navigation, Plus, Search, Settings, Upload } from "@lucide/vue";
import { Button, DataTable, Inputs, Tooltip, type DataTableColumn } from "@vezironi/veyra-ui";
import GameMap, { type MapBlip } from "@/components/map/GameMap.vue";
import { displayStatus, useAdminStore, type MachineDisplayStatus } from "@/stores/admin";
import AdminCreateMachine from "./AdminCreateMachine.vue";
import AdminMachineDetail from "./AdminMachineDetail.vue";
import MachineImportModal from "./MachineImportModal.vue";
import MachineStatusPill from "./MachineStatusPill.vue";
import { formatMoney } from "@/utils/format";

const admin = useAdminStore();

const search = ref<string | number | undefined>("");
const sort = ref<{ key: string; direction: "asc" | "desc" } | null>(null);
const creating = ref(false);
const importing = ref(false);

const columns: DataTableColumn[] = [
    { key: "name", label: "Machine", sortable: true },
    { key: "owner", label: "Owner", sortable: true },
    { key: "status", label: "Status", sortable: true },
    { key: "balance", label: "Balance", sortable: true, align: "right" },
    { key: "actions", label: "", align: "right" },
];

const map = ref<InstanceType<typeof GameMap>>();

// The map and the table show the same searched set
const filteredMachines = computed(() => {
    const query = String(search.value ?? "").trim().toLowerCase();

    return admin.machines.filter((machine) => !query || [machine.name, machine.ownerName ?? "", machine.location.label]
        .some((value) => value.toLowerCase().includes(query)));
});

const rows = computed(() => filteredMachines.value.map((machine) => ({
    id: machine.id,
    name: machine.name,
    area: machine.location.label,
    owner: machine.ownerName,
    status: displayStatus(machine),
    balance: machine.balance,
})));

// Measured from the rendered DataTable: header row plus the table border, one machine row and the pagination bar
const TABLE_HEAD = 42;
const TABLE_ROW = 58;
const TABLE_FOOTER = 46;

const tableArea = ref<HTMLElement>();
const tableHeight = ref(0);
const page = ref(1);

// The area only exists while the list is shown, so it's observed again after coming back from a machine
watch(tableArea, (element, _, onCleanup) => {
    if (!element) return;

    const observer = new ResizeObserver(([entry]) => tableHeight.value = entry?.contentRect.height ?? 0);
    observer.observe(element);
    onCleanup(() => observer.disconnect());
});

// As many rows as fit; the pagination bar only takes room once there's more than one page
const pageSize = computed(() => {
    if (!tableHeight.value) return 12;

    const fit = (space: number) => Math.max(1, Math.floor((space - TABLE_HEAD) / TABLE_ROW));
    const all = fit(tableHeight.value);

    return rows.value.length <= all ? all : fit(tableHeight.value - TABLE_FOOTER);
});

watch(search, () => page.value = 1);

// Fewer pages after resizing or searching: stay on the last one instead of an empty page
watch([pageSize, () => rows.value.length], () => {
    page.value = Math.min(page.value, Math.max(1, Math.ceil(rows.value.length / pageSize.value)));
});

// Blips live in the DOM, so they can use the theme's status tokens directly
const statusBlips: Record<MachineDisplayStatus, { label: string; color: string }> = {
    open: { label: "Open", color: "var(--color-success)" },
    closed: { label: "Closed", color: "var(--color-text-faint)" },
    forSale: { label: "For sale", color: "var(--color-info)" },
    disabled: { label: "Disabled", color: "var(--color-danger)" },
};

const mapLegend = (Object.keys(statusBlips) as MachineDisplayStatus[]).map((status) => ({ status, ...statusBlips[status] }));

const blips = computed<MapBlip[]>(() => filteredMachines.value.map((machine) => {
    const blip = statusBlips[displayStatus(machine)];

    return {
        id: machine.id,
        coords: { x: machine.location.x, y: machine.location.y },
        label: `${machine.name} · ${blip.label}`,
        color: blip.color,
    };
}));

function locate(id: string) {
    const machine = admin.machines.find((entry) => entry.id === id);
    if (machine) map.value?.focus(machine.location, 3);
};
</script>
