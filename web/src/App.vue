<script setup lang="ts">
import { defineAsyncComponent, type Component } from 'vue';
import ShopView from './pages/ShopView.vue';
import PurchaseView from './pages/PurchaseView.vue';
import { useAppStore, type View } from './stores/app';

const app = useAppStore();

// owner/admin pull in echarts, keep them out of the vending bundle
const pages: Record<View, Component> = {
  vending: ShopView,
  purchase: PurchaseView,
  owner: defineAsyncComponent(() => import('./pages/OwnerView.vue')),
  admin: defineAsyncComponent(() => import('./pages/AdminView.vue')),
  screen: defineAsyncComponent(() => import('./pages/ScreenView.vue')),
  idle: defineAsyncComponent(() => import('./pages/IdleView.vue')),
};
</script>

<template>
  <div class="w-screen h-screen items-center justify-center overflow-hidden flex">
    <component :is="pages[app.view]" v-if="app.visible && app.ready" />
  </div>
</template>
