<template>
    <div class="flex size-10 shrink-0 items-center justify-center rounded-md border border-border bg-bg-inset">
        <img
            v-if="product.image && !failed"
            :src="itemImageUrl(product.image)"
            :alt="product.name"
            class="size-8 object-contain"
            @error="failed = true"
        />
        <Package v-else class="size-4 text-text-faint" />
    </div>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import { Package } from "@lucide/vue";
import type { Product } from "@/stores";
import { itemImageUrl } from "@/stores";

const props = defineProps<{ product: Product }>();

const failed = ref(false);

watch(() => itemImageUrl(props.product.image), () => {
    failed.value = false;
});
</script>
