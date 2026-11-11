<template>
    <Modal :title="t('admin.create.title')" :icon="SquarePlus" width="44rem" @close="emit('close')" >
        <!-- The form is taller than the panel, so only the body scrolls and the footer stays in reach -->
        <div class="flex max-h-[70vh] flex-col gap-3 overflow-y-auto px-5 py-4">
            <Alert v-if="createError" variant="danger" :title="createError" />

            <MachineForm v-model="draft" />
        </div>

        <template #footer>
            <p v-if="touched && error" class="mr-auto flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                {{ error }}
            </p>
            <Button variant="outline" size="sm" @click="emit('close')">{{ t("admin.common.cancel") }}</Button>
            <Button size="sm" :disabled="!!error || admin.saving" @click="create">
                {{ admin.saving ? t("admin.create.creating") : t("admin.create.submit") }}
            </Button>
        </template>
    </Modal>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CircleAlert, SquarePlus } from "@lucide/vue";
import { Alert, Button, Modal } from "@vezironi/veyra-ui";
import { emptyMachineConfig, useAdminStore, validateMachine, type MachineConfig } from "@/stores/admin";
import MachineForm from "./MachineForm.vue";
import { t } from "@/utils/locale";

const emit = defineEmits<{ close: [] }>();

const admin = useAdminStore();

const blank = (): MachineConfig => emptyMachineConfig(admin.settings);

const draft = ref<MachineConfig>(blank());
const createError = ref<string>();

// A fresh form is always invalid (no name yet), so the reason only shows once something was filled in
const touched = computed(() => JSON.stringify(draft.value) !== JSON.stringify(blank()));
const error = computed(() => validateMachine(draft.value));

async function create() {
    if (error.value) return;

    draft.value.name = draft.value.name.trim();
    createError.value = undefined;

    const response = await admin.createMachine(draft.value);

    if (response.success && response.data) {
        emit("close");
        admin.openMachine(response.data.id);
    } else {
        createError.value = response.error ?? t("admin.create.error");
    }
};
</script>
