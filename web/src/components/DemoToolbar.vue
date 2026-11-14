<template>
    <!-- Website demo only (utils/demo.ts) -->
    <header class="fixed inset-x-0 top-0 z-50 flex h-16 items-center justify-between gap-x-4 px-5">
        <a
            :href="DEMO_BACK_URL"
            class="flex items-center gap-x-1.5 rounded-md px-3 py-1.5 text-sm font-medium text-text-muted transition-colors hover:bg-bg-muted hover:text-text-primary"
        >
            <ArrowLeft class="size-4" />
            Demos
        </a>

        <nav class="flex items-center gap-x-1 rounded-md border border-border bg-bg-surface p-1">
            <a
                v-for="view in views"
                :key="view.id"
                :href="`?view=${view.id}`"
                class="flex items-center gap-x-1.5 rounded px-3 py-1.5 text-xs font-medium transition-colors"
                :class="demoView === view.id ? 'bg-inverse text-text-inverse' : 'text-text-muted hover:bg-bg-muted hover:text-text-primary'"
            >
                <component :is="view.icon" class="size-3.5" />
                {{ view.label }}
            </a>
        </nav>

        <p class="text-sm font-medium text-text-faint">Hype Vending Machine</p>
    </header>
</template>

<script setup lang="ts">
import type { Component } from "vue";
import { ArrowLeft, ShieldCheck, ShoppingCart, Smartphone, Store } from "@lucide/vue";
import { DEMO_BACK_URL, demoView, type DemoView } from "@/utils/demo";

const views: { id: DemoView; label: string; icon: Component }[] = [
    { id: "shop", label: "Vending Menu", icon: ShoppingCart },
    { id: "screen", label: "Touchscreen", icon: Smartphone },
    { id: "owner", label: "Owner Panel", icon: Store },
    { id: "admin", label: "Admin Panel", icon: ShieldCheck },
];
</script>
