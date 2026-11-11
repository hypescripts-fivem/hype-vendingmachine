<template>
    <!-- Owners can't pick products themselves; an admin sets them on the machine, so there's no button here -->
    <EmptyState
        :title="t('owner.no_products.title')"
        :description="t('owner.no_products.description')"
        :icon="PackageOpen"
        class="h-full"
    />
</template>

<script setup lang="ts">
import { PackageOpen } from "@lucide/vue";
import { EmptyState } from "@vezironi/veyra-ui";
import { t } from "@/utils/locale";
</script>
