<template>
    <article
        :class="[
            'group flex flex-col overflow-hidden rounded-xl border border-border bg-bg-surface transition-colors',
            outOfStock && !inCart ? 'opacity-60' : 'hover:border-bg-elevated',
        ]"
    >
        <div class="relative flex h-32 items-center justify-center border-b border-border bg-bg-inset">
            <img
                v-if="product.image && !imageFailed"
                :src="'nui://' + useShopStore().inventoryImagePath + product.image"
                :alt="product.name"
                class="size-24 object-contain transition-transform duration-200 group-hover:scale-105"
                @error="imageFailed = true"
            />
            <Package v-else class="size-10 text-text-faint" />

            <span class="absolute left-2 top-2 rounded-md border border-border bg-bg-muted px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider text-text-muted">
                {{ product.category }}
            </span>
        </div>

        <div class="flex flex-1 flex-col gap-3 p-3">
            <div class="min-w-0">
                <h3 class="truncate text-sm font-semibold text-text-primary">{{ product.name }}</h3>
                <p class="mt-1 flex items-center gap-1.5 text-xs" :class="stockClass">
                    <span class="size-1.5 rounded-full bg-current" />
                    {{ outOfStock ? t("shop.item.out_of_stock") : t("shop.item.in_stock", stock) }}
                </p>
            </div>

            <div class="mt-auto flex items-center justify-between gap-2">
                <p class="text-base font-semibold tabular-nums text-text-primary">
                    {{ formatMoney(product.price) }}
                </p>
                <Button v-if="inCart" size="sm" variant="danger" @click="emit('remove', product)">
                    <Trash2 class="size-3.5" />
                    {{ t("shop.item.remove") }}
                </Button>
                <Button v-else size="sm" :disabled="outOfStock" @click="emit('add', product)">
                    <Plus class="size-3.5" />
                    {{ t("shop.item.add") }}
                </Button>
            </div>
        </div>
    </article>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { Package, Plus, Trash2 } from "@lucide/vue";
import { Button } from "@vezironi/veyra-ui";
import { useShopStore } from "@/stores";
import type { Product } from "@/stores";
import { formatMoney } from "@/utils/format";
import { t } from "@/utils/locale";

const props = defineProps<{
    product: Product;
    stock: number;
    inCart: boolean;
}>();

const emit = defineEmits<{
    add: [product: Product];
    remove: [product: Product];
}>();

const imageFailed = ref(false);

const outOfStock = computed(() => props.stock < 1);

const stockClass = computed(() => {
    if (outOfStock.value) return "text-danger";
    if (props.stock <= 5) return "text-warning";
    return "text-text-faint";
});

watch(() => props.product.image, () => {
    imageFailed.value = false;
});
</script>
