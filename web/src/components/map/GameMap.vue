<template>
    <div class="relative size-full">
        <div ref="container" class="game-map size-full" />

        <div class="absolute right-3 bottom-3 z-[1000] flex flex-col overflow-hidden rounded-lg border border-border bg-bg-surface shadow-lg">
            <button
                type="button"
                class="grid size-8 place-items-center text-text-muted transition-colors hover:bg-bg-muted hover:text-text-primary"
                aria-label="Zoom in"
                @click="map?.zoomIn()"
            >
                <Plus class="size-4" />
            </button>
            <div class="h-px bg-border" />
            <button
                type="button"
                class="grid size-8 place-items-center text-text-muted transition-colors hover:bg-bg-muted hover:text-text-primary"
                aria-label="Zoom out"
                @click="map?.zoomOut()"
            >
                <Minus class="size-4" />
            </button>
        </div>
    </div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, shallowRef, watch } from "vue";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { Minus, Plus } from "@lucide/vue";
import { CustomCRS } from "./CustomCRS";

export interface MapBlip {
    id: string;
    // GTA world coordinates
    coords: { x: number; y: number };
    label: string;
    color: string;
};

const TILE_SIZE = 256;

// Where the island sits inside the square atlas, as fractions of its width and height;
// the rest is open sea, so the map is fitted to this instead of the whole atlas
const ISLAND = { left: 0.12, right: 0.88, top: 0.02, bottom: 0.99 };

const props = withDefaults(defineProps<{
    blips?: MapBlip[];
    minZoom?: number;
    maxZoom?: number;
}>(), {
    blips: () => [],
    minZoom: 1.5,
    maxZoom: 4,
});

const emit = defineEmits<{ blipClick: [id: string] }>();

const container = ref<HTMLDivElement>();

// Shallow so Leaflet's internals aren't made reactive; only read by the zoom buttons
const map = shallowRef<L.Map>();
let observer: ResizeObserver | undefined;
const markers = new Map<string, L.Marker>();

function escapeHtml(value: string): string {
    return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
};

function blipIcon(blip: MapBlip): L.DivIcon {
    return L.divIcon({
        className: "",
        html: `
            <div class="map-blip" style="--blip-color: ${escapeHtml(blip.color)}">
                <div class="map-blip__dot"></div>
                <div class="map-blip__label">${escapeHtml(blip.label)}</div>
            </div>
        `,
        iconSize: [16, 16],
        iconAnchor: [8, 8],
    });
};

function syncBlips() {
    if (!map.value) return;

    markers.forEach((marker) => marker.remove());
    markers.clear();

    for (const blip of props.blips) {
        const marker = L.marker(L.latLng(blip.coords.y, blip.coords.x), { icon: blipIcon(blip) }).addTo(map.value);
        marker.on("click", () => emit("blipClick", blip.id));
        markers.set(blip.id, marker);
    }
};

watch(() => props.blips, syncBlips, { deep: true });

function focus(coords: { x: number; y: number }, zoom?: number) {
    map.value?.setView(L.latLng(coords.y, coords.x), zoom ?? map.value.getZoom(), { animate: true });
};

defineExpose({ focus });

onMounted(() => {
    if (!container.value) return;

    const { minZoom, maxZoom } = props;
    const mapPixelSize = Math.pow(2, maxZoom) * TILE_SIZE;

    const instance = L.map(container.value, {
        crs: CustomCRS,
        minZoom,
        maxZoom,
        preferCanvas: true,
        maxBoundsViscosity: 1,
        zoomControl: false,
        attributionControl: false,
        fadeAnimation: false,
        markerZoomAnimation: false,
        wheelPxPerZoomLevel: 120,
        zoomSnap: 0.25,
        zoomDelta: 0.5,
    });

    map.value = instance;

    const bounds = L.latLngBounds(
        instance.unproject([0, mapPixelSize], maxZoom),
        instance.unproject([mapPixelSize, 0], maxZoom),
    );
    const island = L.latLngBounds(
        instance.unproject([ISLAND.left * mapPixelSize, ISLAND.bottom * mapPixelSize], maxZoom),
        instance.unproject([ISLAND.right * mapPixelSize, ISLAND.top * mapPixelSize], maxZoom),
    );

    instance.setMaxBounds(bounds);
    fitToContainer(island);

    observer = new ResizeObserver(() => {
        instance.invalidateSize();
        fitToContainer(island, true);
    });
    observer.observe(container.value);

    // Relative to the page (vite base "./"), so it resolves both in the browser and inside NUI
    L.tileLayer(`${import.meta.env.BASE_URL}atlas/{z}/{x}/{y}.webp`, {
        tileSize: TILE_SIZE,
        keepBuffer: 2,
        updateWhenIdle: true,
        updateWhenZooming: false,
        noWrap: true,
        bounds,
        minZoom,
        maxZoom,
    }).addTo(instance);

    syncBlips();
});

// Zoomed all the way out the whole island fits; the space around it is the same color as the sea tiles
function fitToContainer(island: L.LatLngBounds, keepView = false) {
    if (!map.value) return;

    const fitZoom = Math.max(props.minZoom, map.value.getBoundsZoom(island, false));
    map.value.setMinZoom(fitZoom);

    if (!keepView) {
        map.value.setView(island.getCenter(), fitZoom, { animate: false });
    } else if (map.value.getZoom() < fitZoom) {
        map.value.setZoom(fitZoom, { animate: false });
    }
};

onBeforeUnmount(() => {
    observer?.disconnect();
    markers.forEach((marker) => marker.remove());
    markers.clear();
    map.value?.remove();
    map.value = undefined;
});
</script>

<style scoped>
/* Same as the atlas' ocean tiles, so the sea runs on past the edge of the tiles */
.game-map {
    background-color: #111111;
}

/* At fractional zoom Leaflet leaves sub-pixel seams, so tiles overlap by 1px. Leaflet's own
   seam fix (plus-lighter) adds the overlap up into bright lines, so tiles blend normally instead */
.game-map :deep(.leaflet-tile) {
    width: 257px !important;
    height: 257px !important;
    mix-blend-mode: normal !important;
}
</style>

<style>
.map-blip {
    position: relative;
    width: 16px;
    height: 16px;
    cursor: pointer;
}

.map-blip__dot {
    width: 16px;
    height: 16px;
    border-radius: 9999px;
    background: var(--blip-color);
    border: 2px solid var(--color-text-primary);
    box-shadow: 0 2px 6px rgb(0 0 0 / 0.5);
    transition: transform 0.15s ease;
}

.map-blip:hover .map-blip__dot {
    transform: scale(1.25);
}

.map-blip__label {
    position: absolute;
    bottom: calc(100% + 6px);
    left: 50%;
    transform: translateX(-50%);
    padding: 2px 6px;
    border-radius: 6px;
    border: 1px solid var(--color-border);
    background: var(--color-bg-surface);
    color: var(--color-text-primary);
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    white-space: nowrap;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.15s ease;
}

.map-blip:hover .map-blip__label {
    opacity: 1;
}
</style>
