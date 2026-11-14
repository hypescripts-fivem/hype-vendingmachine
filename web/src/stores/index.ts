import { defineStore } from "pinia";
import { computed, ref } from "vue";
import { asList, asNumber, FetchNUI } from "@/utils";
import { demoView } from "@/utils/demo";

export interface Product {
    id: string;
    name: string;
    description?: string;
    category: string;
    price: number;
    stock: number;
    image?: string;
};

export interface CartItem {
    product: Product;
    quantity: number;
};

export const mockProducts: Product[] = [
    { id: "water", name: "Water", description: "500ml bottled water", category: "drinks", price: 5, stock: 24, image: "nui://ox_inventory/web/images/water.png" },
    { id: "cola", name: "eCola", description: "Classic fizzy cola", category: "drinks", price: 8, stock: 18, image: "nui://ox_inventory/web/images/cola.png" },
    { id: "sprunk", name: "Sprunk", description: "Lemon-lime soda", category: "drinks", price: 8, stock: 12, image: "nui://ox_inventory/web/images/sprunk.png" },
    { id: "coffee", name: "Coffee", description: "Hot black coffee", category: "drinks", price: 10, stock: 0, image: "nui://ox_inventory/web/images/coffee.png" },
    { id: "chips", name: "Chips", description: "Salted potato chips", category: "snacks", price: 6, stock: 20, image: "nui://ox_inventory/web/images/chips.png" },
    { id: "chocolate", name: "Chocolate", description: "Milk chocolate bar", category: "snacks", price: 7, stock: 15, image: "nui://ox_inventory/web/images/chocolate.png" },
    { id: "candy", name: "Candy", description: "Mixed fruit candy", category: "snacks", price: 4, stock: 30, image: "nui://ox_inventory/web/images/candy.png" },
    { id: "sandwich", name: "Sandwich", description: "Ham and cheese sandwich", category: "food", price: 15, stock: 8, image: "nui://ox_inventory/web/images/sandwich.png" },
    { id: "donut", name: "Donut", description: "Glazed donut", category: "food", price: 9, stock: 10, image: "nui://ox_inventory/web/images/donut.png" },
];

// Inventory image of a product, from the inventory resource set in setConfig
export function itemImageUrl(image: string | undefined): string {
    // The website demo has no inventory to read from, it ships its own copies (web/demo/items)
    if (demoView) return `${import.meta.env.BASE_URL}demo/items/${image?.replace(/\.\w+$/, "")}.webp`;

    return "nui://" + useShopStore().inventoryImagePath + image;
};

export type PaymentMethod = 'cash' | 'bank';

export interface VendingData {
    // Machine name shown in the header
    name: string;
    products: Product[];
    // What the owner accepts, and what the player has in each account
    payments: Record<PaymentMethod, boolean>;
    wallet: Record<PaymentMethod, number>;
};

const mockVending: VendingData = {
    name: "Legion Square #1",
    products: mockProducts,
    payments: { cash: true, bank: true },
    wallet: { cash: 120, bank: 5400 },
};

export const useShopStore = defineStore("shop", () => {
    const name = ref("");
    // The machine's products. The owner panel reuses this list for prices and stock
    const products = ref<Product[]>([]);
    const cart = ref<CartItem[]>([]);
    const category = ref("all");
    const search = ref("");
    const checkingOut = ref(false);
    const payments = ref<Record<PaymentMethod, boolean>>({ cash: false, bank: false });
    const wallet = ref<Record<PaymentMethod, number>>({ cash: 0, bank: 0 });
    const inventoryImagePath = "ox_inventory/web/images/";

    const categories = computed(() => [...new Set(products.value.map((product) => product.category))]);

    const filteredProducts = computed(() => {
        const query = search.value.trim().toLowerCase();

        return products.value.filter((product) =>
            (category.value === "all" || product.category === category.value) &&
            (!query || product.name.toLowerCase().includes(query))
        );
    });

    const cartCount = computed(() => cart.value.reduce((sum, item) => sum + item.quantity, 0));
    const cartTotal = computed(() => cart.value.reduce((sum, item) => sum + item.product.price * item.quantity, 0));

    function inCart(productId: string): number {
        return cart.value.find((item) => item.product.id === productId)?.quantity ?? 0;
    };

    function remainingStock(product: Product): number {
        return Math.max(0, product.stock - inCart(product.id));
    };

    function addToCart(product: Product, quantity: number) {
        const amount = Math.min(quantity, remainingStock(product));
        if (amount < 1) return;

        const item = cart.value.find((entry) => entry.product.id === product.id);

        if (item) {
            item.quantity += amount;
        } else {
            cart.value.push({ product, quantity: amount });
        }
    };

    function setQuantity(productId: string, quantity: number) {
        const item = cart.value.find((entry) => entry.product.id === productId);
        if (!item) return;

        if (quantity < 1) {
            removeFromCart(productId);
        } else {
            item.quantity = Math.min(quantity, item.product.stock);
        }
    };

    function removeFromCart(productId: string) {
        cart.value = cart.value.filter((item) => item.product.id !== productId);
    };

    function clearCart() {
        cart.value = [];
    };

    // Starts every visit with an empty cart and no filters
    async function load() {
        const response = await FetchNUI<VendingData>("vending:get-data", {}, JSON.parse(JSON.stringify(mockVending)));

        clearCart();
        category.value = "all";
        search.value = "";

        if (response.success && response.data) {
            name.value = response.data.name || "";
            products.value = asList(response.data.products);
            payments.value = { cash: response.data.payments?.cash === true, bank: response.data.payments?.bank === true };
            wallet.value = { cash: asNumber(response.data.wallet?.cash), bank: asNumber(response.data.wallet?.bank) };
        }

        return response;
    };

    async function checkout(payment: PaymentMethod) {
        if (!cart.value.length || checkingOut.value) return;

        checkingOut.value = true;

        try {
            // The server re-checks stock, the price, the payment method and the player's money, and can send back fresh products
            const total = cartTotal.value;
            const response = await FetchNUI<{ products?: Product[]; wallet?: Record<PaymentMethod, number> }>("checkout", {
                items: cart.value.map((item) => ({ id: item.product.id, quantity: item.quantity })),
                payment,
            });

            if (response.success) {
                if (response.data?.products) {
                    products.value = response.data.products;
                } else {
                    for (const item of cart.value) item.product.stock = Math.max(0, item.product.stock - item.quantity);
                }

                if (response.data?.wallet) {
                    wallet.value = { cash: asNumber(response.data.wallet.cash), bank: asNumber(response.data.wallet.bank) };
                } else {
                    wallet.value[payment] -= total;
                }

                clearCart();
            }

            return response;
        } finally {
            checkingOut.value = false;
        }
    };

    return {
        name,
        products,
        cart,
        category,
        search,
        checkingOut,
        payments,
        wallet,
        categories,
        filteredProducts,
        cartCount,
        cartTotal,
        inventoryImagePath,
        inCart,
        remainingStock,
        addToCart,
        setQuantity,
        removeFromCart,
        clearCart,
        checkout,
        load,
    };
});
