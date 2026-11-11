<template>
    <DataTable v-model:sort="sort" :columns="columns" :rows="rows" :page-size="15" :empty-text="t('owner.transactions.empty')">
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
import { t } from "@/utils/locale";

const owner = useOwnerStore();

const sort = ref<{ key: string; direction: "asc" | "desc" } | null>(null);

const columns = computed<DataTableColumn[]>(() => [
    { key: "time", label: t("owner.transactions.time"), sortable: true },
    { key: "buyer", label: t("owner.transactions.buyer"), sortable: true },
    { key: "product", label: t("owner.transactions.product"), sortable: true },
    { key: "quantity", label: t("owner.transactions.quantity"), sortable: true, align: "right" },
    { key: "total", label: t("owner.transactions.total"), sortable: true, align: "right" },
]);

const rows = computed(() => owner.transactions.map((transaction) => ({
    id: transaction.id,
    time: transaction.time,
    buyer: transaction.buyer,
    product: owner.productName(transaction.productId),
    quantity: transaction.quantity,
    total: transaction.total,
})));
</script>
