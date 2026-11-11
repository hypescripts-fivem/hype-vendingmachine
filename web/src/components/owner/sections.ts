import { Banknote, LayoutDashboard, Package, ReceiptText, Settings, Truck, Users } from "@lucide/vue";
import type { PanelSection } from "@/components/PanelSidebar.vue";
import type { OwnerSection } from "@/stores/owner";

export const sections: PanelSection<OwnerSection>[] = [
    { value: "dashboard", label: "owner.sections.dashboard.label", description: "owner.sections.dashboard.description", icon: LayoutDashboard },
    { value: "products", label: "owner.sections.products.label", description: "owner.sections.products.description", icon: Package },
    { value: "restock", label: "owner.sections.restock.label", description: "owner.sections.restock.description", icon: Truck },
    { value: "transactions", label: "owner.sections.transactions.label", description: "owner.sections.transactions.description", icon: ReceiptText },
    { value: "cash", label: "owner.sections.cash.label", description: "owner.sections.cash.description", icon: Banknote },
    { value: "staff", label: "owner.sections.staff.label", description: "owner.sections.staff.description", icon: Users },
    { value: "settings", label: "owner.sections.settings.label", description: "owner.sections.settings.description", icon: Settings },
];
