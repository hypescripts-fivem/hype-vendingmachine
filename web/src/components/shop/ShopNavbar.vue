<template>
    <header class="flex h-16 shrink-0 items-center gap-4 border-b border-border px-5">
        <div class="flex items-center gap-2.5">
            <div class="flex size-9 items-center justify-center rounded-lg border border-border bg-bg-muted text-text-primary">
                <Store class="size-4" />
            </div>
            <div class="leading-tight">
                <h1 class="text-sm font-semibold text-text-primary">{{ shop.name || t("shop.default_name") }}</h1>
                <p class="text-xs text-text-faint">{{ t("shop.navbar.products", shop.filteredProducts.length) }}</p>
            </div>
        </div>

        <Tabs v-model="shop.category" :tabs="tabs" class="ml-4 w-auto" />

        <div class="ml-auto w-60">
            <Inputs v-model="shop.search" size="sm" :placeholder="t('shop.navbar.search')" class="py-2!" />
        </div>

        <Button variant="outline" size="sm" :aria-label="t('common.close')" @click="close" class="p-2!">
            <X class="size-4" />
        </Button>
    </header>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { Store, X } from "@lucide/vue";
import { Button, Inputs, Tabs } from "@vezironi/veyra-ui";
import { useShopStore } from "@/stores";
import { useAppStore } from "@/stores/app";
import { t } from "@/utils/locale";

const shop = useShopStore();
const app = useAppStore();

const tabs = computed(() => [
    { label: t("shop.navbar.all"), value: "all" },
    ...shop.categories.map((category) => ({
        label: category.charAt(0).toUpperCase() + category.slice(1),
        value: category,
    })),
]);

function close() {
    app.close();
};
</script>
