<template>
    <div class="flex items-center justify-between gap-4">
        <div class="min-w-0">
            <p class="text-sm font-medium text-text-primary">{{ label }}</p>
            <p v-if="description" class="text-xs text-text-faint">{{ description }}</p>
        </div>
        <div class="shrink-0">
            <slot />
        </div>
    </div>
</template>

<script setup lang="ts">
defineProps<{
    label: string;
    description?: string;
}>();
</script>
