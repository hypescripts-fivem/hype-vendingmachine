<template>
    <div class="flex flex-col gap-3">
        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                <Store class="size-4 text-text-muted" /> Details
            </h3>
            <label class="grid gap-1.5 text-sm text-text-muted">
                Machine name
                <Inputs :model-value="config.name" placeholder="e.g. Legion Square #2" @update:model-value="config.name = String($event ?? '')" />
            </label>
            <SelectMenu v-model="config.model" label="Prop model" :options="machineModels" />
        </section>

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <div class="flex items-center justify-between">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <MapPin class="size-4 text-text-muted" /> Location
                </h3>
                <Button variant="outline" size="sm" :disabled="locating" @click="useMyPosition">
                    <Crosshair class="size-3.5" />
                    {{ locating ? "Locating..." : "Use my position" }}
                </Button>
            </div>
            <label class="grid gap-1.5 text-sm text-text-muted">
                Area label
                <Inputs
                    :model-value="config.location.label"
                    placeholder="e.g. Legion Square"
                    @update:model-value="config.location.label = String($event ?? '')"
                />
            </label>
            <div class="grid grid-cols-4 gap-2">
                <label v-for="axis in axes" :key="axis" class="grid gap-1 text-xs uppercase text-text-faint">
                    {{ axis }}
                    <Inputs
                        :model-value="config.location[axis]"
                        type="number"
                        size="sm"
                        @update:model-value="config.location[axis] = toNumber($event)"
                    />
                </label>
            </div>
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
                    Ownership
                </h3>
                <p v-if="owner" class="text-xs text-text-faint">
                    Owned by <b class="font-medium text-text-primary">{{ owner }}</b>. Entering a new owner or putting it up for sale takes it away from them.
                </p>
            </div>
            <SettingRow label="For sale" description="Players can buy this machine instead of it having an owner.">
                <Switch v-model="config.forSale" />
            </SettingRow>
            <div class="grid grid-cols-2 gap-3">
                <!-- On an owned machine the field starts empty and only filling it in transfers the machine -->
                <label class="grid gap-1.5 text-sm text-text-muted">
                    {{ owner ? "Transfer to" : "Owner ID" }}
                    <Inputs
                        :model-value="config.ownerId"
                        :disabled="config.forSale"
                        :placeholder="owner ? 'Server or citizen ID of the new owner' : 'Leave empty to put it up for sale'"
                        @update:model-value="config.ownerId = String($event ?? '')"
                    />
                </label>
                <label class="grid gap-1.5 text-sm text-text-muted">
                    Sale price ({{ currencySymbol() }})
                    <Inputs :model-value="config.price" type="number" :min="0" @update:model-value="config.price = toNumber($event, 0)" />
                </label>
            </div>
        </section>

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <div class="flex items-center justify-between">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <ShoppingBag class="size-4 text-text-muted" /> Products
                    <span class="text-xs font-normal text-text-faint">{{ config.products.length }} selected</span>
                </h3>
                <div class="flex items-center gap-3 text-xs">
                    <button type="button" class="text-text-faint transition-colors hover:text-text-primary" @click="config.products = admin.products.map((product) => product.id)">
                        Select all
                    </button>
                    <button type="button" class="text-text-faint transition-colors hover:text-text-primary" @click="config.products = []">
                        Clear
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
                            :aria-label="`Sell ${product.name}`"
                            @update:model-value="toggleProduct(product.id, $event)"
                        />
                    </span>
                </div>
            </div>
        </section>
    </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { Crosshair, MapPin, ShoppingBag, Store, TriangleAlert, Users } from "@lucide/vue";
import { Button, Checkbox, Inputs, SelectMenu, Switch } from "@vezironi/veyra-ui";
import ProductThumb from "@/components/ProductThumb.vue";
import SettingRow from "@/components/SettingRow.vue";
import { machineModels, useAdminStore, type MachineConfig } from "@/stores/admin";
import { currencySymbol } from "@/utils/format";

const config = defineModel<MachineConfig>({ required: true });

defineProps<{
    // Name of the player the machine belongs to right now, when editing an owned machine
    owner?: string;
}>();

const admin = useAdminStore();

const axes = ["x", "y", "z", "heading"] as const;
const locating = ref(false);

function toNumber(value: string | number | undefined, min = -Infinity): number {
    const number = Number(value);
    return Number.isFinite(number) ? Math.max(min, number) : 0;
};

function toggleProduct(productId: string, checked: boolean) {
    config.value.products = checked
        ? [...config.value.products, productId]
        : config.value.products.filter((id) => id !== productId);
};

async function useMyPosition() {
    locating.value = true;

    try {
        const response = await admin.getPosition();

        if (response.success && response.data) {
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
        locating.value = false;
    }
};
</script>
