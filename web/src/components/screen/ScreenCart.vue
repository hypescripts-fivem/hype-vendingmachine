<template>
    <section class="flex min-h-0 flex-1 flex-col">
        <header class="flex items-center justify-between px-6 pb-4 pt-6">
            <div class="leading-tight">
                <h2 class="text-3xl font-semibold text-text-primary">Cart</h2>
                <p class="text-xl text-text-muted">{{ shop.cart.length }} products · {{ shop.cartCount }} items</p>
            </div>
            <Button variant="secondary" size="lg" class="text-xl" @click="shop.clearCart">Clear</Button>
        </header>

        <ul class="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto px-6">
            <li
                v-for="item in shop.cart"
                :key="item.product.id"
                class="flex items-center gap-4 rounded-xl border border-border bg-bg-surface p-3"
            >
                <div class="flex size-16 shrink-0 items-center justify-center rounded-lg border border-border bg-bg-inset">
                    <img
                        v-if="item.product.image && !failedImages.has(item.product.id)"
                        :src="'nui://' + shop.inventoryImagePath + item.product.image"
                        :alt="item.product.name"
                        class="size-12 object-contain"
                        @error="failedImages.add(item.product.id)"
                    />
                    <Package v-else class="size-6 text-text-faint" />
                </div>
                <div class="min-w-0 flex-1 leading-tight">
                    <p class="truncate text-xl font-medium text-text-primary">{{ item.product.name }}</p>
                    <p class="text-lg tabular-nums text-text-muted">{{ formatMoney(item.product.price) }} each</p>
                </div>
                <QuantityStepper :quantity="item.quantity" :max="item.product.stock" @update="shop.setQuantity(item.product.id, $event)" />
                <p class="w-24 text-right text-xl font-semibold tabular-nums text-text-primary">
                    {{ formatMoney(item.product.price * item.quantity) }}
                </p>
                <button
                    type="button"
                    aria-label="Remove from cart"
                    class="flex size-12 items-center justify-center rounded-lg border border-danger/40 bg-danger/15 text-danger transition-colors hover:bg-danger/25"
                    @click="shop.removeFromCart(item.product.id)"
                >
                    <Trash2 class="size-5" />
                </button>
            </li>
        </ul>

        <footer class="flex flex-col gap-4 border-t border-border bg-bg-surface px-6 py-5">
            <div class="flex items-center justify-between">
                <span class="text-xl uppercase tracking-wider text-text-muted">Total</span>
                <span class="text-3xl font-semibold tabular-nums text-text-primary">{{ formatMoney(shop.cartTotal) }}</span>
            </div>
            <div class="flex gap-3">
                <Button variant="secondary" size="lg" class="flex-1 text-xl" @click="emit('back')">
                    <ArrowLeft class="size-5" />
                    Back
                </Button>
                <Button size="lg" class="flex-1 text-xl" :disabled="!shop.cart.length || shop.checkingOut" @click="emit('confirm')">
                    Confirm cart
                </Button>
            </div>
        </footer>
    </section>
</template>

<script setup lang="ts">
import { reactive } from "vue";
import { ArrowLeft, Package, Trash2 } from "@lucide/vue";
import { Button } from "@vezironi/veyra-ui";
import { useShopStore } from "@/stores";
import { formatMoney } from "@/utils/format";
import QuantityStepper from "./QuantityStepper.vue";

const emit = defineEmits<{
    back: [];
    confirm: [];
}>();

const shop = useShopStore();

const failedImages = reactive(new Set<string>());
</script>
