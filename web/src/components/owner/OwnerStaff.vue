<template>
    <div class="flex flex-col gap-3">
        <section class="flex w-full gap-3">
            <Inputs v-model="search" type="text" :placeholder="t('owner.staff.search')" />
            <Button v-if="owner.can('staff.manage')" class="w-[200px]" variant="solid" @click="openHire">
                <UserPlus class="size-4" />
                {{ t("owner.staff.hire") }}
            </Button>
        </section>

        <DataTable v-model:sort="sort" :columns="columns" :rows="rows" :page-size="10" :empty-text="t('owner.staff.empty')">
            <template #cell="{ column, row }">
                <template v-if="row.id === OWNER_ROW || memberOf(row)">
                    <div v-if="column.key === 'name'" class="flex items-center gap-3">
                        <Avatar
                            :fallback="initials(String(row.name))"
                            size="sm"
                            badge
                            badge-tooltip
                            :badge-variant="row.online ? 'active' : 'inactive'"
                            :badge-label="row.online ? t('owner.staff.online') : t('owner.staff.offline')"
                        />
                        <span class="truncate font-medium text-text-primary">{{ row.name }}</span>
                        <Badge v-if="row.id === owner.selfId" variant="outline">{{ t("owner.staff.you") }}</Badge>
                    </div>

                    <Badge v-else-if="column.key === 'role'" :variant="row.custom ? 'outline' : 'default'">{{ row.role }}</Badge>

                    <span v-else-if="column.key === 'hiredAt'" class="tabular-nums text-text-faint">{{ row.hiredAt ? formatDate(Number(row.hiredAt)) : "—" }}</span>

                    <span v-else-if="column.key === 'lastOnline'" class="tabular-nums" :class="row.lastOnline ? 'text-text-muted' : 'text-text-faint'">
                        {{ row.id === OWNER_ROW ? (row.online ? t("owner.staff.now") : "—") : row.lastOnline ? formatDateTime(Number(row.lastOnline)) : t("owner.staff.never") }}
                    </span>

                    <!-- The owner row has no actions: the owner can't be edited or fired -->
                    <div v-else-if="column.key === 'actions' && memberOf(row) && canManage(memberOf(row)!)" class="flex items-center justify-end gap-1.5">
                        <Tooltip :content="t('owner.staff.edit_permissions')" side="top">
                            <Button variant="secondary" size="sm" class="p-2.5" :aria-label="t('owner.staff.edit_permissions')" @click="openEdit(memberOf(row)!)">
                                <Pencil class="size-3.5" />
                            </Button>
                        </Tooltip>
                        <Tooltip :content="t('owner.staff.fire')" side="top">
                            <Button variant="danger" size="sm" class="p-2.5" :aria-label="t('owner.staff.fire')" @click="openFire(memberOf(row)!)">
                                <UserMinus class="size-3.5" />
                            </Button>
                        </Tooltip>
                    </div>
                </template>
            </template>
        </DataTable>

        <Modal
            v-if="modal?.type === 'hire' || modal?.type === 'edit'"
            :title="modal.type === 'hire' ? t('owner.staff.hire_title') : t('owner.staff.edit_title')"
            :icon="modal.type === 'hire' ? UserPlus : Pencil"
            @close="modal = undefined"
        >
            <div class="flex flex-col gap-4 px-5 py-4 text-sm text-text-muted">
                <label v-if="modal.type === 'hire'" class="grid gap-1.5">
                    {{ t("owner.common.player_id") }}
                    <Inputs v-model="playerId" type="number" :min="1" :placeholder="t('owner.staff.server_id')" />
                </label>
                <p v-else>
                    <LocaleText :text="t('owner.staff.edit_description')">
                        <template #p0><b class="text-text-primary">{{ modal.member.name }}</b></template>
                        <template #p1>{{ owner.settings.name }}</template>
                    </LocaleText>
                </p>

                <SelectMenu
                    :label="t('owner.staff.role')"
                    :hint="t('owner.staff.role_hint')"
                    :options="roleOptions"
                    :model-value="custom ? 'custom' : staffRoleOf(draft) ?? 'custom'"
                    @update:model-value="applyRole"
                />

                <div v-if="custom" class="flex max-h-96 flex-col gap-3 overflow-y-auto pr-1">
                    <section
                        v-for="group in permissionGroups"
                        :key="group.section"
                        class="flex flex-col gap-3 rounded-xl border border-border p-3"
                    >
                        <header class="flex items-center justify-between gap-3">
                            <h4 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                                <component :is="group.icon" class="size-4 text-text-muted" />
                                {{ t(group.label) }}
                                <span class="text-xs font-normal tabular-nums text-text-faint">
                                    {{ group.permissions.filter((permission) => draft.includes(permission.value)).length }}/{{ group.permissions.length }}
                                </span>
                            </h4>
                            <Button
                                v-if="grantable(group).length > 1"
                                variant="outline"
                                size="sm"
                                @click="draft = toggleGroup(draft, group, !groupEnabled(group))"
                            >
                                {{ groupEnabled(group) ? t("owner.staff.none") : t("owner.staff.all") }}
                            </Button>
                        </header>
                        <SettingRow
                            v-for="permission in group.permissions"
                            :key="permission.value"
                            :label="t(permission.label)"
                            :description="t(permission.description)"
                        >
                            <Checkbox
                                :model-value="draft.includes(permission.value)"
                                :aria-label="`${t(group.label)}: ${t(permission.label)}`"
                                :disabled="!owner.can(permission.value)"
                                @update:model-value="draft = toggle(draft, [permission.value], $event)"
                            />
                        </SettingRow>
                    </section>
                </div>

                <p v-if="error" class="flex items-center gap-1.5 text-xs text-danger">
                    <CircleAlert class="size-3.5 shrink-0" />
                    {{ error }}
                </p>
                <p v-else-if="modal.type === 'hire'" class="text-xs text-text-faint">
                    {{ t("owner.staff.hire_hint") }}
                </p>
            </div>
            <template #footer>
                <Button variant="outline" size="sm" @click="modal = undefined">{{ t("owner.common.cancel") }}</Button>
                <Button size="sm" :disabled="!canConfirm || busy" @click="confirm">
                    {{ busy ? t("owner.common.working") : modal.type === "hire" ? t("owner.staff.hire") : t("owner.common.save") }}
                </Button>
            </template>
        </Modal>

        <Modal v-if="modal?.type === 'fire'" :title="t('owner.staff.fire_title')" :icon="TriangleAlert" @close="modal = undefined">
            <div class="flex flex-col gap-3 px-5 py-4 text-sm text-text-muted">
                <p>
                    <LocaleText :text="t('owner.staff.fire_description')">
                        <template #p0><b class="text-text-primary">{{ modal.member.name }}</b></template>
                        <template #p1>{{ owner.settings.name }}</template>
                    </LocaleText>
                </p>
                <p v-if="error" class="flex items-center gap-1.5 text-xs text-danger">
                    <CircleAlert class="size-3.5 shrink-0" />
                    {{ error }}
                </p>
            </div>
            <template #footer>
                <Button variant="outline" size="sm" @click="modal = undefined">{{ t("owner.common.cancel") }}</Button>
                <Button variant="danger" size="sm" :disabled="busy" @click="confirm">
                    {{ busy ? t("owner.common.working") : t("owner.staff.fire") }}
                </Button>
            </template>
        </Modal>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CircleAlert, Pencil, TriangleAlert, UserMinus, UserPlus } from "@lucide/vue";
