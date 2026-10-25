import { Banknote, LayoutDashboard, Package, ReceiptText, Settings, Truck, Users } from "@lucide/vue";
import type { PanelSection } from "@/components/PanelSidebar.vue";
import type { OwnerSection } from "@/stores/owner";

export const sections: PanelSection<OwnerSection>[] = [
    { value: "dashboard", label: "Dashboard", description: "Revenue and sales overview for this machine.", icon: LayoutDashboard },
    { value: "products", label: "Products", description: "Stock levels and prices.", icon: Package },
    { value: "restock", label: "Restock", description: "Order new stock from the supplier.", icon: Truck },
    { value: "transactions", label: "Transactions", description: "Every purchase made at this machine.", icon: ReceiptText },
    { value: "cash", label: "Cash", description: "Withdraw and deposit money in the machine.", icon: Banknote },
    { value: "staff", label: "Staff", description: "Hire employees and choose what they can do.", icon: Users },
    { value: "settings", label: "Settings", description: "Machine name and availability.", icon: Settings },
];
