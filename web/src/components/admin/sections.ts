import { Boxes, LayoutDashboard, Settings } from "@lucide/vue";
import type { PanelSection } from "@/components/PanelSidebar.vue";
import type { AdminSection } from "@/stores/admin";

export const sections: PanelSection<AdminSection>[] = [
    { value: "dashboard", label: "Overview", description: "Server-wide vending statistics.", icon: LayoutDashboard },
    { value: "machines", label: "Machines", description: "Every vending machine on the server.", icon: Boxes },
    { value: "settings", label: "Settings", description: "Global rules for all vending machines.", icon: Settings },
];
