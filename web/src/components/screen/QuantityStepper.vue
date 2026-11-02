<template>
    <div class="flex h-12 items-stretch overflow-hidden rounded-lg border border-border bg-bg-muted">
        <button
            type="button"
            aria-label="Decrease quantity"
            class="flex w-12 items-center justify-center text-text-muted transition-colors hover:bg-bg-muted-hover hover:text-text-primary"
            @click="emit('update', quantity - 1)"
        >
            <Minus class="size-5" />
        </button>
        <output class="flex min-w-12 items-center justify-center border-x border-border bg-bg-inset text-xl font-semibold tabular-nums text-text-primary">
            {{ quantity }}
        </output>
        <button
            type="button"
            aria-label="Increase quantity"
            :disabled="quantity >= max"
            class="flex w-12 items-center justify-center text-text-muted transition-colors hover:bg-bg-muted-hover hover:text-text-primary disabled:pointer-events-none disabled:opacity-40"
            @click="emit('update', quantity + 1)"
        >
            <Plus class="size-5" />
        </button>
    </div>
</template>

<script setup lang="ts">
import { Minus, Plus } from "@lucide/vue";

defineProps<{
    quantity: number;
    // The product's whole stock: the cart can't hold more
    max: number;
}>();

const emit = defineEmits<{ update: [quantity: number] }>();
</script>
