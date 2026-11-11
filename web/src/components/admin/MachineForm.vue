<template>
    <div class="flex flex-col gap-3">
        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                <Store class="size-4 text-text-muted" /> {{ t("admin.form.details") }}
            </h3>
            <label class="grid gap-1.5 text-sm text-text-muted">
                {{ t("admin.form.name") }}
                <Inputs :model-value="config.name" :placeholder="t('admin.form.name_placeholder')" @update:model-value="config.name = String($event ?? '')" />
            </label>
            <SelectMenu v-model="modelChoice" :label="t('admin.form.prop_model')" :options="modelOptions" />
            <SelectMenu v-if="modelChoice === CUSTOM" v-model="config.model" :label="t('admin.form.machine_type')" :options="customModelOptions" />
        </section>

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <div class="flex items-center justify-between">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <MapPin class="size-4 text-text-muted" /> {{ t("admin.form.location") }}
                </h3>
                <Button variant="outline" size="sm" :disabled="placing" @click="setPosition">
                    <Move3d class="size-3.5" />
                    {{ placing ? t("admin.form.placing") : t("admin.form.set_position") }}
                </Button>
            </div>
            <label class="grid gap-1.5 text-sm text-text-muted">
                {{ t("admin.form.area") }}
                <Inputs
                    :model-value="config.location.label"
                    :placeholder="t('admin.form.area_placeholder')"
                    @update:model-value="config.location.label = String($event ?? '')"
                />
            </label>
            <p v-if="placeError" class="flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                {{ placeError }}
            </p>
            <p v-else-if="!hasPosition" class="text-xs text-text-faint">{{ t("admin.form.no_position") }}</p>
            <p v-else class="text-xs tabular-nums text-text-muted">
                {{ config.location.x.toFixed(2) }}, {{ config.location.y.toFixed(2) }}, {{ config.location.z.toFixed(2) }}
                · {{ config.location.heading.toFixed(0) }}°
            </p>
        </section>

        <!-- On a machine someone owns, any change here takes it away from them -->
        <section
            class="flex flex-col gap-4 rounded-2xl border bg-bg-surface p-4"
            :class="owner ? 'border-danger/30' : 'border-border'"
        >
            <div class="flex flex-col gap-1">
                <h3 class="flex items-center gap-2 text-sm font-semibold" :class="owner ? 'text-danger' : 'text-text-primary'">
                    <TriangleAlert v-if="owner" class="size-4" />
                    <Users v-else class="size-4 text-text-muted" />
                    {{ t("admin.form.ownership") }}
                </h3>
                <p v-if="owner" class="text-xs text-text-faint">
                    <LocaleText :text="t('admin.form.owned_warning')">
                        <template #p0><b class="font-medium text-text-primary">{{ owner }}</b></template>
                    </LocaleText>
                </p>
            </div>
            <SettingRow :label="t('admin.form.for_sale')" :description="t('admin.form.for_sale_description')">
                <Switch v-model="config.forSale" />
            </SettingRow>
            <div class="grid grid-cols-2 gap-3">
                <!-- On an owned machine the field starts empty and only filling it in transfers the machine -->
                <label class="grid gap-1.5 text-sm text-text-muted">
                    {{ owner ? t("admin.form.transfer_to") : t("admin.form.owner_id") }}
                    <Inputs
                        :model-value="config.ownerId"
                        :disabled="config.forSale"
                        :placeholder="owner ? t('admin.form.transfer_placeholder') : t('admin.form.owner_placeholder')"
                        @update:model-value="config.ownerId = String($event ?? '')"
                    />
                </label>
                <label class="grid gap-1.5 text-sm text-text-muted">
                    {{ t("admin.form.price", currencySymbol()) }}
                    <Inputs :model-value="config.price" type="number" :min="0" @update:model-value="config.price = toNumber($event, 0)" />
                </label>
            </div>
        </section>

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <div class="flex items-center justify-between">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <ShoppingBag class="size-4 text-text-muted" /> {{ t("admin.form.products") }}
                    <span class="text-xs font-normal text-text-faint">{{ t("admin.form.selected", config.products.length) }}</span>
                </h3>
                <div class="flex items-center gap-3 text-xs">
                    <button type="button" class="text-text-faint transition-colors hover:text-text-primary" @click="config.products = admin.products.map((product) => product.id)">
                        {{ t("admin.form.select_all") }}
                    </button>
                    <button type="button" class="text-text-faint transition-colors hover:text-text-primary" @click="config.products = []">
                        {{ t("admin.form.clear") }}
                    </button>
                </div>
            </div>
            <div class="grid grid-cols-3 gap-2">
                <!-- Checkbox renders its own <label>, so the card is a div and the checkbox stops the click from toggling twice -->
                <div
                    v-for="product in admin.products"
                    :key="product.id"
                    :class="[
                        'flex cursor-pointer items-center gap-3 rounded-lg border p-2 transition-colors',
                        config.products.includes(product.id) ? 'border-text-faint bg-bg-muted' : 'border-border hover:bg-bg-muted/30',
                    ]"
                    @click="toggleProduct(product.id, !config.products.includes(product.id))"
                >
                    <ProductThumb :product="product" />
                    <span class="min-w-0 flex-1 leading-tight">
                        <span class="block truncate text-sm font-medium text-text-primary">{{ product.name }}</span>
                        <span class="block text-xs capitalize text-text-faint">{{ product.category }}</span>
                    </span>
                    <span @click.stop>
                        <Checkbox
                            :model-value="config.products.includes(product.id)"
                            :aria-label="t('admin.form.sell_product', product.name)"
                            @update:model-value="toggleProduct(product.id, $event)"
                        />
                    </span>
                </div>
            </div>
        </section>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CircleAlert, MapPin, Move3d, ShoppingBag, Store, TriangleAlert, Users } from "@lucide/vue";
