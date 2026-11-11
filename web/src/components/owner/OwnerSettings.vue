<template>
    <div class="flex flex-col gap-3">
        <SaveBar :dirty="dirty" :error="error" :saving="owner.saving" @reset="reset" @save="save" />

        <div class="flex flex-col gap-3">
            <section v-if="owner.can('settings.general')" class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Store class="size-4 text-text-muted" /> {{ t("owner.settings.general") }}
                </h3>
                <label class="grid gap-1.5 text-sm text-text-muted">
                    {{ t("owner.settings.name") }}
                    <Inputs
                        :model-value="draft.name"
                        :placeholder="t('owner.settings.name')"
                        @update:model-value="draft.name = String($event ?? '')"
                    />
                </label>
                <label class="grid gap-1.5 text-sm text-text-muted">
                    {{ t("owner.settings.description") }}
                    <Textarea v-model="draft.description" :rows="2" :maxlength="120" :resizable="false" :placeholder="t('owner.settings.description_placeholder')" />
                </label>
                <SettingRow :label="t('owner.settings.open')" :description="t('owner.settings.open_description')">
                    <Switch v-model="draft.open" />
                </SettingRow>
            </section>

            <section v-if="owner.can('settings.hours')" class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Clock class="size-4 text-text-muted" /> {{ t("owner.settings.hours") }}
                </h3>
                <SettingRow :label="t('owner.settings.schedule')" :description="t('owner.settings.schedule_description')">
                    <Switch v-model="draft.schedule.enabled" />
                </SettingRow>
                <div class="grid grid-cols-2 gap-3">
                    <TimePicker v-model="draft.schedule.opensAt" :label="t('owner.settings.opens_at')" :disabled="!draft.schedule.enabled" />
                    <TimePicker v-model="draft.schedule.closesAt" :label="t('owner.settings.closes_at')" :disabled="!draft.schedule.enabled" />
                </div>
                <p class="text-xs text-text-faint">
                    {{ draft.schedule.enabled
                        ? t("owner.settings.schedule_on", draft.schedule.opensAt, draft.schedule.closesAt)
                        : t("owner.settings.schedule_off") }}
                </p>
            </section>

            <section v-if="owner.can('settings.stock')" class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Package class="size-4 text-text-muted" /> {{ t("owner.settings.stock") }}
                </h3>
                <Slider v-model="draft.lowStockThreshold" :min="1" :max="20" :label="t('owner.settings.low_stock_threshold')" show-value />
                <SettingRow :label="t('owner.settings.auto_restock')" :description="t('owner.settings.auto_restock_description')">
                    <Switch v-model="draft.autoRestock" />
                </SettingRow>
                <SettingRow :label="t('owner.settings.low_stock_alerts')" :description="t('owner.settings.low_stock_alerts_description')">
                    <Switch v-model="draft.notifyLowStock" />
                </SettingRow>
                <SettingRow :label="t('owner.settings.sale_notifications')" :description="t('owner.settings.sale_notifications_description')">
                    <Switch v-model="draft.notifySales" />
                </SettingRow>
            </section>

            <section v-if="owner.can('settings.payments')" class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <CreditCard class="size-4 text-text-muted" /> {{ t("owner.settings.payments") }}
                </h3>
                <SettingRow :label="t('owner.settings.cash')" :description="t('owner.settings.cash_description')">
                    <Checkbox v-model="draft.payments.cash" :aria-label="t('owner.settings.accept_cash')" />
                </SettingRow>
                <SettingRow :label="t('owner.settings.bank')" :description="t('owner.settings.bank_description')">
                    <Checkbox v-model="draft.payments.bank" :aria-label="t('owner.settings.accept_bank')" />
                </SettingRow>
            </section>

            <!-- Selling and transferring are never delegated to staff -->
            <section v-if="owner.access.owner" class="flex flex-col gap-4 rounded-2xl border border-danger/30 bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-danger">
                    <TriangleAlert class="size-4" /> {{ t("owner.settings.danger_zone") }}
                </h3>
                <SettingRow :label="t('owner.settings.transfer_title')" :description="t('owner.settings.transfer_description')">
                    <Button variant="outline" size="sm" @click="openModal('transfer')">{{ t("owner.settings.transfer") }}</Button>
                </SettingRow>
                <Separator />
                <SettingRow :label="t('owner.settings.sell')" :description="t('owner.settings.sell_description')">
                    <Button variant="danger" size="sm" @click="openModal('sell')">{{ t("owner.settings.sell") }}</Button>
                </SettingRow>
            </section>
        </div>

        <Modal
            v-if="modal"
            :title="modal === 'sell' ? t('owner.settings.sell') : t('owner.settings.transfer_title')"
            :icon="TriangleAlert"
            @close="modal = undefined"
        >
            <div class="flex flex-col gap-3 px-5 py-4 text-sm text-text-muted">
                <template v-if="modal === 'sell'">
                    <p>
                        <LocaleText :text="t('owner.settings.sell_confirm')">
                            <template #p0><b class="text-text-primary">{{ owner.settings.name }}</b></template>
                        </LocaleText>
                    </p>
                </template>
                <template v-else>
                    <p>{{ t("owner.settings.transfer_prompt") }}</p>
                    <Inputs v-model="playerId" type="number" :min="1" :placeholder="t('owner.common.player_id')" />
                </template>
                <p v-if="modalError" class="flex items-center gap-1.5 text-xs text-danger">
                    <CircleAlert class="size-3.5 shrink-0" />
                    {{ modalError }}
                </p>
            </div>
            <template #footer>
                <Button variant="outline" size="sm" @click="modal = undefined">{{ t("owner.common.cancel") }}</Button>
                <Button variant="danger" size="sm" :disabled="!canConfirm || confirming" @click="confirmModal">
                    {{ confirming ? t("owner.common.working") : modal === "sell" ? t("owner.settings.sell") : t("owner.settings.transfer") }}
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
import LocaleText from "@/components/LocaleText.vue";
import SaveBar from "@/components/SaveBar.vue";
import SettingRow from "@/components/SettingRow.vue";
import TimePicker from "@/components/TimePicker.vue";
import { t } from "@/utils/locale";

const app = useAppStore();
const owner = useOwnerStore();

const clone = (settings: OwnerSettings): OwnerSettings => JSON.parse(JSON.stringify(settings));

const draft = ref<OwnerSettings>(clone(owner.settings));

const dirty = computed(() => JSON.stringify(draft.value) !== JSON.stringify(owner.settings));

const error = computed(() => {
    if (!draft.value.name.trim()) return t("owner.settings.name_empty");
    if (!draft.value.payments.cash && !draft.value.payments.bank) return t("owner.settings.payment_required");
    if (draft.value.schedule.enabled && draft.value.schedule.opensAt === draft.value.schedule.closesAt) {
        return t("owner.settings.same_times");
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
            modalError.value = response.error ?? t("owner.common.error");
        }
    } finally {
        confirming.value = false;
    }
};
</script>
