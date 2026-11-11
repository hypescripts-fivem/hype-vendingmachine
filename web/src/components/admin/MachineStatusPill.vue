<template>
    <span class="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium" :class="meta.class">
        <span class="size-1.5 rounded-full bg-current" />
        {{ t(meta.label) }}
    </span>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { MachineDisplayStatus } from "@/stores/admin";
import { t } from "@/utils/locale";

const props = defineProps<{ status: MachineDisplayStatus }>();

const statusMeta: Record<MachineDisplayStatus, { label: string; class: string }> = {
    open: { label: "admin.status.open", class: "bg-success/10 text-success" },
    closed: { label: "admin.status.closed", class: "bg-bg-muted text-text-muted" },
    forSale: { label: "admin.status.for_sale", class: "bg-info/10 text-info" },
    disabled: { label: "admin.status.disabled", class: "bg-danger/10 text-danger" },
};

const meta = computed(() => statusMeta[props.status]);
</script>
