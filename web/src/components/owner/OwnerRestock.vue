<template>
    <NoProducts v-if="!shop.products.length" />

    <div v-else class="grid grid-cols-5 items-start gap-3">
        <section class="col-span-3 rounded-2xl border border-border bg-bg-surface">
            <header class="flex items-center justify-between px-4 py-3">
                <h3 class="text-sm font-semibold text-text-primary">Supplier catalog</h3>
                <Switch v-model="lowStockOnly" label="Low stock only" />
            </header>

            <EmptyState
                v-if="!catalog.length"
                title="Everything is stocked"
                description="No products are running low right now."
                :icon="PackageCheck"
                class="border-none bg-transparent"
            />

            <ul v-else class="divide-y divide-border border-t border-border">
                <li v-for="product in catalog" :key="product.id" class="flex items-center gap-3 px-4 py-2.5">
                    <ProductThumb :product="product" />

                    <div class="min-w-0 flex-1 leading-tight">
                        <p class="truncate text-sm font-medium text-text-primary">{{ product.name }}</p>
                        <p class="text-xs text-text-faint">
                            <span class="tabular-nums" :class="stockClass(product.stock)">{{ product.stock }} / {{ owner.capacity }}</span>
                            <span v-if="owner.incoming[product.id]" class="tabular-nums text-info"> +{{ owner.incoming[product.id] }} incoming</span>
                            · {{ formatMoney(unitCost(product.id)) }} per unit
                        </p>
                    </div>

                    <div class="flex h-8 items-stretch overflow-hidden rounded-lg border border-border">
                        <button
                            type="button"
                            aria-label="Decrease quantity"
                            :disabled="quantity(product.id) < 1"
                            class="flex w-8 items-center justify-center text-text-muted transition-colors hover:bg-bg-muted-hover hover:text-text-primary disabled:pointer-events-none disabled:opacity-40"
                            @click="setQuantity(product, quantity(product.id) - 1)"
                        >
                            <Minus class="size-3.5" />
                        </button>
                        <output class="flex min-w-10 items-center justify-center border-x border-border bg-bg-inset px-1 text-sm font-semibold tabular-nums text-text-primary">
                            {{ quantity(product.id) }}
                        </output>
                        <button
                            type="button"
                            aria-label="Increase quantity"
                            :disabled="quantity(product.id) >= space(product)"
                            class="flex w-8 items-center justify-center text-text-muted transition-colors hover:bg-bg-muted-hover hover:text-text-primary disabled:pointer-events-none disabled:opacity-40"
                            @click="setQuantity(product, quantity(product.id) + 1)"
                        >
                            <Plus class="size-3.5" />
                        </button>
                    </div>

                    <Button variant="outline" size="sm" :disabled="quantity(product.id) >= space(product)" @click="setQuantity(product, space(product))">
                        Fill
                    </Button>

                    <span class="w-14 text-right text-sm font-semibold tabular-nums text-text-primary">
                        {{ formatMoney(unitCost(product.id) * quantity(product.id)) }}
                    </span>
                </li>
            </ul>
        </section>

        <div class="col-span-2 flex flex-col gap-3">
            <section class="rounded-2xl border border-border bg-bg-surface">
                <header class="flex items-center justify-between px-4 py-3">
                    <h3 class="text-sm font-semibold text-text-primary">Order summary</h3>
                    <button
                        v-if="orderItems.length"
                        type="button"
                        class="text-xs text-text-faint transition-colors hover:text-text-primary"
                        @click="clear"
                    >
                        Clear
                    </button>
                </header>

                <div class="border-t border-border px-4 py-3">
                    <p v-if="!orderItems.length" class="py-4 text-center text-xs text-text-faint">
                        Pick quantities from the catalog to build an order.
                    </p>
                    <ul v-else class="flex flex-col gap-1.5">
                        <li v-for="item in orderItems" :key="item.productId" class="flex justify-between text-sm">
                            <span class="text-text-muted">
                                {{ owner.productName(item.productId) }} <span class="text-text-faint">× {{ item.quantity }}</span>
                            </span>
                            <span class="tabular-nums text-text-primary">{{ formatMoney(unitCost(item.productId) * item.quantity) }}</span>
                        </li>
                    </ul>
                </div>

                <!-- Staff without cash.history only see the total; the error below still says when the balance is short -->
                <dl v-if="owner.can('cash.history')" class="flex flex-col gap-1.5 border-t border-border px-4 py-3 text-sm">
                    <div class="flex justify-between">
                        <dt class="text-text-muted">Machine balance</dt>
                        <dd class="tabular-nums text-text-primary">{{ formatMoney(owner.balance) }}</dd>
                    </div>
                    <div class="flex justify-between">
                        <dt class="text-text-muted">Order total</dt>
                        <dd class="tabular-nums text-text-primary">−{{ formatMoney(total) }}</dd>
                    </div>
                    <div class="flex justify-between font-semibold">
                        <dt class="text-text-primary">Balance after</dt>
                        <dd class="tabular-nums" :class="insufficient ? 'text-danger' : 'text-text-primary'">
                            {{ formatMoney(owner.balance - total) }}
                        </dd>
                    </div>
                </dl>
                <dl v-else class="flex justify-between border-t border-border px-4 py-3 text-sm font-semibold">
                    <dt class="text-text-primary">Order total</dt>
                    <dd class="tabular-nums text-text-primary">{{ formatMoney(total) }}</dd>
                </dl>

                <div class="flex flex-col gap-2 border-t border-border p-4">
                    <p v-if="error" class="flex items-center gap-1.5 text-xs text-danger">
                        <CircleAlert class="size-3.5 shrink-0" />
                        {{ error }}
                    </p>
                    <Button class="w-full" :disabled="!orderItems.length || insufficient || owner.ordering" @click="placeOrder">
                        <Truck class="size-4" />
                        {{ owner.ordering ? "Ordering..." : "Place order" }}
                    </Button>
                </div>
            </section>

            <section class="rounded-2xl border border-border bg-bg-surface">
                <header class="flex items-baseline justify-between px-4 py-3">
                    <h3 class="text-sm font-semibold text-text-primary">Orders</h3>
                    <span class="text-xs text-text-faint">{{ owner.activeOrders.length }} in progress</span>
                </header>
                <ul class="max-h-96 divide-y divide-border overflow-y-auto border-t border-border">
                    <StockOrderCard v-for="order in sortedOrders" :key="order.id" :order="order" />
                </ul>
            </section>
        </div>
    </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from "vue";
