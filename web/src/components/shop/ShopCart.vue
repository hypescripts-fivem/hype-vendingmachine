<template>
    <aside class="flex h-full flex-col">
        <div class="flex items-center justify-between px-4 py-3">
            <div class="flex items-center gap-2">
                <ShoppingCart class="size-4 text-text-muted" />
                <h2 class="text-sm font-semibold text-text-primary">Cart</h2>
                <Badge variant="muted">{{ shop.cartCount }}</Badge>
            </div>
            <button
                v-if="shop.cart.length"
                type="button"
                class="text-xs text-text-faint transition-colors hover:text-text-primary"
                @click="shop.clearCart"
            >
                Clear
            </button>
        </div>

        <Separator />

        <div class="min-h-0 flex-1 overflow-y-auto p-3">
            <EmptyState
                v-if="!shop.cart.length"
                title="Your cart is empty"
                description="Add products to see them here."
                :icon="ShoppingCart"
                class="h-full bg-transparent border-none"
            />

            <ul v-else class="flex flex-col gap-2">
                <li
                    v-for="item in shop.cart"
                    :key="item.product.id"
                    class="rounded-lg border border-border bg-bg-surface p-3"
                >
                    <div class="flex items-start gap-2.5">
                        <div class="flex size-10 shrink-0 items-center justify-center rounded-md border border-border bg-bg-inset">
                            <img
                                v-if="item.product.image && !failedImages.has(item.product.id)"
                                :src="item.product.image"
                                :alt="item.product.name"
                                class="size-8 object-contain"
                                @error="failedImages.add(item.product.id)"
                            />
                            <Package v-else class="size-4 text-text-faint" />
                        </div>
                        <div class="min-w-0 flex-1">
                            <p class="truncate text-sm font-medium text-text-primary">{{ item.product.name }}</p>
                            <p class="text-xs tabular-nums text-text-faint">{{ formatMoney(item.product.price) }} each</p>
                        </div>
                        <button
                            type="button"
                            aria-label="Remove item"
                            class="text-text-faint transition-colors hover:text-danger"
                            @click="shop.removeFromCart(item.product.id)"
                        >
                            <Trash2 class="size-3.5" />
                        </button>
                    </div>

                    <div class="mt-2 flex items-center justify-between">
                        <div class="flex h-7 items-stretch overflow-hidden rounded-md border border-border">
                            <button
                                type="button"
                                aria-label="Decrease quantity"
                                class="flex w-7 items-center justify-center text-text-muted transition-colors hover:bg-bg-muted-hover hover:text-text-primary"
                                @click="shop.setQuantity(item.product.id, item.quantity - 1)"
                            >
                                <Minus class="size-3" />
                            </button>
                            <output class="flex min-w-7 items-center justify-center border-x border-border bg-bg-inset text-xs font-semibold tabular-nums text-text-primary">
                                {{ item.quantity }}
                            </output>
                            <button
                                type="button"
                                aria-label="Increase quantity"
                                :disabled="item.quantity >= item.product.stock"
                                class="flex w-7 items-center justify-center text-text-muted transition-colors hover:bg-bg-muted-hover hover:text-text-primary disabled:pointer-events-none disabled:opacity-40"
                                @click="shop.setQuantity(item.product.id, item.quantity + 1)"
                            >
                                <Plus class="size-3" />
                            </button>
                        </div>
                        <p class="text-sm font-semibold tabular-nums text-text-primary">
                            {{ formatMoney(item.product.price * item.quantity) }}
                        </p>
                    </div>
                </li>
            </ul>
        </div>

        <Separator />

        <div class="flex flex-col gap-3 p-4">
            <div class="flex items-center justify-between">
                <span class="text-xs uppercase tracking-wider text-text-faint">Total</span>
                <span class="text-lg font-semibold tabular-nums text-text-primary">
                    {{ formatMoney(shop.cartTotal) }}
                </span>
            </div>
            <Button class="w-full" :disabled="!shop.cart.length || shop.checkingOut" @click="paying = true">
                Checkout
            </Button>
        </div>

        <CheckoutModal v-if="paying" @close="paying = false" />
    </aside>
</template>

<script setup lang="ts">
import { reactive, ref } from "vue";
import { Minus, Package, Plus, ShoppingCart, Trash2 } from "@lucide/vue";
import { Badge, Button, EmptyState, Separator } from "@vezironi/veyra-ui";
import { useShopStore } from "@/stores";
import CheckoutModal from "./CheckoutModal.vue";
import { formatMoney } from "@/utils/format";

const shop = useShopStore();

const paying = ref(false);

const failedImages = reactive(new Set<string>());
</script>
