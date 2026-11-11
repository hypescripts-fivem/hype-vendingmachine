<template>
    <!-- Same bottom padding as the shop: the model's screen crops the bottom of the texture -->
    <main class="flex h-screen w-screen flex-col items-center justify-center gap-16 overflow-hidden bg-bg-base pb-[20px]">
        <div class="flex size-[32rem] items-center justify-center">
            <!-- out-in: the old image is gone before the next one fades in, so they never overlap -->
            <Transition
                mode="out-in"
                enter-active-class="transition-opacity duration-1000"
                leave-active-class="transition-opacity duration-1000"
                enter-from-class="opacity-0"
                leave-to-class="opacity-0"
            >
                <img v-if="image" :key="image" :src="image" alt="" class="idle-drift size-full object-contain" />
            </Transition>
        </div>

        <div class="flex flex-col items-center gap-8 text-center">
            <div class="flex size-32 items-center justify-center rounded-3xl border border-border bg-bg-surface">
                <ShoppingCart class="size-16 text-text-primary" />
            </div>
            <p class="text-6xl font-semibold text-text-primary">{{ t("idle.use_to_order") }}</p>
        </div>
    </main>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { ShoppingCart } from "@lucide/vue";
import { useShopStore } from "@/stores";
import { asList, FetchNUI } from "@/utils";
import { t } from "@/utils/locale";

// How long each product image stays before the next one fades in
const IMAGE_MS = 4000;

const shop = useShopStore();

// Only the images that loaded: a missing one would show as a broken image
const images = ref<string[]>([]);
const index = ref(0);

const image = computed(() => images.value.length ? images.value[index.value % images.value.length] : undefined);

let timer: ReturnType<typeof setInterval> | undefined;

/**
 * @param src Image url
 * @returns Whether the image loaded
 */
function preload(src: string): Promise<boolean> {
    return new Promise((resolve) => {
        const img = new Image();
        img.onload = () => resolve(true);
        img.onerror = () => resolve(false);
        img.src = src;
    });
};

onMounted(async () => {
    const response = await FetchNUI<string[]>("screen:idle", {}, ["water.png", "cola.png", "chips.png", "chocolate.png", "donut.png"]);
    const urls = asList<string>(response.data).map((name) => "nui://" + shop.inventoryImagePath + name);
    const loaded = await Promise.all(urls.map(preload));

    images.value = urls.filter((_, i) => loaded[i]);
    timer = setInterval(() => index.value++, IMAGE_MS);
});

onBeforeUnmount(() => clearInterval(timer));
</script>

<style scoped>
/* A slow drift so the screen never looks frozen */
.idle-drift {
    animation: idle-drift 8s ease-in-out infinite alternate;
}

@keyframes idle-drift {
    from { transform: scale(0.95) rotate(-4deg); }
    to { transform: scale(1.05) rotate(4deg); }
}
</style>