import { Button, Checkbox, Inputs, SelectMenu, Switch } from "@vezironi/veyra-ui";
import LocaleText from "@/components/LocaleText.vue";
import ProductThumb from "@/components/ProductThumb.vue";
import SettingRow from "@/components/SettingRow.vue";
import { customMachineModels, machineModels, useAdminStore, type MachineConfig } from "@/stores/admin";
import { usePlacementStore } from "@/stores/placement";
import { currencySymbol } from "@/utils/format";
import { t } from "@/utils/locale";

const config = defineModel<MachineConfig>({ required: true });

const props = defineProps<{
    // Name of the player the machine belongs to right now, when editing an owned machine
    owner?: string;
    // The machine being edited: its position can only be changed next to it
    machineId?: string;
}>();

const admin = useAdminStore();

// "Custom Vending Machine" stands for every custom model; the type menu under it picks which one is saved
const CUSTOM = "custom";
const isCustom = computed(() => customMachineModels.some((model) => model.value === config.value.model));

// Only offered while olentrix_vending runs; a machine that already is custom keeps it, so its form still shows its model
const modelOptions = computed(() => (admin.customMachines || isCustom.value
    ? [...machineModels, { label: "admin.models.custom", value: CUSTOM }]
    : machineModels).map((model) => ({ label: t(model.label), value: model.value })));

const customModelOptions = computed(() => customMachineModels.map((model) => ({ label: t(model.label), value: model.value })));

const modelChoice = computed({
    get: () => (isCustom.value ? CUSTOM : config.value.model),
    set: (value: string) => {
        config.value.model = value === CUSTOM ? customMachineModels[0]!.value : value;
    },
});

const placement = usePlacementStore();
const placing = ref(false);
const placeError = ref<string>();

const hasPosition = computed(() => !!(config.value.location.x || config.value.location.y || config.value.location.z));

function toNumber(value: string | number | undefined, min = -Infinity): number {
    const number = Number(value);
    return Number.isFinite(number) ? Math.max(min, number) : 0;
};

function toggleProduct(productId: string, checked: boolean) {
    config.value.products = checked
        ? [...config.value.products, productId]
        : config.value.products.filter((id) => id !== productId);
};

// The admin page hides while the ghost machine is placed and comes back with the confirmed position
async function setPosition() {
    placing.value = true;
    placeError.value = undefined;

    try {
        const response = await placement.start(config.value.model, props.machineId);

        if (!response.success) {
            placeError.value = response.error;
        } else if (response.data) {
            const { label, x, y, z, heading } = response.data;
            const round = (value: number) => Math.round(value * 100) / 100;

            config.value.location = {
                label: config.value.location.label || label,
                x: round(x),
                y: round(y),
                z: round(z),
                heading: round(heading),
            };
        }
    } finally {
        placing.value = false;
    }
};
</script>
