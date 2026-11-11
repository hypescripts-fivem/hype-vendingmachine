import type { Component } from "vue";
import { sections } from "@/components/owner/sections";
import type { OwnerSection, StaffPermission } from "@/stores/owner";

export interface PermissionDetail {
    value: StaffPermission;
    label: string;
    description: string;
};

export interface PermissionGroup {
    section: OwnerSection;
    label: string;
    icon: Component;
    permissions: PermissionDetail[];
};

const details: Record<OwnerSection, PermissionDetail[]> = {
    dashboard: [
        { value: "dashboard.view", label: "owner.permissions.dashboard_view.label", description: "owner.permissions.dashboard_view.description" },
    ],
    products: [
        { value: "products.prices", label: "owner.permissions.products_prices.label", description: "owner.permissions.products_prices.description" },
    ],
    restock: [
        { value: "restock.order", label: "owner.permissions.restock_order.label", description: "owner.permissions.restock_order.description" },
    ],
    transactions: [
        { value: "transactions.view", label: "owner.permissions.transactions_view.label", description: "owner.permissions.transactions_view.description" },
    ],
    cash: [
        { value: "cash.deposit", label: "owner.permissions.cash_deposit.label", description: "owner.permissions.cash_deposit.description" },
        { value: "cash.withdraw", label: "owner.permissions.cash_withdraw.label", description: "owner.permissions.cash_withdraw.description" },
        { value: "cash.history", label: "owner.permissions.cash_history.label", description: "owner.permissions.cash_history.description" },
    ],
    staff: [
        { value: "staff.view", label: "owner.permissions.staff_view.label", description: "owner.permissions.staff_view.description" },
        { value: "staff.manage", label: "owner.permissions.staff_manage.label", description: "owner.permissions.staff_manage.description" },
    ],
    settings: [
        { value: "settings.general", label: "owner.permissions.settings_general.label", description: "owner.permissions.settings_general.description" },
        { value: "settings.hours", label: "owner.permissions.settings_hours.label", description: "owner.permissions.settings_hours.description" },
        { value: "settings.stock", label: "owner.permissions.settings_stock.label", description: "owner.permissions.settings_stock.description" },
        { value: "settings.payments", label: "owner.permissions.settings_payments.label", description: "owner.permissions.settings_payments.description" },
    ],
};

// Same order and icons as the sidebar, so each group reads like the page it unlocks
export const permissionGroups: PermissionGroup[] = sections.map((section) => ({
    section: section.value,
    label: section.label,
    icon: section.icon,
    permissions: details[section.value],
}));
