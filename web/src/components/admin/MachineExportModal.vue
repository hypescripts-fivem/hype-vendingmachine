<template>
    <Modal title="Export machines" :icon="Download" width="36rem" @close="emit('close')">
        <div class="flex flex-col gap-3 px-5 py-4 text-sm text-text-muted">
            <p>
                {{ admin.machines.length }} machine{{ admin.machines.length === 1 ? "" : "s" }}. Only names, models, locations, prices and
                products are included; owners, balances and stock stay on this server.
            </p>

            <textarea
                ref="output"
                readonly
                rows="12"
                :value="json"
                aria-label="Exported machines"
                class="w-full resize-none rounded-lg border border-border bg-bg-inset p-3 font-mono text-xs text-text-muted outline-none focus:border-text-faint"
                @focus="output?.select()"
            />

            <p v-if="copyFailed" class="flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                Couldn't copy automatically. Click the text and press Ctrl+C.
            </p>
        </div>

        <template #footer>
            <!-- Downloads don't work in FiveM's browser; copying does -->
            <Button v-if="!isNative" variant="outline" size="sm" @click="download">
                <Download class="size-3.5" />
                Download
            </Button>
            <Button size="sm" @click="copy">
                <Check v-if="copied" class="size-3.5" />
                <Copy v-else class="size-3.5" />
                {{ copied ? "Copied" : "Copy JSON" }}
            </Button>
        </template>
    </Modal>
</template>

<script setup lang="ts">
import { onBeforeUnmount, ref } from "vue";
import { Check, CircleAlert, Copy, Download } from "@lucide/vue";
import { Button, Modal } from "@vezironi/veyra-ui";
import { useAdminStore } from "@/stores/admin";
import { isNative } from "@/utils";
import { exportMachines } from "./machineTransfer";

const emit = defineEmits<{ close: [] }>();

const admin = useAdminStore();

// Taken once when the modal opens, so the text doesn't shift while it's being copied
const json = exportMachines(admin.machines);

const output = ref<HTMLTextAreaElement>();
const copied = ref(false);
const copyFailed = ref(false);
let copiedTimer: ReturnType<typeof setTimeout> | undefined;

async function copy() {
    copyFailed.value = false;

    try {
        await navigator.clipboard.writeText(json);
    } catch {
        // The async clipboard API isn't always allowed inside NUI; selecting and copying is
        output.value?.select();
        if (!document.execCommand("copy")) {
            copyFailed.value = true;
            return;
        }
    }

    copied.value = true;
    clearTimeout(copiedTimer);
    copiedTimer = setTimeout(() => copied.value = false, 2000);
};

function download() {
    const url = URL.createObjectURL(new Blob([json], { type: "application/json" }));
    const link = document.createElement("a");

    link.href = url;
    link.download = `vending-machines-${new Date().toISOString().slice(0, 10)}.json`;
    link.click();
    URL.revokeObjectURL(url);
};

onBeforeUnmount(() => clearTimeout(copiedTimer));
</script>