import { CircleAlert, Minus, PackageCheck, Plus, Truck } from "@lucide/vue";
import { Button, EmptyState, Switch } from "@vezironi/veyra-ui";
import ProductThumb from "@/components/ProductThumb.vue";
import NoProducts from "./NoProducts.vue";
import StockOrderCard from "./StockOrderCard.vue";
import { useShopStore, type Product } from "@/stores";
import { useOwnerStore } from "@/stores/owner";
import { formatMoney } from "@/utils/format";

const shop = useShopStore();
const owner = useOwnerStore();

const quantities = reactive<Record<string, number>>({});
const lowStockOnly = ref(false);
const error = ref<string>();

const catalog = computed(() => lowStockOnly.value ? owner.lowStock : shop.products);

const orderItems = computed(() => Object.entries(quantities)
    .filter(([, quantity]) => quantity > 0)
    .map(([productId, quantity]) => ({ productId, quantity })));

const total = computed(() => owner.orderTotal(orderItems.value));

// In-progress orders first, each group keeps newest-first order
const sortedOrders = computed(() => [
    ...owner.activeOrders,
    ...owner.orders.filter((order) => order.status === "completed"),
]);
const insufficient = computed(() => total.value > owner.balance);

watch(insufficient, (value) => {
    error.value = value ? "Not enough money in the machine for this order." : undefined;
});

function unitCost(productId: string): number {
    return owner.wholesale[productId] ?? 0;
};

function quantity(productId: string): number {
    return quantities[productId] ?? 0;
};

// Undelivered orders already reserve capacity
function space(product: Product): number {
    return Math.max(0, owner.capacity - product.stock - (owner.incoming[product.id] ?? 0));
};

function setQuantity(product: Product, value: number) {
    quantities[product.id] = Math.min(space(product), Math.max(0, value));
};

function stockClass(stock: number): string {
    if (stock < 1) return "text-danger";
    if (owner.isLowStock(stock)) return "text-warning";
    return "text-text-muted";
};

function clear() {
    for (const productId of Object.keys(quantities)) delete quantities[productId];
};

async function placeOrder() {
    const response = await owner.orderStock(orderItems.value);

    if (response?.success) {
        clear();
    } else if (response) {
        error.value = response.error ?? "Order failed.";
    }
};
</script>
