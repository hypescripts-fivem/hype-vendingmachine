# NUI Callbacks

UI (`web/`) ile Lua arasındaki bütün iletişim. UI tarafı hazır; Lua tarafı bu listeye göre yazılmalı.

## Genel kurallar

- **Her callback cevabı** aynı biçimde döner:

  ```json
  { "success": true, "data": { } }
  { "success": false, "error": "Oyuncuya gösterilecek hata metni" }
  ```

  `error` metni panelde olduğu gibi gösterilir. `data` gerekmiyorsa gönderilmeyebilir.
  Callback hiç yoksa, boş cevap dönerse ya da `success` alanı olmayan bir cevap dönerse UI bunu `success: false` sayar ve konsola uyarı yazar.
- **`vending:*` ve `owner:*` çağrıları makine id'si göndermez.** Oyuncunun hangi makineyi açtığını client tutar ve sunucuya kendisi ekler.
- **UI kontrolleri sadece görüntü içindir.** Fiyat, bakiye, stok, kapasite, mesafe ve yetki kontrolleri sunucuda tekrar yapılmalıdır.
- **Paneller her açılışta veriyi yeniden ister.** Lua `setView` gönderir, UI ilgili `getData` callback'ini çağırır ve veri gelene kadar sayfayı çizmez.
- **Kapatma:** Çarpı, çıkış butonu veya ESC tuşu UI'yi hemen gizler ve `close` callback'ini çağırır. Lua bu sırada NUI focus'u bırakır.

---

## Lua → UI mesajları

`SendNUIMessage({ action = "...", payload = ... })`

| action | payload | Ne işe yarar |
|---|---|---|
| `nuiReady` | – | UI'nin `nui-ready` callback'ini çağırmasını sağlar |
| `setConfig` | `{ inventoryImagePath, currency, locale }` | Ürün resimlerinin yolu ve para formatı (`Config.Currency`, `Config.NumberAndDateFormat`). Bütün para ve tarih gösterimleri bununla formatlanır |
| `setView` | `{ view: "vending" \| "purchase" \| "owner" \| "admin" }` | Paneli açar ve o panelin `getData` callback'ini tetikler |
| `close` | – | Lua'nın UI'yi kapatması (oyuncu uzaklaştı, öldü, makine silindi vb.) |
| `setAccess` | `OwnerAccess` | Sahip paneli açıkken personelin yetkisi değişirse |
| `setOrderStatus` | `{ id, status }` | Stok siparişinin durumunu ilerletir: `preparing` → `prepared` → `shipping` → `completed`, ya da `cancelled` (oyuncu teslim alma bölgesinden ayrıldı). Stoku sunucu kutu kutu ekler |
| `setStaffOnline` | `{ id, online }` | Personelin çevrimiçi rozetini günceller |

---

## Genel

| Callback | Gönderilen | Beklenen `data` | Ne işe yarar |
|---|---|---|---|
| `nui-ready` | `{}` | – | `nuiReady` mesajına cevap; UI'nin yüklendiğini bildirir |
| `close` | `{}` | – | UI kapandı; NUI focus bırakılır |

---

## Satış ekranı (vending)

| Callback | Gönderilen | Beklenen `data` | Ne işe yarar |
|---|---|---|---|
| `vending:get-data` | `{}` | `{ name, products: Product[], payments: { cash, bank }, wallet: { cash, bank } }` | Makine adı (başlıkta görünür), satıştaki ürünler, sahibin kabul ettiği ödeme yöntemleri ve oyuncunun iki hesaptaki parası |
| `checkout` | `{ items: [{ id, quantity }], payment: "cash" \| "bank" }` | `{ products?: Product[], wallet? }` | Ödeme modalında seçilen yöntemle satın alma. `products` dönülürse liste onunla yenilenir; dönülmezse UI stoğu kendisi düşürür. `wallet` dönülmezse UI seçilen hesaptan toplamı düşer |

