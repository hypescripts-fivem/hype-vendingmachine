<template>
    <aside class="flex w-16 shrink-0 flex-col items-center border-r border-border bg-bg-surface">
        <div class="flex h-16 w-full shrink-0 items-center justify-center border-b border-border">
            <div class="flex size-9 items-center justify-center rounded-lg border border-border bg-bg-muted text-text-primary">
                <component :is="icon" class="size-4" />
            </div>
        </div>

        <nav class="flex flex-1 flex-col items-center gap-1.5 py-3">
            <Tooltip v-for="item in sections" :key="item.value" :content="item.label" side="right">
                <button
                    type="button"
                    :aria-label="item.label"
                    :aria-current="model === item.value ? 'page' : undefined"
                    :class="[
                        'relative flex size-10 items-center justify-center rounded-lg transition-colors',
                        'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring',
                        model === item.value
                            ? 'bg-bg-muted-hover text-text-primary'
                            : 'text-text-faint hover:bg-bg-muted hover:text-text-primary',
                    ]"
                    @click="model = item.value"
                >
                    <component :is="item.icon" class="size-4.5" />
                    <span
                        v-if="alerts?.includes(item.value)"
                        class="absolute right-1.5 top-1.5 size-2 rounded-full bg-danger ring-2 ring-bg-surface"
                    />
                </button>
            </Tooltip>
        </nav>

        <div class="pb-3">
            <Tooltip content="Close" side="right">
                <button
                    type="button"
                    aria-label="Close"
                    class="flex size-10 items-center justify-center rounded-lg text-danger transition-colors hover:bg-danger/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
                    @click="close"
                >
                    <LogOut class="size-4.5" />
                </button>
            </Tooltip>
        </div>
    </aside>
</template>

<script setup lang="ts" generic="T extends string">
import type { Component } from "vue";
import { LogOut } from "@lucide/vue";
import { Tooltip } from "@vezironi/veyra-ui";
import { useAppStore } from "@/stores/app";

export interface PanelSection<V extends string = string> {
    value: V;
    label: string;
    description: string;
    icon: Component;
};

defineProps<{
    icon: Component;
    sections: PanelSection<T>[];
    // section values that show a red dot
    alerts?: T[];
}>();

const model = defineModel<T>({ required: true });

const app = useAppStore();

function close() {
    app.close();
};
</script>
