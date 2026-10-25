<template>
    <div class="grid gap-1.5 text-sm text-text-muted">
        <span v-if="label">{{ label }}</span>
        <Button variant="outline" class="w-full justify-between" :disabled="disabled" @click="openModal">
            <span class="tabular-nums text-text-primary">{{ display }}</span>
            <Clock class="size-4 text-text-faint" />
        </Button>

        <Modal v-if="open" :title="label ?? 'Pick a time'" :icon="Clock" width="20rem" @close="open = false">
            <div class="flex items-end gap-2 px-5 py-4">
                <WheelPicker v-model="hour" :options="hourOptions" label="Hour" class="flex-1" />
                <!-- Same height as a wheel so the colon lines up with the selection band -->
                <span
                    aria-hidden="true"
                    class="flex items-center text-lg font-semibold text-text-faint"
                    :style="{ height: `${wheelHeight}px` }"
                >:</span>
                <WheelPicker v-model="minute" :options="minuteOptions" label="Minute" class="flex-1" />
            </div>
            <template #footer>
                <Button variant="outline" size="sm" @click="open = false">Cancel</Button>
                <Button size="sm" @click="confirm">Done</Button>
            </template>
        </Modal>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { Clock } from "@lucide/vue";
import { Button, Modal } from "@vezironi/veyra-ui";
import WheelPicker from "@/components/WheelPicker.vue";

defineProps<{
    label?: string;
    disabled?: boolean;
}>();

// "HH:MM", 24 hour
const model = defineModel<string>({ required: true });

// WheelPicker defaults: 36px rows, 5 visible
const wheelHeight = 36 * 5;

const pad = (value: number) => String(value).padStart(2, "0");

const hourOptions = Array.from({ length: 24 }, (_, value) => ({ label: pad(value), value: pad(value) }));
const minuteOptions = Array.from({ length: 60 }, (_, value) => ({ label: pad(value), value: pad(value) }));

function parse(value: string): [string, string] {
    const [hours, minutes] = value.split(":").map((part) => Math.floor(Number(part)));
    const clamp = (number: number | undefined, max: number) => pad(Number.isFinite(number) ? Math.min(max, Math.max(0, number!)) : 0);

    return [clamp(hours, 23), clamp(minutes, 59)];
};

const display = computed(() => parse(model.value).join(":"));

const open = ref(false);
const hour = ref("00");
const minute = ref("00");

// The wheels edit a copy; the value only changes on Done
function openModal() {
    [hour.value, minute.value] = parse(model.value);
    open.value = true;
};

function confirm() {
    model.value = `${hour.value}:${minute.value}`;
    open.value = false;
};
</script>
