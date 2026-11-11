<template>
    <Modal :title="t('shop.checkout.title')" :icon="CreditCard" width="26rem" @close="emit('close')">
        <div class="flex flex-col gap-4 px-5 py-4 text-sm">
            <div class="flex items-end justify-between">
                <span class="text-xs uppercase tracking-wider text-text-faint">{{ t("common.total") }}</span>
                <span class="text-2xl font-semibold tabular-nums text-text-primary">
                    {{ formatMoney(shop.cartTotal) }}
                </span>
            </div>

            <div class="flex flex-col gap-2" role="radiogroup" :aria-label="t('shop.checkout.payment_method')">
                <button
                    v-for="method in methods"
                    :key="method.value"
                    type="button"
                    role="radio"
                    :aria-checked="selected === method.value"
                    :disabled="!!unavailable(method.value)"
                    :class="[
                        'flex items-center gap-3 rounded-lg border p-3 text-left transition-colors disabled:cursor-not-allowed disabled:opacity-50',
                        selected === method.value ? 'border-text-faint bg-bg-muted' : 'border-border hover:bg-bg-muted/30',
                    ]"
                    @click="selected = method.value"
                >
                    <component :is="method.icon" class="size-4 shrink-0 text-text-muted" />
                    <span class="min-w-0 flex-1 leading-tight">
                        <span class="block font-medium text-text-primary">{{ t(method.label) }}</span>
                        <span class="block text-xs" :class="unavailable(method.value) ? 'text-danger' : 'text-text-faint'">
                            {{ unavailable(method.value) ?? t("shop.checkout.available") }}
                        </span>
                    </span>
                    <span class="tabular-nums text-text-muted">{{ formatMoney(shop.wallet[method.value]) }}</span>
                </button>
            </div>

            <p v-if="error" class="flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                {{ error }}
            </p>
        </div>

        <template #footer>
            <Button variant="outline" size="sm" @click="emit('close')">{{ t("common.cancel") }}</Button>
            <Button size="sm" :disabled="!selected || shop.checkingOut" @click="pay">
                {{ shop.checkingOut ? t("shop.checkout.processing") : t("shop.checkout.pay", formatMoney(shop.cartTotal)) }}
            </Button>
        </template>
    </Modal>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { Banknote, CircleAlert, CreditCard, Landmark } from "@lucide/vue";
import { Button, Modal } from "@vezironi/veyra-ui";
import { useShopStore, type PaymentMethod } from "@/stores";
import { formatMoney } from "@/utils/format";
import { t } from "@/utils/locale";

const emit = defineEmits<{ close: [] }>();

const shop = useShopStore();

const methods = [
    { value: "cash" as const, label: "shop.checkout.cash", icon: Banknote },
    { value: "bank" as const, label: "shop.checkout.bank", icon: Landmark },
];

// Why a method can't be picked; only for the UI, the server checks both again
function unavailable(method: PaymentMethod): string | undefined {
    if (!shop.payments[method]) return t("shop.checkout.not_accepted");
    if (shop.wallet[method] < shop.cartTotal) return t("shop.checkout.not_enough_money");
    return undefined;
};

const selected = ref<PaymentMethod | undefined>(methods.find((method) => !unavailable(method.value))?.value);
const error = ref<string>();

async function pay() {
    if (!selected.value) return;

    error.value = undefined;
    const response = await shop.checkout(selected.value);
    if (!response) return;

    if (response.success) {
        emit("close");
    } else {
        error.value = response.error;
    }
};
</script>
