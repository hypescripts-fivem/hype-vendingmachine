<template>
    <span class="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium" :class="meta.class">
        <span class="size-1.5 rounded-full bg-current" />
        {{ meta.label }}
    </span>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { MachineDisplayStatus } from "@/stores/admin";

const props = defineProps<{ status: MachineDisplayStatus }>();

const statusMeta: Record<MachineDisplayStatus, { label: string; class: string }> = {
    open: { label: "Open", class: "bg-success/10 text-success" },
    closed: { label: "Closed", class: "bg-bg-muted text-text-muted" },
    forSale: { label: "For sale", class: "bg-info/10 text-info" },
    disabled: { label: "Disabled", class: "bg-danger/10 text-danger" },
};

const meta = computed(() => statusMeta[props.status]);
</script>
