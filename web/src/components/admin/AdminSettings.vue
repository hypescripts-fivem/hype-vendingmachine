<template>
    <div class="flex flex-col gap-3">
        <SaveBar :dirty="dirty" :error="error" :saving="admin.saving" @reset="reset" @save="save" />

        <div class="flex flex-col gap-3">
            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Coins class="size-4 text-text-muted" /> Economy
                </h3>
                <Slider v-model="draft.wholesaleMultiplier" :min="0.5" :max="2" :step="0.1" label="Wholesale price multiplier" show-value />
                <p class="-mt-2 text-xs text-text-faint">
                    Owners pay {{ Math.round(draft.wholesaleMultiplier * 100) }}% of the base supplier price.
                </p>
                <Slider v-model="draft.salesTax" :min="0" :max="30" label="Sales tax (%)" show-value />
                <SettingRow label="Machines per player" description="How many machines one player can own.">
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
                    <Truck class="size-4 text-text-muted" /> Stock orders
                </h3>
                <Slider v-model="draft.deliveryMinutes" :min="1" :max="30" label="Minutes per order stage" show-value />
                <p class="-mt-2 text-xs text-text-faint">
                    An order takes about {{ draft.deliveryMinutes * 3 }} minutes from preparing to delivered.
                </p>
            </section>

            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <SlidersHorizontal class="size-4 text-text-muted" /> New machine defaults
                </h3>
                <Slider v-model="draft.defaultCapacity" :min="10" :max="100" :step="5" label="Capacity per product" show-value />
                <SettingRow label="Default sale price" description="Used when creating a machine.">
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
                <SettingRow label="Players can buy machines" description="Machines marked for sale can be purchased in game.">
                    <Switch v-model="draft.allowPlayerPurchase" />
                </SettingRow>
            </section>

            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Webhook class="size-4 text-text-muted" /> Logging
                </h3>
                <label class="grid gap-1.5 text-sm text-text-muted">
                    Discord webhook URL
                    <Inputs
                        :model-value="draft.webhook"
                        placeholder="https://discord.com/api/webhooks/..."
                        @update:model-value="draft.webhook = String($event ?? '').trim()"
                    />
                </label>
                <SettingRow label="Log purchases" description="Send every machine purchase to the webhook.">
                    <Switch v-model="draft.logPurchases" />
                </SettingRow>
                <SettingRow label="Log admin actions" description="Creating, editing and deleting machines.">
                    <Switch v-model="draft.logAdminActions" />
                </SettingRow>
            </section>

            <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Share2 class="size-4 text-text-muted" /> Share machines
                </h3>
                <SettingRow
                    label="Export machines"
                    description="Names, models, locations, prices and products as JSON. Import it from the Machines page on another server."
                >
                    <Button variant="outline" size="sm" :disabled="!admin.machines.length" @click="exporting = true">
                        <Download class="size-3.5" />
                        Export
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

const admin = useAdminStore();

const clone = (settings: AdminSettings): AdminSettings => JSON.parse(JSON.stringify(settings));

const draft = ref<AdminSettings>(clone(admin.settings));
const exporting = ref(false);

const dirty = computed(() => JSON.stringify(draft.value) !== JSON.stringify(admin.settings));

const error = computed(() => {
    const { webhook, logPurchases, logAdminActions } = draft.value;

    if (webhook && !/^https:\/\/(\w+\.)?discord(app)?\.com\/api\/webhooks\//.test(webhook)) {
        return "The webhook must be a Discord webhook URL.";
    }
    if (!webhook && (logPurchases || logAdminActions)) {
        return "Add a webhook URL or turn logging off.";
    }
    return undefined;
});

function toInt(value: string | number | undefined, min: number): number {
    const number = Math.floor(Number(value));
    return Number.isFinite(number) ? Math.max(min, number) : min;
};

function reset() {
    draft.value = clone(admin.settings);
};

async function save() {
    if (error.value) return;

    const response = await admin.saveSettings(draft.value);
    if (response.success) reset();
};
</script>
