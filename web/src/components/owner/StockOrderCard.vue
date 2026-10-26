<template>
    <li class="flex flex-col gap-3 px-4 py-3">
        <div class="flex items-start gap-3">
            <div class="min-w-0 flex-1 leading-tight">
                <p class="truncate text-sm text-text-primary">
                    {{ order.items.map((item) => `${owner.productName(item.productId)} ×${item.quantity}`).join(", ") }}
                </p>
                <p class="text-xs tabular-nums text-text-faint">{{ formatDateTime(order.time) }} · −{{ formatMoney(order.total) }}</p>
            </div>
            <span
                class="inline-flex shrink-0 items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium"
                :class="statusMeta[order.status].class"
            >
                <component :is="statusMeta[order.status].icon" class="size-3" />
                {{ statusMeta[order.status].label }}
            </span>
        </div>

        <ol v-if="currentIndex !== -1 && order.status !== 'completed'" class="flex items-start" :aria-label="`Order status: ${statusMeta[order.status].label}`">
            <template v-for="(status, index) in orderStatuses" :key="status">
                <li
                    v-if="index > 0"
                    aria-hidden="true"
                    class="mt-3 h-px flex-1"
                    :class="index <= currentIndex ? 'bg-inverse' : 'bg-border'"
                />
                <li class="flex w-16 flex-col items-center gap-1">
                    <span
                        class="flex size-6 items-center justify-center rounded-full"
                        :class="index <= currentIndex ? 'bg-inverse text-text-inverse' : 'border border-border bg-bg-muted text-text-faint'"
                    >
                        <component :is="statusMeta[status].icon" class="size-3" />
                    </span>
                    <span class="text-center text-[10px] leading-tight" :class="index <= currentIndex ? 'text-text-primary' : 'text-text-faint'">
                        {{ statusMeta[status].label }}
                    </span>
                </li>
            </template>
        </ol>

        <div v-if="order.status === 'prepared'" class="flex flex-col gap-2">
            <p v-if="error" class="flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                {{ error }}
            </p>
            <Button size="sm" class="w-full" :disabled="picking" @click="pickup">
                <Truck class="size-4" />
                Pick up
            </Button>
        </div>
    </li>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CircleAlert, CircleCheck, CircleX, Clock, PackageCheck, Truck } from "@lucide/vue";
import { Button } from "@vezironi/veyra-ui";
import { orderStatuses, useOwnerStore, type StockOrder } from "@/stores/owner";
import { formatDateTime, formatMoney } from "@/utils/format";

const props = defineProps<{ order: StockOrder }>();

const owner = useOwnerStore();

const statusMeta = {
    preparing: { label: "Preparing", icon: Clock, class: "bg-warning/10 text-warning" },
    prepared: { label: "Prepared", icon: PackageCheck, class: "bg-info/10 text-info" },
    shipping: { label: "On the way", icon: Truck, class: "bg-info/10 text-info" },
    completed: { label: "Completed", icon: CircleCheck, class: "bg-success/10 text-success" },
    cancelled: { label: "Cancelled", icon: CircleX, class: "bg-danger/10 text-danger" },
};

const currentIndex = computed(() => orderStatuses.indexOf(props.order.status));

const picking = ref(false);
const error = ref<string>();

// On success the client closes the panel, so only a failure is shown here
async function pickup() {
    picking.value = true;
    error.value = undefined;

    const response = await owner.pickupOrder(props.order.id);
    if (!response.success) error.value = response.error;

    picking.value = false;
}
</script>
