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
        { value: "dashboard.view", label: "View stats", description: "See revenue, sales and top products." },
    ],
    products: [
        { value: "products.prices", label: "Change prices", description: "Set the price customers pay." },
    ],
    restock: [
        { value: "restock.order", label: "Order stock", description: "Buy stock from the supplier with the machine balance." },
    ],
    transactions: [
        { value: "transactions.view", label: "View sales", description: "See every purchase made at the machine." },
    ],
    cash: [
        { value: "cash.deposit", label: "Deposit money", description: "Put their own cash into the machine." },
        { value: "cash.withdraw", label: "Withdraw money", description: "Take money out of the machine balance." },
        { value: "cash.history", label: "View history", description: "See the balance and past cash movements." },
    ],
    staff: [
        { value: "staff.view", label: "View staff", description: "See who works here and their roles." },
        { value: "staff.manage", label: "Manage staff", description: "Hire, fire and change permissions they have themselves." },
    ],
    settings: [
        { value: "settings.general", label: "General", description: "Rename the machine and open or close it." },
        { value: "settings.hours", label: "Operating hours", description: "Change the open and close schedule." },
        { value: "settings.stock", label: "Stock & alerts", description: "Low stock threshold, auto restock and notifications." },
        { value: "settings.payments", label: "Payments", description: "Choose which payment methods are accepted." },
    ],
};

// Same order and icons as the sidebar, so each group reads like the page it unlocks
export const permissionGroups: PermissionGroup[] = sections.map((section) => ({
    section: section.value,
    label: section.label,
    icon: section.icon,
    permissions: details[section.value],
}));
