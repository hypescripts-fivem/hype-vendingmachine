<template>
    <div class="flex flex-col gap-4">
        <SaveBar :dirty="dirty" :error="error" :saving="admin.saving" @reset="reset" @save="save" />

        <div class="flex items-center gap-3">
            <Button variant="outline" size="sm" aria-label="Back to machines" @click="admin.editingId = undefined">
                <ArrowLeft class="size-3.5" />
                Machines
            </Button>
            <div class="min-w-0 leading-tight">
                <p class="flex items-center gap-2 truncate text-sm font-semibold text-text-primary">
                    {{ machine.name }}
                    <MachineStatusPill :status="displayStatus(machine)" />
                </p>
                <p class="text-xs text-text-faint">
                    {{ machine.location.label || "No area" }} · {{ machine.ownerName ?? "For sale" }} · Created {{ formatDate(machine.createdAt) }}
                </p>
            </div>

            <div class="ml-auto flex items-center gap-2">
                <Button variant="outline" size="sm" @click="admin.teleport(machine.id)">
                    <Navigation class="size-3.5" />
                    Teleport
                </Button>
                <Button
                    :variant="machine.status === 'disabled' ? 'success' : 'warning'"
                    size="sm"
                    @click="admin.setStatus(machine.id, machine.status === 'disabled' ? 'closed' : 'disabled')"
                >
                    <component :is="machine.status === 'disabled' ? Power : PowerOff" class="size-3.5" />
                    {{ machine.status === "disabled" ? "Enable" : "Disable" }}
                </Button>
            </div>
        </div>

        <div class="grid grid-cols-4 gap-3">
            <StatCard label="Balance" :value="formatMoney(machine.balance)" :icon="Banknote" change-label="Money in the machine" />
            <StatCard label="Revenue" :value="formatMoney(machine.revenue)" :icon="DollarSign" change-label="Last 7 days" />
            <StatCard label="Items sold" :value="machine.sales" :icon="ShoppingBag" change-label="Last 7 days" />
            <StatCard label="Stock level" :value="machine.stockLevel" suffix="%" :icon="Package" change-label="Average across products" />
        </div>

        <MachineForm v-model="draft" :owner="owner" />

        <section class="flex flex-col gap-4 rounded-2xl border border-danger/30 bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-danger">
                <TriangleAlert class="size-4" /> Danger zone
            </h3>
            <SettingRow label="Reset balance" :description="`Remove the ${formatMoney(machine.balance)} currently in the machine.`">
                <Button variant="outline" size="sm" :disabled="machine.balance < 1" @click="confirm = 'reset'">
                    <RotateCcw class="size-3.5" />
                    Reset
                </Button>
            </SettingRow>
            <Separator />
            <SettingRow label="Delete machine" description="Removes the prop, its stock, orders and history for good.">
                <Button variant="danger" size="sm" @click="confirm = 'delete'">
                    <Trash2 class="size-3.5" />
                    Delete
                </Button>
            </SettingRow>
        </section>

        <Modal
            v-if="confirm"
            :title="confirm === 'delete' ? 'Delete machine' : 'Reset balance'"
            :icon="TriangleAlert"
            @close="confirm = undefined"
        >
            <div class="flex flex-col gap-3 px-5 py-4 text-sm text-text-muted">
                <p v-if="confirm === 'delete'">
                    This permanently deletes <b class="text-text-primary">{{ machine.name }}</b>. This can't be undone.
                </p>
                <p v-else>
                    This removes <b class="text-text-primary">{{ formatMoney(machine.balance) }}</b> from <b class="text-text-primary">{{ machine.name }}</b>.
                </p>
                <p v-if="confirmError" class="flex items-center gap-1.5 text-xs text-danger">
                    <CircleAlert class="size-3.5 shrink-0" />
                    {{ confirmError }}
                </p>
            </div>
            <template #footer>
                <Button variant="outline" size="sm" @click="confirm = undefined">Cancel</Button>
                <Button variant="danger" size="sm" :disabled="confirming" @click="runConfirm">
                    {{ confirming ? "Working..." : confirm === "delete" ? "Delete machine" : "Reset balance" }}
                </Button>
            </template>
        </Modal>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import {
    ArrowLeft, Banknote, CircleAlert, DollarSign, Navigation, Package, Power, PowerOff, RotateCcw, ShoppingBag, Trash2, TriangleAlert,
} from "@lucide/vue";
import { Button, Modal, Separator, StatCard } from "@vezironi/veyra-ui";
import SaveBar from "@/components/SaveBar.vue";
import SettingRow from "@/components/SettingRow.vue";
import { displayStatus, useAdminStore, validateMachine, type Machine, type MachineConfig } from "@/stores/admin";
import MachineForm from "./MachineForm.vue";
import MachineStatusPill from "./MachineStatusPill.vue";
import { formatDate, formatMoney } from "@/utils/format";

const props = defineProps<{ machine: Machine }>();

const admin = useAdminStore();

const owner = computed(() => (!props.machine.forSale && props.machine.ownerId ? props.machine.ownerName ?? "a player" : undefined));

// The owner field is for transferring, so it starts empty instead of showing the current owner's ID
function configOf(machine: Machine): MachineConfig {
    const { name, model, location, forSale, price, capacity, products } = machine;
    return JSON.parse(JSON.stringify({ name, model, location, ownerId: "", forSale, price, capacity, products }));
};

const draft = ref<MachineConfig>(configOf(props.machine));

// Left empty, the machine stays with its current owner
const submitted = computed<MachineConfig>(() => ({
    ...draft.value,
    ownerId: draft.value.ownerId.trim() || (owner.value && !draft.value.forSale ? props.machine.ownerId : ""),
}));

const dirty = computed(() => JSON.stringify(draft.value) !== JSON.stringify(configOf(props.machine)));
const error = computed(() => validateMachine(submitted.value));

function reset() {
    draft.value = configOf(props.machine);
};

async function save() {
    if (error.value) return;

    draft.value.name = draft.value.name.trim();

    const response = await admin.updateMachine(props.machine.id, submitted.value);
    if (response.success) reset();
};

const confirm = ref<"delete" | "reset">();
const confirmError = ref<string>();
const confirming = ref(false);

async function runConfirm() {
    confirming.value = true;
    confirmError.value = undefined;

    try {
        const response = confirm.value === "delete"
            ? await admin.deleteMachine(props.machine.id)
            : await admin.resetBalance(props.machine.id);

        if (response.success) {
            confirm.value = undefined;
        } else {
            confirmError.value = response.error ?? "Something went wrong.";
        }
    } finally {
        confirming.value = false;
    }
};
</script>
