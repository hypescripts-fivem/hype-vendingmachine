import { defineStore } from "pinia";
import { ref } from "vue";
import { asList, asNumber, FetchNUI } from "@/utils";
import { mockProducts, type Product } from "@/stores";

// A machine that's for sale, sent by purchase:get-data when the modal opens
export interface PurchaseData {
    name: string;
    // Area name
    area: string;
    // Model label, e.g. "Soda machine"
    model: string;
    price: number;
    // Max units of each product the machine holds
    capacity: number;
    products: Product[];
    // Where the price is taken from, and how much the player has there
    account: "bank" | "cash";
    balance: number;
};

const blankData: PurchaseData = {
    name: "",
    area: "",
    model: "",
    price: 0,
    capacity: 0,
    products: [],
    account: "bank",
    balance: 0,
};

const mockData: PurchaseData = {
    name: "Sandy Shores Gas",
    area: "Sandy Shores",
    model: "Soda machine",
    price: 15000,
    capacity: 30,
    products: mockProducts.slice(0, 3),
    account: "bank",
    balance: 42500,
};

export const usePurchaseStore = defineStore("purchase", () => {
    const machine = ref<PurchaseData>(blankData);
    const buying = ref(false);

    async function load() {
        const response = await FetchNUI<PurchaseData>("purchase:get-data", {}, mockData);
        const data = response.data;

        if (response.success && data) {
            machine.value = {
                ...blankData,
                ...data,
                price: asNumber(data.price),
                capacity: asNumber(data.capacity),
                balance: asNumber(data.balance),
                products: asList(data.products),
            };
        };

        return response;
    };

    // The server re-checks the price, the player's money, the machine limit and that it's still for sale
    async function buy() {
        if (buying.value) return;

        buying.value = true;

        try {
            return await FetchNUI<{ message?: string }>("purchase:buy");
        } finally {
            buying.value = false;
        }
    };

    return {
        machine,
        buying,
        load,
        buy,
    };
});
