<template>
    <div class="grid gap-1.5 text-sm text-text-muted" :class="disabled && 'opacity-50'">
        <span v-if="label">{{ label }}</span>

        <div
            class="relative overflow-hidden rounded-xl border border-border bg-bg-inset focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-ring"
            :style="{ height: `${itemHeight * visibleRows}px` }"
        >
            <!-- Selection band sits behind the rows so the centered value reads as picked -->
            <div
                aria-hidden="true"
                class="pointer-events-none absolute inset-x-2 rounded-lg bg-bg-muted"
                :style="{ top: `${padding}px`, height: `${itemHeight}px` }"
            />

            <div
                ref="scroller"
                role="spinbutton"
                :tabindex="disabled ? -1 : 0"
                :aria-label="label"
                :aria-valuetext="options[selectedIndex]?.label"
                :aria-disabled="disabled || undefined"
                class="relative h-full touch-none select-none overflow-y-scroll outline-none [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
                :class="[disabled && 'pointer-events-none', dragging ? 'cursor-grabbing' : 'cursor-grab']"
                :style="{
                    perspective: '600px',
                    maskImage: 'linear-gradient(to bottom, transparent, black 30%, black 70%, transparent)',
                }"
                @scroll="onScroll"
                @keydown="onKeydown"
                @wheel.prevent="onWheel"
                @pointerdown="onPointerDown"
                @pointermove="onPointerMove"
                @pointerup="onPointerUp"
                @pointercancel="onPointerUp"
            >
                <div :style="{ paddingBlock: `${padding}px` }">
                    <div
                        v-for="(option, index) in looped"
                        :key="index"
                        class="flex items-center justify-center text-base tabular-nums text-text-primary"
                        :style="[{ height: `${itemHeight}px` }, rowStyle(index)]"
                    >
                        {{ option.label }}
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch, type StyleValue } from "vue";

interface WheelOption {
    label: string;
    value: string;
};

const props = withDefaults(defineProps<{
    options: WheelOption[];
    label?: string;
    disabled?: boolean;
    itemHeight?: number;
    // Odd, so one row sits exactly in the middle
    visibleRows?: number;
}>(), {
    disabled: false,
    itemHeight: 36,
    visibleRows: 5,
});

const model = defineModel<string>();

// The list is repeated so it can be scrolled past either end; after every stop the
// position jumps back into the middle copy, which looks identical, so it never runs out
const copies = 5;
const middleCopy = Math.floor(copies / 2);

const scroller = ref<HTMLElement>();
const scrollTop = ref(0);
const dragging = ref(false);
let settleTimer: ReturnType<typeof setTimeout> | undefined;
// Row the wheel is heading to, so quick wheel notches stack instead of restarting from mid-animation
let targetIndex: number | undefined;

const padding = computed(() => props.itemHeight * Math.floor(props.visibleRows / 2));
const looped = computed(() => Array.from({ length: copies }, () => props.options).flat());

const selectedIndex = computed(() => Math.max(0, props.options.findIndex((option) => option.value === model.value)));

const wrap = (index: number) => ((index % props.options.length) + props.options.length) % props.options.length;

const currentIndex = () => Math.round((scroller.value?.scrollTop ?? 0) / props.itemHeight);

// Rows curve away from the center like a drum; distance is counted in rows
function rowStyle(index: number): StyleValue {
    const distance = index - scrollTop.value / props.itemHeight;
    if (Math.abs(distance) > props.visibleRows) return { opacity: 0 };

    return {
        transform: `rotateX(${-distance * 20}deg)`,
        opacity: Math.max(0.15, 1 - Math.abs(distance) * 0.3),
    };
};

function scrollToIndex(index: number, behavior: ScrollBehavior = "auto") {
    const top = index * props.itemHeight;
    if (!scroller.value) return;

    // Already there: no scroll event will fire, so settle right away
    if (Math.abs(scroller.value.scrollTop - top) < 0.5) {
        settle();
    } else {
        scroller.value.scrollTo({ top, behavior });
    }
};

function step(delta: number) {
    targetIndex = (targetIndex ?? currentIndex()) + delta;
    scrollToIndex(targetIndex, "smooth");
};