**Sunucu `checkout`'ta şunları kontrol etmeli:** stok, güncel fiyat, seçilen ödeme yönteminin kabul edilip edilmediği, oyuncunun o hesaptaki parası, makinenin açık olup olmadığı ve mesafe.

---

## Satın alma modalı (purchase)

Satılık bir makinenin target'ından açılır. Client önce sunucuya sorar; makine satılık değilse veya oyuncu uzaktaysa modal hiç açılmaz.

| Callback | Gönderilen | Beklenen `data` | Ne işe yarar |
|---|---|---|---|
| `purchase:get-data` | `{}` | `PurchaseData` | Makine bilgisi, fiyat ve oyuncunun bakiyesi |
| `purchase:buy` | `{}` | `{ message? }` | Makineyi satın alır. Başarılıysa UI kapanır, sonuç bildirim olarak gösterilir |

**Sunucu `purchase:buy`'da şunları kontrol etmeli:** makinenin hâlâ satılık olduğu, `allowPlayerPurchase`, `maxMachinesPerPlayer`, oyuncunun parası ve mesafe.

---

## Sahip paneli (owner)

| Callback | Gönderilen | Beklenen `data` | Ne işe yarar |
|---|---|---|---|
| `owner:get-data` | `{}` | `OwnerData` | Panelin bütün verisi |
| `owner:update-price` | `{ id, price }` | – | Ürünün satış fiyatını değiştirir |
| `owner:order-stock` | `{ items: [{ productId, quantity }] }` | `{ balance?, orderId? }` | Stok siparişi verir; tutar makine bakiyesinden düşer. Ardından durum `setOrderStatus` ile ilerletilir |
| `owner:pickup-order` | `{ id }` | – | `prepared` siparişi teslim almaya başlar. Başarılıysa panel kapanır, araba spawn olur |
| `owner:deposit` | `{ amount }` | `{ balance?, wallet? }` | Oyuncudan makine kasasına para yatırır |
| `owner:withdraw` | `{ amount }` | `{ balance?, wallet? }` | Makine kasasından oyuncuya para çeker |
| `owner:save-settings` | `OwnerSettings` | – | Ad, açıklama, açık/kapalı durumu, çalışma saatleri, stok uyarıları ve ödeme yöntemlerini kaydeder |
| `owner:hire-staff` | `{ playerId, permissions: StaffPermission[] }` | `{ member?: StaffMember }` | Yakındaki bir oyuncuyu işe alır |
| `owner:update-staff` | `{ id, permissions: StaffPermission[] }` | – | Personelin yetkilerini değiştirir |
| `owner:fire-staff` | `{ id }` | – | Personeli kovar |
| `owner:transfer` | `{ playerId }` | – | Makineyi başka bir oyuncuya devreder. Başarılıysa panel kapanır |
| `owner:sell` | `{}` | – | Makineyi satar. Başarılıysa panel kapanır |

**Notlar:**
- `balance` ve `wallet` dönülürse UI onları o değere ayarlar; dönülmezse kendisi hesaplar.
- Her callback'te yetki kontrol edilmeli. Sahip her şeyi yapabilir; personel yalnızca `permissions` listesindekileri yapabilir.

### Personel yetkileri (`StaffPermission`)

| Yetki | Callback / ekran |
|---|---|
| `dashboard.view` | Gösterge paneli |
| `products.prices` | `owner:update-price` |
| `restock.order` | `owner:order-stock`, `owner:pickup-order` |
| `transactions.view` | Satış geçmişi |
| `cash.deposit` | `owner:deposit` |
| `cash.withdraw` | `owner:withdraw` |
| `cash.history` | Kasa hareketleri ve üst bardaki bakiye |
| `staff.view` | Personel listesi |
| `staff.manage` | `owner:hire-staff`, `owner:update-staff`, `owner:fire-staff` |
| `settings.general` | `owner:save-settings` (ad, açıklama, açık/kapalı) |
| `settings.hours` | `owner:save-settings` (çalışma saatleri) |
| `settings.stock` | `owner:save-settings` (stok uyarıları, otomatik sipariş) |
| `settings.payments` | `owner:save-settings` (ödeme yöntemleri) |

