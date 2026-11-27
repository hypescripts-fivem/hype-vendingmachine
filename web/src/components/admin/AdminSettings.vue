<template>
    <div class="flex flex-col gap-3">
        <SaveBar :dirty="dirty" :saving="admin.saving" @reset="reset" @save="save" />

        <div class="flex flex-col gap-3">
            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Coins class="size-4 text-text-muted" /> {{ t("admin.settings.economy") }}
                </h3>
                <Slider v-model="draft.wholesaleMultiplier" :min="0.5" :max="2" :step="0.1" :label="t('admin.settings.wholesale_multiplier')" show-value />
                <p class="-mt-2 text-xs text-text-faint">
                    {{ t("admin.settings.wholesale_hint", Math.round(draft.wholesaleMultiplier * 100)) }}
                </p>
                <Slider v-model="draft.salesTax" :min="0" :max="30" :label="t('admin.settings.sales_tax')" show-value />
                <SettingRow :label="t('admin.settings.max_machines')" :description="t('admin.settings.max_machines_description')">
                    <div class="w-24">
                        <Inputs
                            :model-value="draft.maxMachinesPerPlayer"
                            type="number"
                            size="sm"
                            :min="1"
                            @update:model-value="draft.maxMachinesPerPlayer = toInt($event, 1)"
                        />
                    </div>
                </SettingRow>
            </section>

            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Truck class="size-4 text-text-muted" /> {{ t("admin.settings.stock_orders") }}
                </h3>
                <Slider v-model="draft.deliveryMinutes" :min="1" :max="30" :label="t('admin.settings.delivery_minutes')" show-value />
                <p class="-mt-2 text-xs text-text-faint">
                    {{ t("admin.settings.delivery_hint", draft.deliveryMinutes * 3) }}
                </p>
            </section>

            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <SlidersHorizontal class="size-4 text-text-muted" /> {{ t("admin.settings.defaults") }}
                </h3>
                <Slider v-model="draft.defaultCapacity" :min="10" :max="100" :step="5" :label="t('admin.settings.default_capacity')" show-value />
                <SettingRow :label="t('admin.settings.default_price')" :description="t('admin.settings.default_price_description')">
                    <div class="w-32">
                        <Inputs
                            :model-value="draft.defaultPrice"
                            type="number"
                            size="sm"
                            :min="0"
                            @update:model-value="draft.defaultPrice = toInt($event, 0)"
                        />
                    </div>
                </SettingRow>
                <SettingRow :label="t('admin.settings.allow_purchase')" :description="t('admin.settings.allow_purchase_description')">
                    <Switch v-model="draft.allowPlayerPurchase" />
                </SettingRow>
            </section>

            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Webhook class="size-4 text-text-muted" /> {{ t("admin.settings.logging") }}
                </h3>
                <SettingRow :label="t('admin.settings.log_purchases')" :description="t('admin.settings.log_purchases_description')">
                    <Switch v-model="draft.logPurchases" />
                </SettingRow>
                <SettingRow :label="t('admin.settings.log_admin_actions')" :description="t('admin.settings.log_admin_actions_description')">
                    <Switch v-model="draft.logAdminActions" />
                </SettingRow>
            </section>

            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Share2 class="size-4 text-text-muted" /> {{ t("admin.settings.share") }}
                </h3>
                <SettingRow
                    :label="t('admin.settings.export')"
                    :description="t('admin.settings.export_description')"
                >
                    <Button variant="outline" size="sm" :disabled="!admin.machines.length" @click="exporting = true">
                        <Download class="size-3.5" />
                        {{ t("admin.settings.export_button") }}
                    </Button>
                </SettingRow>
            </section>
        </div>

        <MachineExportModal v-if="exporting" @close="exporting = false" />
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { Coins, Download, Share2, SlidersHorizontal, Truck, Webhook } from "@lucide/vue";
import { Button, Inputs, Slider, Switch } from "@vezironi/veyra-ui";
import SaveBar from "@/components/SaveBar.vue";
import SettingRow from "@/components/SettingRow.vue";
import { useAdminStore, type AdminSettings } from "@/stores/admin";
import MachineExportModal from "./MachineExportModal.vue";
import { t } from "@/utils/locale";

const admin = useAdminStore();

const clone = (settings: AdminSettings): AdminSettings => JSON.parse(JSON.stringify(settings));

const draft = ref<AdminSettings>(clone(admin.settings));
const exporting = ref(false);

const dirty = computed(() => JSON.stringify(draft.value) !== JSON.stringify(admin.settings));

function toInt(value: string | number | undefined, min: number): number {
    const number = Math.floor(Number(value));
    return Number.isFinite(number) ? Math.max(min, number) : min;
};

function reset() {
    draft.value = clone(admin.settings);
};

async function save() {
    const response = await admin.saveSettings(draft.value);
    if (response.success) reset();
};
</script>
