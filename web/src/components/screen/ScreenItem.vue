<template>
    <article
        :class="[
            'flex flex-col overflow-hidden rounded-2xl border bg-bg-surface',
            quantity ? 'border-text-faint' : 'border-border',
            outOfStock ? 'opacity-60' : '',
        ]"
    >
        <div class="relative flex h-56 items-center justify-center border-b border-border bg-bg-inset">
            <img
                v-if="product.image && !imageFailed"
                :src="'nui://' + shop.inventoryImagePath + product.image"
                :alt="product.name"
                class="size-36 object-contain"
                @error="imageFailed = true"
            />
            <Package v-else class="size-16 text-text-faint" />

            <span class="absolute left-3 top-3 rounded-md border border-border bg-bg-muted px-2.5 py-1 text-lg font-medium uppercase tracking-wider text-text-muted">
                {{ product.category }}
            </span>

            <div class="absolute right-3 top-3 flex items-center gap-2">
                <template v-if="quantity">
                    <QuantityStepper :quantity="quantity" :max="product.stock" @update="shop.setQuantity(product.id, $event)" />
                    <button
                        type="button"
                        :aria-label="t('screen.remove_from_cart')"
                        class="flex size-12 items-center justify-center rounded-lg border border-danger/40 bg-danger/15 text-danger transition-colors hover:bg-danger/25"
                        @click="shop.removeFromCart(product.id)"
                    >
                        <Trash2 class="size-5" />
                    </button>
                </template>
                <button
                    v-else-if="!outOfStock"
                    type="button"
                    :aria-label="t('screen.item.add_to_cart')"
                    class="flex size-12 items-center justify-center rounded-lg bg-inverse text-text-inverse transition-opacity hover:opacity-90"
                    @click="shop.addToCart(product, 1)"
                >
                    <Plus class="size-6" />
                </button>
            </div>

            <span v-if="outOfStock" class="absolute bottom-3 text-xl font-medium text-danger">{{ t("screen.item.out_of_stock") }}</span>
        </div>

        <div class="flex items-baseline justify-between gap-3 px-4 py-3">
            <h3 class="truncate text-2xl font-semibold text-text-primary">{{ product.name }}</h3>
            <p class="text-2xl font-semibold tabular-nums text-text-primary">{{ formatMoney(product.price) }}</p>
        </div>
    </article>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { Package, Plus, Trash2 } from "@lucide/vue";
import { useShopStore } from "@/stores";
import type { Product } from "@/stores";
import { formatMoney } from "@/utils/format";
import { t } from "@/utils/locale";
import QuantityStepper from "./QuantityStepper.vue";

const props = defineProps<{
    product: Product;
    // Units of this product in the cart
    quantity: number;
    // Stock left after the cart
    stock: number;
}>();

const shop = useShopStore();

const imageFailed = ref(false);

const outOfStock = computed(() => props.stock < 1 && props.quantity === 0);

watch(() => props.product.image, () => {
    imageFailed.value = false;
});
</script>