`owner:transfer` ve `owner:sell` callback'lerini sadece sahip kullanabilir.

---

## Admin paneli

| Callback | Gönderilen | Beklenen `data` | Ne işe yarar |
|---|---|---|---|
| `admin:get-data` | `{}` | `AdminData` | Bütün makineler, 7 günlük toplam ciro, ayarlar ve ürün kataloğu |
| `admin:get-position` | `{}` | `MachineLocation` | "Konumumu kullan" butonu; admin'in bulunduğu yer ve bölge adı |
| `admin:teleport` | `{ id }` | – | Admin'i makinenin yanına ışınlar |
| `admin:create-machine` | `MachineConfig` | `{ id, ownerName? }` | Yeni makine oluşturur |
| `admin:import-machine` | `{ machines: MachineConfig[] }` | `{ ids: string[] }` | JSON'dan toplu makine ekler. `ids` gönderilen sırayla dönmelidir |
| `admin:update-machine` | `{ id, ...MachineConfig }` | `{ ownerName? }` | Makineyi düzenler veya sahibini değiştirir |
| `admin:set-status` | `{ id, status: MachineStatus }` | – | Makineyi devre dışı bırakır (`disabled`) veya tekrar açar (`closed`) |
| `admin:reset-balance` | `{ id }` | – | Makine kasasını sıfırlar |
| `admin:delete-machine` | `{ id }` | – | Makineyi siler |
| `admin:save-settings` | `AdminSettings` | – | Genel ayarları kaydeder |

**Notlar:**
- Her admin callback'inde admin yetkisi kontrol edilmeli.
- `admin:create-machine` ve `admin:update-machine`'de `ownerId` bir server id ya da citizen id olabilir (oyuncu çevrimiçi olmalı); sunucu bunu oyuncuya çevirip `ownerName`'i döner. `forSale: true` ise `ownerId` boştur. Sahip girilmezse UI makineyi `forSale: true` olarak gönderir; sunucu da boş `ownerId` gelen makineyi satılık saymalıdır.
- Admin panelinde satılık makineler `closed` yerine "For sale" olarak görünür. `disabled` her zaman önce gelir.
- `admin:update-machine`'de gelen `ownerId` her zaman geçerli sahiptir. Değişmediyse eski sahip gönderilir.
- `admin:import-machine` ile gelen makineler sahipsiz ve satılıktır (`ownerId: ""`, `forSale: true`). Sunucu aynı konumda makine olup olmadığını, ürünlerin ve modelin geçerli olduğunu tekrar kontrol etmeli.
- Yeni oluşturulan veya içe aktarılan makineler UI'da `closed` durumunda, bakiye ve stok 0 olarak görünür.

---

## Veri tipleri

### Product

```ts
{
    id: string;          // item adı, ör. "water"
    name: string;
    description?: string;
    category: string;    // ör. "drinks", "snacks", "food"
    price: number;
    stock: number;
    image?: string;      // ör. "nui://ox_inventory/web/images/water.png"
}
```

### PurchaseData

```ts
{
    name: string;
    area: string;                 // bölge adı
    model: string;                // model etiketi, ör. "Soda machine"
    price: number;
    capacity: number;             // ürün başına en fazla stok
    products: Product[];
    account: "bank" | "cash";     // fiyatın çekileceği hesap
    balance: number;              // oyuncunun o hesaptaki parası
}
```

### OwnerData

