<template>
    <Modal title="Buy machine" :icon="Store" width="28rem" @close="app.close()">
        <div class="flex flex-col gap-4 px-5 py-4 text-sm">
            <div class="leading-tight">
                <p class="text-base font-semibold text-text-primary">{{ machine.name }}</p>
                <p class="mt-1 flex items-center gap-1.5 text-xs text-text-faint">
                    <MapPin class="size-3.5" />
                    {{ machine.area || "Unknown area" }}
                </p>
            </div>

            <dl class="grid grid-cols-2 gap-3">
                <div class="rounded-lg border border-border bg-bg-inset px-3 py-2">
                    <dt class="text-xs text-text-faint">Type</dt>
                    <dd class="mt-0.5 font-medium text-text-primary">{{ machine.model }}</dd>
                </div>
                <div class="rounded-lg border border-border bg-bg-inset px-3 py-2">
                    <dt class="text-xs text-text-faint">Capacity</dt>
                    <dd class="mt-0.5 font-medium text-text-primary">{{ machine.capacity }} per product</dd>
                </div>
            </dl>

            <div v-if="machine.products.length" class="flex flex-col gap-2">
                <p class="text-xs text-text-faint">
                    Sells {{ machine.products.length }} product{{ machine.products.length === 1 ? "" : "s" }}
                </p>
                <div class="flex flex-wrap gap-1.5">
                    <ProductThumb v-for="product in machine.products" :key="product.id" :product="product" :title="product.name" />
                </div>
            </div>

            <div class="flex items-end justify-between border-t border-border pt-4">
                <div>
                    <p class="text-xs text-text-faint">Price</p>
                    <p class="text-2xl font-semibold tabular-nums text-text-primary">
                        {{ formatMoney(machine.price) }}
                    </p>
                </div>
                <div class="text-right text-xs" :class="affordable ? 'text-text-muted' : 'text-danger'">
                    <p>{{ machine.account === "cash" ? "Cash" : "Bank" }} balance</p>
                    <p class="tabular-nums">{{ formatMoney(machine.balance) }}</p>
                </div>
            </div>

            <p v-if="error" class="flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                {{ error }}
            </p>
        </div>

        <template #footer>
            <Button variant="outline" size="sm" @click="app.close()">Cancel</Button>
            <Button size="sm" :disabled="!affordable || purchase.buying" @click="buy">
                <ShoppingCart class="size-3.5" />
                {{ purchase.buying ? "Buying..." : "Buy machine" }}
            </Button>
        </template>
    </Modal>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CircleAlert, MapPin, ShoppingCart, Store } from "@lucide/vue";
import { Button, Modal } from "@vezironi/veyra-ui";
import ProductThumb from "@/components/ProductThumb.vue";
import { useAppStore } from "@/stores/app";
import { usePurchaseStore } from "@/stores/purchase";
import { formatMoney } from "@/utils/format";

const app = useAppStore();
const purchase = usePurchaseStore();

const machine = computed(() => purchase.machine);

// Only for the button; the server checks the money again
const affordable = computed(() => machine.value.balance >= machine.value.price);

const error = ref<string>();

async function buy() {
    error.value = affordable.value ? undefined : "You don't have enough money.";
    if (error.value) return;

    const response = await purchase.buy();
    if (!response) return;

    if (response.success) {
        app.close();
    } else {
        error.value = response.error;
    }
};
</script>
