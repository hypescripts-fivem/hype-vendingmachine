<template>
    <!-- Owners can't pick products themselves; an admin sets them on the machine, so there's no button here -->
    <EmptyState
        title="No products yet"
        description="This machine has nothing to sell. Once an admin adds products to it, sales, stock and orders show up here."
        :icon="PackageOpen"
        class="h-full"
    />
</template>

<script setup lang="ts">
import { PackageOpen } from "@lucide/vue";
import { EmptyState } from "@vezironi/veyra-ui";
</script>
