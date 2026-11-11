<template>
    <template v-for="(part, index) in parts" :key="index">
        <slot v-if="part.slot !== null" :name="`p${part.slot}`" />
        <template v-else>{{ part.text }}</template>
    </template>
</template>

<script setup lang="ts">
import { computed } from "vue";

const props = defineProps<{ text: string }>();

const parts = computed(() => {
    let slot = 0;

    return props.text
        .split(/(%s)/)
        .filter((part) => part !== "")
        .map((part) => (part === "%s" ? { text: "", slot: slot++ } : { text: part, slot: null }));
});
</script>
