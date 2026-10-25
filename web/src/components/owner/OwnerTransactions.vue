<template>
    <DataTable v-model:sort="sort" :columns="columns" :rows="rows" :page-size="15" empty-text="No sales yet">
        <template #cell="{ column, value }">
            <span v-if="column.key === 'total'" class="font-semibold tabular-nums text-text-primary">
                {{ formatMoney(Number(value)) }}
            </span>
            <span v-else-if="column.key === 'time'" class="tabular-nums text-text-faint">{{ formatDateTime(Number(value)) }}</span>
            <template v-else>{{ value }}</template>
        </template>
    </DataTable>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { DataTable, type DataTableColumn } from "@vezironi/veyra-ui";
import { useOwnerStore } from "@/stores/owner";
import { formatDateTime, formatMoney } from "@/utils/format";

const owner = useOwnerStore();

const sort = ref<{ key: string; direction: "asc" | "desc" } | null>(null);

const columns: DataTableColumn[] = [
    { key: "time", label: "Time", sortable: true },
    { key: "buyer", label: "Buyer", sortable: true },
    { key: "product", label: "Product", sortable: true },
    { key: "quantity", label: "Qty", sortable: true, align: "right" },
    { key: "total", label: "Total", sortable: true, align: "right" },
];

const rows = computed(() => owner.transactions.map((transaction) => ({
    id: transaction.id,
    time: transaction.time,
    buyer: transaction.buyer,
    product: owner.productName(transaction.productId),
    quantity: transaction.quantity,
    total: transaction.total,
})));
</script>
