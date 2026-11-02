<template>
    <footer class="flex items-center gap-3 border-t border-border bg-bg-surface px-6 py-5">
        <div class="min-w-0 flex-1 leading-tight">
            <p class="text-xl text-text-muted">{{ shop.cartCount }} {{ shop.cartCount === 1 ? "item" : "items" }}</p>
            <p class="text-3xl font-semibold tabular-nums text-text-primary">{{ formatMoney(shop.cartTotal) }}</p>
        </div>
        <Button variant="secondary" size="lg" class="text-xl" :disabled="!shop.cart.length" @click="emit('cart')">
            <ShoppingCart class="size-5" />
            Cart
            <Badge variant="muted" class="text-base">{{ shop.cartCount }}</Badge>
        </Button>
        <Button size="lg" class="text-xl" :disabled="!shop.cart.length || shop.checkingOut" @click="emit('quick')">
            <Zap class="size-5" />
            Quick order
        </Button>
    </footer>
</template>

<script setup lang="ts">
import { ShoppingCart, Zap } from "@lucide/vue";
import { Badge, Button } from "@vezironi/veyra-ui";
import { useShopStore } from "@/stores";
import { formatMoney } from "@/utils/format";

const emit = defineEmits<{
    cart: [];
    quick: [];
}>();

const shop = useShopStore();
</script>