```ts
{
    access: OwnerAccess;
    settings: OwnerSettings;
    balance: number;
    wallet: number;                      // paneli açanın Config.CashAccount hesabındaki parası (Deposit "All")
    capacity: number;                    // ürün başına en fazla stok
    products: Product[];                 // makinenin ürünleri, stok ve fiyatla
    revenue: DailyRevenue[];             // son 7 gün, eskiden yeniye
    transactions: Transaction[];         // yeniden eskiye
    unitsSold: Record<string, number>;   // ürün id → satılan adet
    cashMovements: CashMovement[];       // yeniden eskiye
    wholesale: Record<string, number>;   // ürün id → sipariş birim fiyatı
    orders: StockOrder[];                // yeniden eskiye
    staff: StaffMember[];
    ownerMember: { name: string; online: boolean } | null;   // personel listesinin en üstünde; düzenlenemez, kovulamaz
    selfId: string | null;               // paneli açan kişi: "owner" ya da kendi personel id'si
}
```

### OwnerAccess

```ts
{
    owner: boolean;                  // true ise her şeyi görür
    permissions: StaffPermission[];  // personelse görebildikleri
}
```

### OwnerSettings

```ts
{
    name: string;
    description: string;
    open: boolean;
    schedule: { enabled: boolean; opensAt: string; closesAt: string };  // oyun saati, "HH:MM" 24 saat
    lowStockThreshold: number;
    autoRestock: boolean;
    notifyLowStock: boolean;
    notifySales: boolean;
    payments: { cash: boolean; bank: boolean };
}
```

### DailyRevenue

```ts
{ date: string; revenue: number; sales: number }   // date "YYYY-MM-DD", ör. "2026-10-24"
```

### Transaction

```ts
{ id: string; time: number; buyer: string; productId: string; quantity: number; total: number }
```

### CashMovement

```ts
{ id: string; time: number; type: "deposit" | "withdraw" | "order"; amount: number; by: string }
```

### StockOrder

```ts
{
    id: string;
    time: number;                // milisaniye
    items: { productId: string; quantity: number }[];
    total: number;
    status: "preparing" | "prepared" | "shipping" | "completed" | "cancelled";
}
```

### StaffMember

```ts
{
    id: string;
    name: string;
    hiredAt: number;             // milisaniye
    lastOnline: number | null;   // milisaniye; paneli hiç açmadıysa null
    online: boolean;
    permissions: StaffPermission[];
}
```

### AdminData

```ts
{
    machines: Machine[];
    revenue: { date: string; revenue: number }[];   // son 7 gün ("YYYY-MM-DD"), tüm makineler, eskiden yeniye
    settings: AdminSettings;
    products: Product[];   // makinelere atanabilecek bütün ürünler (id, name, category, image yeterli)
}
```

### MachineConfig

```ts
{
    name: string;
    model: string;          // "prop_vend_soda_01" | "prop_vend_snak_01" | "prop_vend_coffe_01" | "prop_vend_water_01"
    location: MachineLocation;
    ownerId: string;        // server id veya citizen id; satılıksa ""
    forSale: boolean;
    price: number;          // satın alma fiyatı
    capacity: number;       // ürün başına en fazla stok
    products: string[];     // ürün id'leri
}
```

### MachineLocation

```ts
{ label: string; x: number; y: number; z: number; heading: number }   // label = bölge adı
```

### Machine

```ts
MachineConfig & {
    id: string;
    colorSlot: number;          // grafik rengi, 0-7; makineye bir kez verilir ve değişmez
    ownerName: string | null;   // satılıksa null
    status: MachineStatus;
    balance: number;
    revenue: number;
    sales: number;
    stockLevel: number;         // 0-100, ürünlerin ortalama doluluk yüzdesi; 25'in altı "düşük stok" sayılır
    createdAt: number;          // milisaniye
}
```

### MachineStatus

```ts
"open" | "closed" | "disabled"
```

### AdminSettings

```ts
{
    wholesaleMultiplier: number;
    salesTax: number;              // yüzde
    maxMachinesPerPlayer: number;
    deliveryMinutes: number;
    defaultCapacity: number;
    defaultPrice: number;
    allowPlayerPurchase: boolean;
    logPurchases: boolean;
    logAdminActions: boolean;
}
```
