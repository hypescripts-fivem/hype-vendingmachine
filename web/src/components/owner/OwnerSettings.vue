<template>
    <div class="flex flex-col gap-3">
        <SaveBar :dirty="dirty" :error="error" :saving="owner.saving" @reset="reset" @save="save" />

        <div class="flex flex-col gap-3">
            <section v-if="owner.can('settings.general')" class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Store class="size-4 text-text-muted" /> General
                </h3>
                <label class="grid gap-1.5 text-sm text-text-muted">
                    Machine name
                    <Inputs
                        :model-value="draft.name"
                        placeholder="Machine name"
                        @update:model-value="draft.name = String($event ?? '')"
                    />
                </label>
                <label class="grid gap-1.5 text-sm text-text-muted">
                    Description
                    <Textarea v-model="draft.description" :rows="2" :maxlength="120" :resizable="false" placeholder="Shown to customers" />
                </label>
                <SettingRow label="Open for customers" description="Closed machines can't be used by other players.">
                    <Switch v-model="draft.open" />
                </SettingRow>
            </section>

            <section v-if="owner.can('settings.hours')" class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Clock class="size-4 text-text-muted" /> Operating hours
                </h3>
                <SettingRow label="Use a schedule" description="Open and close automatically by in-game time.">
                    <Switch v-model="draft.schedule.enabled" />
                </SettingRow>
                <div class="grid grid-cols-2 gap-3">
                    <TimePicker v-model="draft.schedule.opensAt" label="Opens at" :disabled="!draft.schedule.enabled" />
                    <TimePicker v-model="draft.schedule.closesAt" label="Closes at" :disabled="!draft.schedule.enabled" />
                </div>
                <p class="text-xs text-text-faint">
                    {{ draft.schedule.enabled
                        ? `Open from ${draft.schedule.opensAt} to ${draft.schedule.closesAt}.`
                        : "The open switch alone controls availability." }}
                </p>
            </section>

            <section v-if="owner.can('settings.stock')" class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Package class="size-4 text-text-muted" /> Stock & alerts
                </h3>
                <Slider v-model="draft.lowStockThreshold" :min="1" :max="20" label="Low stock threshold" show-value />
                <SettingRow label="Auto restock" description="Order up to capacity when a product hits the threshold.">
                    <Switch v-model="draft.autoRestock" />
                </SettingRow>
                <SettingRow label="Low stock alerts" description="Get a notification when stock runs low.">
                    <Switch v-model="draft.notifyLowStock" />
                </SettingRow>
                <SettingRow label="Sale notifications" description="Get a notification for every purchase.">
                    <Switch v-model="draft.notifySales" />
                </SettingRow>
            </section>

            <section v-if="owner.can('settings.payments')" class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <CreditCard class="size-4 text-text-muted" /> Payments
                </h3>
                <SettingRow label="Cash" description="Customers pay with cash on hand.">
                    <Checkbox v-model="draft.payments.cash" aria-label="Accept cash" />
                </SettingRow>
                <SettingRow label="Bank card" description="Customers pay from their bank account.">
                    <Checkbox v-model="draft.payments.bank" aria-label="Accept bank card" />
                </SettingRow>
            </section>

            <!-- Selling and transferring are never delegated to staff -->
            <section v-if="owner.access.owner" class="flex flex-col gap-4 rounded-2xl border border-danger/30 bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-danger">
                    <TriangleAlert class="size-4" /> Danger zone
                </h3>
                <SettingRow label="Transfer ownership" description="Give this machine to another player. You lose all access.">
                    <Button variant="outline" size="sm" @click="openModal('transfer')">Transfer</Button>
                </SettingRow>
                <Separator />
                <SettingRow label="Sell machine" description="Sell the machine back. Stock and orders in progress are lost.">
                    <Button variant="danger" size="sm" @click="openModal('sell')">Sell machine</Button>
                </SettingRow>
            </section>
        </div>

        <Modal
            v-if="modal"
            :title="modal === 'sell' ? 'Sell machine' : 'Transfer ownership'"
            :icon="TriangleAlert"
            @close="modal = undefined"
        >
            <div class="flex flex-col gap-3 px-5 py-4 text-sm text-text-muted">
                <template v-if="modal === 'sell'">
                    <p>This permanently sells <b class="text-text-primary">{{ owner.settings.name }}</b>. This can't be undone.</p>
                </template>
                <template v-else>
                    <p>Enter the server ID of the player who will own this machine.</p>
                    <Inputs v-model="playerId" type="number" :min="1" placeholder="Player ID" />
                </template>
                <p v-if="modalError" class="flex items-center gap-1.5 text-xs text-danger">
                    <CircleAlert class="size-3.5 shrink-0" />
                    {{ modalError }}
                </p>
            </div>
            <template #footer>
                <Button variant="outline" size="sm" @click="modal = undefined">Cancel</Button>
                <Button variant="danger" size="sm" :disabled="!canConfirm || confirming" @click="confirmModal">
                    {{ confirming ? "Working..." : modal === "sell" ? "Sell machine" : "Transfer" }}
                </Button>
            </template>
        </Modal>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CircleAlert, Clock, CreditCard, Package, Store, TriangleAlert } from "@lucide/vue";
import { Button, Checkbox, Inputs, Modal, Separator, Slider, Switch, Textarea } from "@vezironi/veyra-ui";
import { useAppStore } from "@/stores/app";
import { useOwnerStore, type OwnerSettings } from "@/stores/owner";
import SaveBar from "@/components/SaveBar.vue";
import SettingRow from "@/components/SettingRow.vue";
import TimePicker from "@/components/TimePicker.vue";

const app = useAppStore();
const owner = useOwnerStore();

const clone = (settings: OwnerSettings): OwnerSettings => JSON.parse(JSON.stringify(settings));

const draft = ref<OwnerSettings>(clone(owner.settings));

const dirty = computed(() => JSON.stringify(draft.value) !== JSON.stringify(owner.settings));

const error = computed(() => {
    if (!draft.value.name.trim()) return "Machine name can't be empty.";
    if (!draft.value.payments.cash && !draft.value.payments.bank) return "Accept at least one payment method.";
    if (draft.value.schedule.enabled && draft.value.schedule.opensAt === draft.value.schedule.closesAt) {
        return "Opening and closing times can't be the same.";
    }
    return undefined;
});

function reset() {
    draft.value = clone(owner.settings);
};

async function save() {
    if (error.value) return;

    draft.value.name = draft.value.name.trim();

    const response = await owner.saveSettings(draft.value);
    if (response?.success) reset();
};

const modal = ref<"sell" | "transfer">();
const playerId = ref<string | number | undefined>();
const modalError = ref<string>();
const confirming = ref(false);

const canConfirm = computed(() => modal.value === "sell" || Number(playerId.value) > 0);

function openModal(type: "sell" | "transfer") {
    modal.value = type;
    playerId.value = undefined;
    modalError.value = undefined;
};

async function confirmModal() {
    confirming.value = true;
    modalError.value = undefined;

    try {
        const response = modal.value === "sell"
            ? await owner.sellMachine()
            : await owner.transferOwnership(Math.floor(Number(playerId.value)));

        if (response.success) {
            modal.value = undefined;
            // The machine isn't theirs anymore, so the panel has nothing left to show
            app.close();
        } else {
            modalError.value = response.error ?? "Something went wrong.";
        }
    } finally {
        confirming.value = false;
    }
};
</script>
