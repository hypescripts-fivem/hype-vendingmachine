<template>
    <NoProducts v-if="!shop.products.length" />

    <DataTable v-else v-model:sort="sort" :columns="columns" :rows="rows" :page-size="15" empty-text="No products">
        <template #cell="{ column, row }">
            <template v-if="productOf(row)">
                <div v-if="column.key === 'name'" class="flex items-center gap-3">
                    <ProductThumb :product="productOf(row)!" />
                    <span class="truncate font-medium text-text-primary">{{ row.name }}</span>
                </div>

                <span v-else-if="column.key === 'category'" class="capitalize text-text-muted">{{ row.category }}</span>

                <span v-else-if="column.key === 'sold'" class="tabular-nums text-text-muted">{{ row.sold }}</span>

                <div v-else-if="column.key === 'stock'" class="flex w-48 items-center gap-2">
                    <span class="w-14 tabular-nums" :class="stockClass(Number(row.stock))">
                        {{ row.stock }}<span class="text-text-faint"> / {{ owner.capacity }}</span>
                    </span>
                    <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-bg-muted">
                        <div
                            class="h-full rounded-full"
                            :class="owner.isLowStock(Number(row.stock)) ? 'bg-warning' : 'bg-text-muted'"
                            :style="{ width: `${(Number(row.stock) / owner.capacity) * 100}%` }"
                        />
                    </div>
                    <TriangleAlert v-if="owner.isLowStock(Number(row.stock))" class="size-4 shrink-0 text-warning" aria-label="Low stock" />
                </div>

                <div v-else-if="column.key === 'price'" class="w-28">
                    <Inputs v-model="drafts[String(row.id)]" type="number" size="sm" :min="0" />
                </div>

                <Button
                    v-else-if="column.key === 'actions'"
                    size="sm"
                    :disabled="!isDirty(productOf(row)!) || savingId === row.id"
                    @click="save(productOf(row)!)"
                >
                    {{ savingId === row.id ? "Saving..." : "Save" }}
                </Button>
            </template>
        </template>
    </DataTable>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watchEffect } from "vue";
import { TriangleAlert } from "@lucide/vue";
import { Button, DataTable, Inputs, type DataTableColumn, type DataTableRow } from "@vezironi/veyra-ui";
import ProductThumb from "@/components/ProductThumb.vue";
import { useShopStore, type Product } from "@/stores";
import { useOwnerStore } from "@/stores/owner";
import NoProducts from "./NoProducts.vue";
import { currencySymbol } from "@/utils/format";

const shop = useShopStore();
const owner = useOwnerStore();

const sort = ref<{ key: string; direction: "asc" | "desc" } | null>(null);
const drafts = reactive<Record<string, string | number | undefined>>({});
const savingId = ref<string>();

const columns: DataTableColumn[] = [
    { key: "name", label: "Product", sortable: true },
    { key: "category", label: "Category", sortable: true },
    { key: "sold", label: "Sold", sortable: true, align: "right" },
    { key: "stock", label: "Stock", sortable: true },
    { key: "price", label: `Price (${currencySymbol()})`, sortable: true },
    { key: "actions", label: "", align: "right" },
];

const rows = computed(() => shop.products.map((product) => ({
    id: product.id,
    name: product.name,
    category: product.category,
    sold: owner.unitsSold[product.id] ?? 0,
    stock: product.stock,
    price: product.price,
})));

watchEffect(() => {
    for (const product of shop.products) {
        drafts[product.id] ??= product.price;
    }
});

function productOf(row: DataTableRow): Product | undefined {
    return shop.products.find((product) => product.id === row.id);
};

function parse(value: string | number | undefined): number {
    const number = Math.floor(Number(value));
    return Number.isFinite(number) ? Math.max(0, number) : 0;
};

function stockClass(stock: number): string {
    if (stock < 1) return "text-danger";
    if (owner.isLowStock(stock)) return "text-warning";
    return "text-text-primary";
};

function isDirty(product: Product): boolean {
    return parse(drafts[product.id]) !== product.price;
};

async function save(product: Product) {
    const price = parse(drafts[product.id]);

    savingId.value = product.id;

    try {
        const response = await owner.updatePrice(product.id, price);
        if (response?.success) drafts[product.id] = price;
    } finally {
        savingId.value = undefined;
    }
};
</script>
