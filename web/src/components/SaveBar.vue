<template>
    <!-- Absolute to the panel's content column (it is `relative`), so it floats over the scroll area -->
    <Transition
        enter-active-class="transition duration-200 ease-out"
        enter-from-class="translate-y-4 opacity-0"
        leave-active-class="transition duration-150 ease-in"
        leave-to-class="translate-y-4 opacity-0"
    >
        <div v-if="dirty" class="absolute inset-x-5 bottom-5 z-10">
            <div
                role="status"
                class="flex w-full items-center justify-between gap-4 rounded-2xl border border-border bg-bg-elevated/60 px-4 py-3 shadow-2xl"
            >
                <p class="flex items-center gap-2 text-sm" :class="error ? 'text-danger' : 'text-text-primary'">
                    <CircleAlert v-if="error" class="size-4 shrink-0" />
                    <span v-else class="size-2 shrink-0 rounded-full bg-warning" />
                    {{ error ?? "You have unsaved changes." }}
                </p>
                <div class="flex shrink-0 items-center gap-2">
                    <Button variant="outline" size="sm" :disabled="saving" @click="emit('reset')">Reset</Button>
                    <Button size="sm" :disabled="!!error || saving" @click="emit('save')">
                        {{ saving ? "Saving..." : saveLabel ?? "Save changes" }}
                    </Button>
                </div>
            </div>
        </div>
    </Transition>
</template>

<script setup lang="ts">
import { CircleAlert } from "@lucide/vue";
import { Button } from "@vezironi/veyra-ui";

defineProps<{
    dirty: boolean;
    error?: string;
    saving?: boolean;
    saveLabel?: string;
}>();

const emit = defineEmits<{ reset: []; save: [] }>();
</script>
