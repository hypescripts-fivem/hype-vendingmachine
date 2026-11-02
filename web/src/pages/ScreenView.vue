<template>
    <!-- The model's screen crops the bottom of the texture, the padding keeps the buttons in view -->
    <main class="flex h-screen w-screen flex-col overflow-hidden bg-bg-base pb-[20px]">
        <template v-if="page === 'products'">
            <header class="px-6 pb-4 pt-6 leading-tight">
                <h1 class="text-3xl font-semibold text-text-primary">{{ shop.name }}</h1>
                <p class="text-xl text-text-muted">Pick a product and add it to the cart</p>
            </header>

            <section class="min-h-0 flex-1 overflow-y-auto px-6 pb-6">
                <EmptyState
                    v-if="!shop.products.length"
                    title="No products"
                    description="This machine has nothing for sale yet."
                    :icon="PackageSearch"
                    class="h-full"
                />

                <div v-else class="grid grid-cols-2 gap-4">
                    <ScreenItem
                        v-for="product in shop.products"
                        :key="product.id"
                        :product="product"
                        :quantity="shop.inCart(product.id)"
                        :stock="shop.remainingStock(product)"
                    />
                </div>
            </section>

            <ScreenBar @cart="page = 'cart'" @quick="paying = true" />
        </template>

        <ScreenCart v-else @back="page = 'products'" @confirm="paying = true" />

        <!-- The menu's payment dialog, scaled up to the screen's text size -->
        <CheckoutModal v-if="paying" class="[zoom:1.75]" @close="paying = false" />
    </main>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import { PackageSearch } from "@lucide/vue";
import { EmptyState } from "@vezironi/veyra-ui";
import CheckoutModal from "@/components/shop/CheckoutModal.vue";
import ScreenBar from "@/components/screen/ScreenBar.vue";
import ScreenCart from "@/components/screen/ScreenCart.vue";
import ScreenItem from "@/components/screen/ScreenItem.vue";
import { useShopStore } from "@/stores";

const shop = useShopStore();

const page = ref<"products" | "cart">("products");
const paying = ref(false);

// An empty cart has nothing to show, e.g. after a checkout or the last item was removed
watch(() => shop.cart.length, (length) => {
    if (!length) page.value = "products";
});
</script>
