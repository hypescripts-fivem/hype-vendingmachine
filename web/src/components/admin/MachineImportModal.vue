<template>
    <Modal title="Import machines" :icon="Upload" width="36rem" @close="emit('close')">
        <div class="flex flex-col gap-3 px-5 py-4 text-sm text-text-muted">
            <p>
                Paste a machine export from Settings on another server. Machines arrive for sale with no owner, money or stock.
            </p>

            <Textarea
                v-model="text"
                :rows="8"
                :resizable="false"
                class="font-mono text-xs"
                placeholder='{ "machines": [ ... ] }'
            />

            <!-- FiveM's browser has no file picker, so loading a file is only offered outside the game -->
            <div v-if="!isNative" class="flex items-center gap-2">
                <input ref="fileInput" type="file" accept=".json,application/json" class="hidden" @change="loadFile" />
                <Button variant="outline" size="sm" @click="fileInput?.click()">
                    <FileUp class="size-3.5" />
                    Load file
                </Button>
                <span v-if="fileName" class="truncate text-xs text-text-faint">{{ fileName }}</span>
            </div>

            <template v-if="result">
                <p v-if="result.error" class="flex items-center gap-1.5 text-xs text-danger">
                    <CircleAlert class="size-3.5 shrink-0" />
                    {{ result.error }}
                </p>

                <template v-else>
                    <p class="text-xs">
                        <span class="text-text-primary">{{ ready }} ready to import</span>
                        <span v-if="result.skipped.length" class="text-text-faint"> · {{ result.skipped.length }} skipped</span>
                    </p>
                    <!-- Skipped ones first, so problems aren't hidden below a long list -->
                    <div class="flex max-h-56 flex-col gap-1 overflow-y-auto rounded-xl border border-border p-2">
                        <div v-for="(entry, index) in result.skipped" :key="`skip-${index}`" class="flex items-center gap-2 rounded-lg px-2 py-1.5">
                            <CircleMinus class="size-3.5 shrink-0 text-text-faint" />
                            <span class="truncate text-text-muted">{{ entry.name }}</span>
                            <span class="ml-auto shrink-0 text-xs text-warning">{{ entry.reason }}</span>
                        </div>
                        <div v-for="(machine, index) in result.machines" :key="`ok-${index}`" class="flex items-center gap-2 rounded-lg px-2 py-1.5">
                            <CircleCheck class="size-3.5 shrink-0 text-success" />
                            <span class="truncate font-medium text-text-primary">{{ machine.name }}</span>
                            <span class="ml-auto shrink-0 text-xs text-text-faint">{{ machine.location.label || "No area" }}</span>
                        </div>
                    </div>
                </template>
            </template>

            <p v-if="importError" class="flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                {{ importError }}
            </p>
        </div>

        <template #footer>
            <Button variant="outline" size="sm" @click="emit('close')">Cancel</Button>
            <Button size="sm" :disabled="!ready || admin.saving" @click="confirm">
                {{ admin.saving ? "Importing..." : ready ? `Import ${ready} machine${ready === 1 ? "" : "s"}` : "Import" }}
            </Button>
        </template>
    </Modal>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CircleAlert, CircleCheck, CircleMinus, FileUp, Upload } from "@lucide/vue";
import { Button, Modal, Textarea } from "@vezironi/veyra-ui";
import { useAdminStore } from "@/stores/admin";
import { isNative } from "@/utils";
import { parseMachineImport } from "./machineTransfer";

const emit = defineEmits<{ close: [] }>();

const admin = useAdminStore();

const text = ref("");
const fileInput = ref<HTMLInputElement>();
const fileName = ref<string>();
const importError = ref<string>();

// Parsed as it's typed, so the list shows what will happen before anything is sent
const result = computed(() => {
    if (!text.value.trim()) return undefined;

    return parseMachineImport(text.value, {
        settings: admin.settings,
        existing: admin.machines,
        products: admin.products.map((product) => product.id),
    });
});

const ready = computed(() => result.value?.machines.length ?? 0);

async function loadFile(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    fileName.value = file.name;
    text.value = await file.text();
    // Lets the same file be picked again after editing it
    input.value = "";
};

async function confirm() {
    if (!result.value?.machines.length) return;

    importError.value = undefined;

    const response = await admin.importMachines(result.value.machines);

    if (response.success) {
        emit("close");
    } else {
        importError.value = response.error ?? "The machines could not be imported.";
    }
};
</script>