function jumpToValue() {
    const top = (middleCopy * props.options.length + selectedIndex.value) * props.itemHeight;

    if (scroller.value) scroller.value.scrollTop = top;
    scrollTop.value = top;
};

// Every input ends here: line up on a row, pick its value, then hop back to the middle copy
function settle() {
    if (!scroller.value || !props.options.length || dragging.value) return;

    const index = currentIndex();

    if (Math.abs(scroller.value.scrollTop - index * props.itemHeight) > 0.5) {
        scroller.value.scrollTo({ top: index * props.itemHeight, behavior: "smooth" });
        return;
    }

    targetIndex = undefined;

    const option = props.options[wrap(index)]!;
    if (option.value !== model.value) model.value = option.value;

    const recentered = middleCopy * props.options.length + wrap(index);
    if (recentered !== index) scroller.value.scrollTop = recentered * props.itemHeight;
};

function onScroll() {
    scrollTop.value = scroller.value?.scrollTop ?? 0;

    // scrollend isn't in every CEF build, so wait for scrolling to stop instead
    clearTimeout(settleTimer);
    settleTimer = setTimeout(settle, 120);
};

// One row per notch; trackpads send many small deltas, so they're summed first
let wheelDelta = 0;

function onWheel(event: WheelEvent) {
    wheelDelta += event.deltaY;
    if (Math.abs(wheelDelta) < 40) return;

    step(Math.sign(wheelDelta));
    wheelDelta = 0;
};

function onKeydown(event: KeyboardEvent) {
    const delta = { ArrowUp: -1, ArrowDown: 1 }[event.key];
    if (!delta) return;

    event.preventDefault();
    step(delta);
};

// Drag: the wheel follows the pointer, then coasts a little in the direction it was flicked
let dragStart = { y: 0, top: 0 };
let samples: { y: number; time: number }[] = [];
let moved = false;

function onPointerDown(event: PointerEvent) {
    if (event.button !== 0 || !scroller.value) return;

    scroller.value.setPointerCapture(event.pointerId);
    scroller.value.focus();

    dragging.value = true;
    moved = false;
    targetIndex = undefined;
    dragStart = { y: event.clientY, top: scroller.value.scrollTop };
    samples = [{ y: event.clientY, time: event.timeStamp }];
};

function onPointerMove(event: PointerEvent) {
    if (!dragging.value || !scroller.value) return;

    const offset = event.clientY - dragStart.y;
    if (Math.abs(offset) > 3) moved = true;

    scroller.value.scrollTop = dragStart.top - offset;

    samples.push({ y: event.clientY, time: event.timeStamp });
    samples = samples.filter((sample) => event.timeStamp - sample.time < 100);
};

function onPointerUp(event: PointerEvent) {
    if (!dragging.value || !scroller.value) return;

    dragging.value = false;
    if (scroller.value.hasPointerCapture(event.pointerId)) scroller.value.releasePointerCapture(event.pointerId);

    // A press without movement is a click: go to the row under the pointer
    if (!moved) {
        const rect = scroller.value.getBoundingClientRect();
        const row = Math.floor((event.clientY - rect.top - padding.value + scroller.value.scrollTop) / props.itemHeight);
        scrollToIndex(row, "smooth");
        return;
    }

    const first = samples[0]!;
    const elapsed = event.timeStamp - first.time;
    const velocity = elapsed > 0 ? (event.clientY - first.y) / elapsed : 0;

    // px/ms × 150ms of coasting, capped so a hard flick still lands somewhere readable
    const coast = Math.max(-8, Math.min(8, (-velocity * 150) / props.itemHeight));
    scrollToIndex(Math.round(scroller.value.scrollTop / props.itemHeight + coast), "smooth");
};

// External changes (Reset in the settings page) move the wheel without animation
watch(model, (value) => {
    if (props.options.length && props.options[wrap(Math.round(scrollTop.value / props.itemHeight))]?.value !== value) jumpToValue();
});

onMounted(() => nextTick(jumpToValue));

onBeforeUnmount(() => clearTimeout(settleTimer));
</script>
