import { Boxes, LayoutDashboard, Settings } from "@lucide/vue";
import type { PanelSection } from "@/components/PanelSidebar.vue";
import type { AdminSection } from "@/stores/admin";

export const sections: PanelSection<AdminSection>[] = [
    { value: "dashboard", label: "admin.sections.dashboard.label", description: "admin.sections.dashboard.description", icon: LayoutDashboard },
    { value: "machines", label: "admin.sections.machines.label", description: "admin.sections.machines.description", icon: Boxes },
    { value: "settings", label: "admin.sections.settings.label", description: "admin.sections.settings.description", icon: Settings },
];
