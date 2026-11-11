<template>
    <main class="flex h-180 w-7xl flex-col overflow-hidden rounded-[1rem] border border-border bg-bg-base">
        <ShopNavbar />

        <div class="flex min-h-0 flex-1">
            <section class="w-3/4 overflow-y-auto p-4">
                <EmptyState
                    v-if="!shop.filteredProducts.length"
                    :title="t('shop.empty.title')"
                    :description="t('shop.empty.description')"
                    :icon="PackageSearch"
                    class="h-full"
                />

                <div v-else class="grid grid-cols-4 gap-3">
                    <ShopItem
                        v-for="product in shop.filteredProducts"
                        :key="product.id"
                        :product="product"
                        :stock="shop.remainingStock(product)"
                        :in-cart="shop.inCart(product.id) > 0"
                        @add="shop.addToCart(product, 1)"
                        @remove="shop.removeFromCart(product.id)"
                    />
                </div>
            </section>

            <section class="w-1/4 border-l border-border bg-bg-surface">
                <ShopCart />
            </section>
        </div>
    </main>
</template>

<script setup lang="ts">
import { PackageSearch } from "@lucide/vue";
import { EmptyState } from "@vezironi/veyra-ui";
import ShopNavbar from "@/components/shop/ShopNavbar.vue";
import ShopCart from "@/components/shop/ShopCart.vue";
import ShopItem from "@/components/shop/ShopItem.vue";
import { useShopStore } from "@/stores";
import { t } from "@/utils/locale";

const shop = useShopStore();
</script>
