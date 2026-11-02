<template>
    <aside class="fixed left-4 top-4 flex w-72 flex-col gap-3 rounded-2xl border border-border bg-bg-surface p-4 shadow-2xl">
        <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
            <Move3d class="size-4 text-text-muted" /> Machine position
        </h3>

        <dl class="grid grid-cols-2 gap-x-3 gap-y-1 text-xs">
            <template v-for="axis in axes" :key="axis">
                <dt class="uppercase text-text-faint">{{ axis }}</dt>
                <dd class="text-right tabular-nums text-text-primary">{{ placement.position[axis].toFixed(2) }}</dd>
            </template>
        </dl>

        <div class="grid grid-cols-2 gap-2">
            <Button size="sm" :variant="placement.mode === 'translate' ? 'primary' : 'outline'" @click="placement.mode = 'translate'">
                <Move class="size-3.5" /> Move
            </Button>
            <Button size="sm" :variant="placement.mode === 'rotate' ? 'primary' : 'outline'" @click="placement.mode = 'rotate'">
                <RotateCw class="size-3.5" /> Rotate
            </Button>
        </div>

        <Button size="sm" variant="outline" @click="placement.snap">
            <ArrowDownToLine class="size-3.5" /> Snap to ground <Kbd>G</Kbd>
        </Button>

        <p class="flex items-center gap-1.5 text-xs text-text-faint">
            <Kbd>Left Alt</Kbd> {{ placement.cursor ? "walk and look around" : "back to the cursor" }}
        </p>

        <div class="grid grid-cols-2 gap-2">
            <Button size="sm" variant="outline" @click="placement.cancel">Cancel <Kbd>Esc</Kbd></Button>
            <Button size="sm" @click="placement.confirm">Confirm</Button>
        </div>
    </aside>
</template>

<script setup lang="ts">
import { ArrowDownToLine, Move, Move3d, RotateCw } from "@lucide/vue";
import { Button, Kbd } from "@vezironi/veyra-ui";
import { usePlacementStore } from "@/stores/placement";

const placement = usePlacementStore();

const axes = ["x", "y", "z", "heading"] as const;
</script>