import { Avatar, Badge, Button, Checkbox, DataTable, Inputs, Modal, SelectMenu, Tooltip, type DataTableColumn, type DataTableRow } from "@vezironi/veyra-ui";
import LocaleText from "@/components/LocaleText.vue";
import SettingRow from "@/components/SettingRow.vue";
import { permissionGroups, type PermissionGroup } from "@/components/owner/permissions";
import { staffPermissions, staffRoleOf, staffRoles, useOwnerStore, type StaffMember, type StaffPermission } from "@/stores/owner";
import { formatDate, formatDateTime } from "@/utils/format";
import { t } from "@/utils/locale";

const owner = useOwnerStore();

function toggle(permissions: StaffPermission[], changed: StaffPermission[], enabled: boolean): StaffPermission[] {
    const rest = permissions.filter((entry) => !changed.includes(entry));
    // Keep the canonical order so the server always gets the same shape
    return staffPermissions.filter((entry) => rest.includes(entry) || (enabled && changed.includes(entry)));
};

// Staff with staff.manage can only hand out permissions they have themselves
function grantable(group: PermissionGroup): StaffPermission[] {
    return group.permissions.map((permission) => permission.value).filter((permission) => owner.can(permission));
};

function toggleGroup(permissions: StaffPermission[], group: PermissionGroup, enabled: boolean): StaffPermission[] {
    return toggle(permissions, grantable(group), enabled);
};

function groupEnabled(group: PermissionGroup): boolean {
    return grantable(group).every((permission) => draft.value.includes(permission));
};

