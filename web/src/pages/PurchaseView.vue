<template>
    <Modal :title="t('purchase.title')" :icon="Store" width="28rem" @close="app.close()">
        <div class="flex flex-col gap-4 px-5 py-4 text-sm">
            <div class="leading-tight">
                <p class="text-base font-semibold text-text-primary">{{ machine.name }}</p>
                <p class="mt-1 flex items-center gap-1.5 text-xs text-text-faint">
                    <MapPin class="size-3.5" />
                    {{ machine.area || t("purchase.unknown_area") }}
                </p>
            </div>

            <dl class="grid grid-cols-2 gap-3">
                <div class="rounded-lg border border-border bg-bg-inset px-3 py-2">
                    <dt class="text-xs text-text-faint">{{ t("purchase.type") }}</dt>
                    <dd class="mt-0.5 font-medium text-text-primary">{{ machine.model }}</dd>
                </div>
                <div class="rounded-lg border border-border bg-bg-inset px-3 py-2">
                    <dt class="text-xs text-text-faint">{{ t("purchase.capacity") }}</dt>
                    <dd class="mt-0.5 font-medium text-text-primary">{{ t("purchase.capacity_value", machine.capacity) }}</dd>
                </div>
            </dl>

            <div v-if="machine.products.length" class="flex flex-col gap-2">
                <p class="text-xs text-text-faint">
                    {{ machine.products.length === 1 ? t("purchase.sells_one", machine.products.length) : t("purchase.sells_other", machine.products.length) }}
                </p>
                <div class="flex flex-wrap gap-1.5">
                    <ProductThumb v-for="product in machine.products" :key="product.id" :product="product" :title="product.name" />
                </div>
            </div>

            <div class="flex items-end justify-between border-t border-border pt-4">
                <div>
                    <p class="text-xs text-text-faint">{{ t("purchase.price") }}</p>
                    <p class="text-2xl font-semibold tabular-nums text-text-primary">
                        {{ formatMoney(machine.price) }}
                    </p>
                </div>
                <div class="text-right text-xs" :class="affordable ? 'text-text-muted' : 'text-danger'">
                    <p>{{ machine.account === "cash" ? t("purchase.cash_balance") : t("purchase.bank_balance") }}</p>
                    <p class="tabular-nums">{{ formatMoney(machine.balance) }}</p>
                </div>
            </div>

            <p v-if="error" class="flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                {{ error }}
            </p>
        </div>

        <template #footer>
            <Button variant="outline" size="sm" @click="app.close()">{{ t("common.cancel") }}</Button>
            <Button size="sm" :disabled="!affordable || purchase.buying" @click="buy">
                <ShoppingCart class="size-3.5" />
                {{ purchase.buying ? t("purchase.buying") : t("purchase.buy") }}
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
import { t } from "@/utils/locale";

const app = useAppStore();
const purchase = usePurchaseStore();

const machine = computed(() => purchase.machine);

// Only for the button; the server checks the money again
const affordable = computed(() => machine.value.balance >= machine.value.price);

const error = ref<string>();

async function buy() {
    error.value = affordable.value ? undefined : t("purchase.not_enough_money");
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