// Same rule for people: nobody edits or fires someone who can do more than they can
function canManage(member: StaffMember): boolean {
    return owner.can("staff.manage") && member.permissions.every((permission) => owner.can(permission));
};

const grantableRoles = computed(() => staffRoles.filter((role) => role.permissions.every((permission) => owner.can(permission))));

// "Custom" keeps the current permissions and opens the list to edit them one by one
const roleOptions = computed(() => [
    ...grantableRoles.value.map((role) => ({ label: t(role.label), value: role.value })),
    { label: t("owner.roles.custom"), value: "custom" },
]);

function roleLabel(permissions: StaffPermission[]): string {
    const role = staffRoles.find((entry) => entry.value === staffRoleOf(permissions));
    return role ? t(role.label) : t("owner.roles.custom");
};

function applyRole(value: string | undefined) {
    const role = staffRoles.find((entry) => entry.value === value);

    custom.value = !role;
    if (role) draft.value = [...role.permissions];
};

function initials(name: string): string {
    return name.split(/\s+/).map((part) => part[0] ?? "").join("").slice(0, 2).toUpperCase();
};

const search = ref<string | number | undefined>("");
const sort = ref<{ key: string; direction: "asc" | "desc" } | null>(null);

const columns = computed<DataTableColumn[]>(() => [
    { key: "name", label: t("owner.staff.employee"), sortable: true },
    { key: "role", label: t("owner.staff.role"), sortable: true },
    { key: "hiredAt", label: t("owner.staff.hired"), sortable: true },
    { key: "lastOnline", label: t("owner.staff.last_online"), sortable: true },
    ...(owner.can("staff.manage") ? [{ key: "actions", label: "", align: "right" as const }] : []),
]);

// Matches OwnerData.selfId when the owner is the one looking
const OWNER_ROW = "owner";

const rows = computed(() => {
    const query = String(search.value ?? "").trim().toLowerCase();
    const matches = (name: string) => !query || name.toLowerCase().includes(query);

    // The owner isn't hired and their last visit isn't tracked
    const ownerRow = owner.ownerMember && matches(owner.ownerMember.name)
        ? [{
            id: OWNER_ROW,
            name: owner.ownerMember.name,
            role: t("owner.roles.owner"),
            custom: false,
            hiredAt: null,
            lastOnline: null,
            online: owner.ownerMember.online,
        }]
        : [];

    return [
        ...ownerRow,
        ...owner.staff
            .filter((member) => matches(member.name))
            .map((member) => ({
                id: member.id,
                name: member.name,
                role: roleLabel(member.permissions),
                custom: !staffRoleOf(member.permissions),
                hiredAt: member.hiredAt,
                lastOnline: member.lastOnline,
                online: member.online,
            })),
    ];
});

function memberOf(row: DataTableRow): StaffMember | undefined {
    return owner.staff.find((member) => member.id === row.id);
};

type StaffModal =
    | { type: "hire" }
    | { type: "edit"; member: StaffMember }
    | { type: "fire"; member: StaffMember };

const modal = ref<StaffModal>();
const playerId = ref<string | number | undefined>();
const draft = ref<StaffPermission[]>([]);
// Picked explicitly, so the list stays open even if the boxes happen to match a preset
const custom = ref(false);
const error = ref<string>();
const busy = ref(false);

function open(next: StaffModal, permissions: StaffPermission[] = []) {
    modal.value = next;
    draft.value = [...permissions];
    custom.value = !staffRoleOf(permissions);
    playerId.value = undefined;
    error.value = undefined;
};

const openHire = () => open({ type: "hire" }, grantableRoles.value[0]?.permissions);
const openEdit = (member: StaffMember) => open({ type: "edit", member }, member.permissions);
const openFire = (member: StaffMember) => open({ type: "fire", member });

const canConfirm = computed(() => {
    if (modal.value?.type === "hire") return Number(playerId.value) > 0;
    if (modal.value?.type === "edit") return draft.value.join() !== modal.value.member.permissions.join();
    return true;
});

async function confirm() {
    const current = modal.value;
    if (!current || !canConfirm.value || busy.value) return;

    busy.value = true;
    error.value = undefined;

    try {
        const response = current.type === "hire"
            ? await owner.hireStaff(Math.floor(Number(playerId.value)), draft.value)
            : current.type === "edit"
                ? await owner.updateStaffPermissions(current.member.id, draft.value)
                : await owner.fireStaff(current.member.id);

        if (response?.success) {
            modal.value = undefined;
        } else {
            error.value = response?.error ?? t("owner.common.error");
        }
    } finally {
        busy.value = false;
    }
};
</script>
