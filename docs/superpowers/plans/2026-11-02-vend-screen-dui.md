# vend_screen DUI Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Amaç:** `arm` (olentrix) makinelerde "Aç", tam ekran NUI yerine makinenin `vend_screen` dokusuna çizilen bir DUI'yi ve ona odaklı bir kamerayı açar; oyuncu fareyle ekrandan sipariş verir.

**Mimari:** Aynı web build'i DUI olarak `nui://hype-vendingmachine/web/dist/index.html?view=screen&dui=1` adresinden açılır. DUI sayfası Lua ile bugünkü NUI callback'leri üzerinden konuşur (`fetch("https://hype-vendingmachine/...")`), sepet/checkout mantığı mevcut `useShopStore`'dan gelir. Yeni `client/cl-screen.lua` DUI'yi, doku değişimini, kamerayı ve fare/klavye girdisini yönetir; `cl-main.lua` arm makinelerde NUI yerine onu açar.

**Teknoloji:** FiveM Lua 5.4 + ox_lib, Vue 3 + Pinia + Tailwind v4 + `@vezironi/veyra-ui`, Vite.

**Spec:** `docs/superpowers/specs/2026-11-02-vend-screen-dui-design.md` (onaylı taslak: `.superpowers/brainstorm/1182-1793625543/content/vend-screen-v3.html`)

## Genel Kısıtlar

- Sadece istenen kod; ekstra özellik yok (kategori filtresi, arama, açıklama, debug/ayar komutu yok). Kullanılmayan kalan kod silinir.
- Her Lua fonksiyonunda `--- @param` / `--- @return` açıklamaları (mevcut dosyalardaki stil).
- Yeni paylaşılan Lua tipleri `shared/_types.lua` içine (`View` alias'ına `"screen"` eklenir, `ScreenConfig` sınıfı).
- Sunucu tarafında değişiklik yok; checkout bugünkü `checkout` NUI callback'i → `hype-vendingmachine:server:checkout` yolundan geçer.
- Arm olmayan makinelerin akışı ve owner/purchase/admin NUI'si değişmez.
- Tema: veyra-ui token'ları (`bg-bg-base`, `bg-bg-surface`, `border-border`, `text-text-primary`, `text-danger` …), monokrom, beyaz birincil buton.
- Ekran dikey; DUI varsayılanı 900×1200, config'ten değişir. Izgara 2 sütun.
- Web metinleri mevcut web gibi İngilizce sabit metin: `Cart`, `Quick order`, `Confirm cart`, `Back`, `Clear`, `Out of stock`, `Total`.
- Proje test altyapısı yok ve eklenmez. Doğrulama: `web` içinde `pnpm build` (vue-tsc tip kontrolü dahil), tarayıcı önizlemesi (`pnpm dev`) ve her görevin sonunda listelenen oyun içi kontroller.
- Commit yalnızca kullanıcı isterse atılır; görevlerde commit adımı yoktur.

## İnceleme Odağı

Spec'in ima ettiği ama görev testlerinin doğal olarak yakalamayacağı, en olası beş durum (her biri sahibi olan görevin kontrol listesine eklendi):

1. Ekran açıkken makinenin prop'u kalkıyor (oyuncu uzaklaştı, makine silindi/taşındı, kaynak durdu) → ekran kapanır, doku geri gelir, kamera ve kontroller serbest kalır. (Görev 3)
2. Ekran açıkken oyuncu ölüyor ya da makineden `Config.Interaction.maxDistance` ötesine itiliyor → ekran kapanır. (Görev 3)
3. İmleç ekran dörtgeninin dışındayken tıklama/tekerlek → DUI'ye hiçbir şey gitmez, oyun da ateş etmez/vurmaz. (Görev 4)
4. Ödeme başarısız (para yetmedi, stok başka alıcıyla bitti) → ekran açık kalır, `CheckoutModal` hatayı gösterir, sepet korunur. (Görev 5)
5. Yan yana aynı modelden iki makine → kullanan oyuncuda ikisi de ekranı gösterir (spec'te kabul edildi), ama tıklamalar sadece açılan makinenin köşelerinden eşlenir ve kamera sadece ona odaklanır. (Görev 4)

---

### Görev 1: Web'de DUI modu ve `screen` görünümü iskeleti

**Dosyalar:**
- Değiştir: `web/src/utils/index.ts` (`isDui`, `FetchNUI`)
- Değiştir: `web/src/stores/app.ts` (`View`'a `'screen'`, DUI başlangıcı)
- Değiştir: `web/src/App.vue` (`screen` sayfası)
- Oluştur: `web/src/pages/ScreenView.vue` (şimdilik sadece ürün adlarını listeleyen iskelet)
- Değiştir: `shared/_types.lua` (`---@alias View` → `"vending" | "purchase" | "owner" | "admin" | "screen"`)

**Arayüzler:**
- Üretir: `export const isDui: boolean` — `new URLSearchParams(location.search).get("dui") === "1"`.
- Üretir: `FetchNUI` artık `!isNative && !isDui` iken mock döner; DUI'de gerçek `fetch` yapar.
- Üretir: `View` tipine `'screen'`; `loaders.screen` = önce `FetchNUI<ScreenConfig>("screen:ready")`, gelen `{ inventoryImagePath, currency, locale, debug }` ile `setConfig`'teki aynı üç ayarı uygular, sonra `useShopStore().load()`.
- Üretir: DUI'de (`isDui`) app store `view = 'screen'`, `visible = true` ile başlar ve hemen `load('screen')` çağırır (NUI'deki `setView` mesajını beklemez). `history.pushState` DUI'de yapılmaz.
- Tüketir: Görev 3'teki `screen:ready` NUI callback'i (tarayıcı önizlemesinde mock: `{ inventoryImagePath: "ox_inventory/web/images/", currency: "USD", locale: "en-US", debug: true }`).

- [ ] **Adım 1:** `setConfig` handler'ındaki üç ayarı (`setDebug`, `useShopStore().inventoryImagePath`, `setLocaleFormat`) `web/src/utils/events.ts` içinde `export function applyConfig(config: { inventoryImagePath: string; currency: string; locale: string; debug: boolean }): void` olarak ayır; `setConfig` handler'ı onu çağırsın. `loaders.screen` da onu kullanır.
- [ ] **Adım 2:** Yukarıdaki arayüzleri uygula. `ScreenView.vue` kökü `flex h-screen w-screen flex-col bg-bg-base` (DUI tüm dokuyu doldurur; NUI'deki gibi ortalanmış kart değil).
- [ ] **Adım 3:** `cd web && pnpm build` → hatasız biter.
- [ ] **Adım 4:** `pnpm dev`, tarayıcıda `/?view=screen` → mock ürün adları listelenir; `/?view=vending` eskisi gibi çalışır.

### Görev 2: Ekran arayüzü (kartlar, alt çubuk, sepet, ödeme)

**Dosyalar:**
- Değiştir: `web/src/pages/ScreenView.vue`
- Oluştur: `web/src/components/screen/ScreenItem.vue` (ürün kartı)
- Oluştur: `web/src/components/screen/ScreenCart.vue` (sepet sayfası)
- Oluştur: `web/src/components/screen/ScreenBar.vue` (alt sabit çubuk)
- Oluştur: `web/src/components/screen/QuantityStepper.vue` (`− adet +`, kart ve sepet satırı ortak kullanır)
- Yeniden kullan: `web/src/components/shop/CheckoutModal.vue` (değişmeden)

**Arayüzler:**
- Tüketir: `useShopStore()` → `products`, `cart`, `cartCount`, `cartTotal`, `inCart(id)`, `remainingStock(product)`, `addToCart(product, 1)`, `setQuantity(id, n)`, `removeFromCart(id)`, `clearCart()`, `inventoryImagePath`, `name`.
- `ScreenItem` props: `{ product: Product; quantity: number; stock: number }` (stock = `remainingStock`). Emits yok; store'u doğrudan çağırır.
- `QuantityStepper` props: `{ quantity: number; max: number }`, emits `update: [quantity: number]`. `+`, `quantity >= max` iken pasif.
- `ScreenBar` emits: `cart: []`, `quick: []`. Sepet boşken iki buton da pasif.
- `ScreenCart` emits: `back: []`, `confirm: []`.
- `ScreenView` durumu: `page: "products" | "cart"`, `paying: boolean`. `quick` ve `confirm` → `paying = true` (`<CheckoutModal v-if="paying" @close="paying = false" />`). Sepet boşalırsa (`cart.length === 0`) `page` → `"products"`.

Düzen (v3 taslağına göre, 2 sütun):
- Kart: görsel alanı `bg-bg-inset`, sol üstte kategori etiketi, sağ üstte sepette değilse beyaz `+` (Button, primary), sepetteyse `QuantityStepper` + kırmızı sil (`Trash2`, danger). Altta solda ad, sağda fiyat (`formatMoney`). Görsel `'nui://' + shop.inventoryImagePath + product.image`, hata olursa `Package` ikonu (`ShopItem` ile aynı). Sepetteki kart vurgulu çerçeve; `stock < 1 && quantity === 0` iken soluk, `+` yok, "Out of stock".
- Alt çubuk: solda `cartCount` ve `formatMoney(cartTotal)`, sağda `Cart` (adet rozeti, secondary) ve `Quick order` (primary). Izgara kayar, çubuk sabit.
- Sepet sayfası: üstte "Cart" ve `Clear`; satırda küçük görsel, ad, birim fiyat, `QuantityStepper` (`max` = `item.product.stock`), satır toplamı, sil; altta `Total`, `Back` ve `Confirm cart`.

- [ ] **Adım 1:** Bileşenleri yaz.
- [ ] **Adım 2:** `cd web && pnpm build` → hatasız.
- [ ] **Adım 3:** `pnpm dev`, tarayıcı penceresini 900×1200'e getir, `/?view=screen` ile kontrol et:
  - `+` → kart stepper + kırmızı sile döner, çubuktaki adet/toplam güncellenir.
  - Stepper `−` 1'den aşağı → ürün sepetten çıkar, kart `+`'ya döner. `+` stoğa ulaşınca pasif.
  - Mock'ta `coffee` (stock 0) soluk, eklenemez, "Out of stock".
  - `Quick order` → `CheckoutModal` doğrudan açılır. `Cart` → sepet sayfası; `Confirm cart` → `CheckoutModal`; `Back` → ürünler.
  - Mock checkout başarılı → modal kapanır, sepet boşalır, ürünler sayfasına dönülür.
  - 9 mock ürünle ızgara kayar, alt çubuk yerinde kalır.

### Görev 3: Lua — ekranı aç/kapat (DUI, doku, kamera)

**Dosyalar:**
- Değiştir: `config/config.lua` (yeni `Screen` bloğu, `Machines`'ın yakınına)
- Değiştir: `shared/_types.lua` (`---@class ScreenConfig`)
- Oluştur: `client/cl-screen.lua`
- Değiştir: `client/cl-main.lua` (`openVending` yönlendirmesi, `screen:ready` callback'i, `removeEntity` temizliği)

**Arayüzler:**
- Config (değerler yer tutucu, oyunda ayarlanır; tüm olentrix modelleri tek değeri paylaşır):
  ```lua
  -- Arm machines open their own screen instead of the menu. Offsets are from the machine prop, tune them in game
  Screen = {
      texture = "vend_screen", -- texture name in the model; its dictionary is the model name
      width = 900,             -- DUI size in pixels, portrait like the screen
      height = 1200,
      camera = { offset = vec3(0.0, -0.6, 1.3), fov = 40.0 }, -- looks at the screen centre
      corners = {              -- the screen's corners on the prop
          topLeft = vec3(-0.15, -0.35, 1.5),
          topRight = vec3(0.05, -0.35, 1.5),
          bottomLeft = vec3(-0.15, -0.35, 1.2),
      },
  },
  ```
- `cl-screen.lua` globalleri:
  - `function OpenScreen(machine: MachineEntry): boolean` — entity yoksa ya da zaten açıksa `false`. DUI'yi `CreateDui(url, width, height)` ile açar, `IsDuiAvailable` bekler, `CreateRuntimeTxd`/`CreateRuntimeTextureFromDuiHandle`, `AddReplaceTexture(machine.data.model, Config.Screen.texture, txd, txn)`. Kamera `GetOffsetFromEntityInWorldCoords(entity, camera.offset)` konumunda, köşelerin ortasına `PointCamAtCoord`, `RenderScriptCams(true, true, 500, true, true)`. Açıkken her karede kontrolleri kapatan döngüyü başlatır (girdi Görev 4).
  - `function CloseScreen(): nil` — açık değilse hiçbir şey yapmaz. `RenderScriptCams(false, true, 500, true, true)`, `DestroyCam`, `RemoveReplaceTexture(model, texture)`, `DestroyDui`, `TriggerEvent("hype-vendingmachine:client:ui-closed")`.
  - `function IsScreenOpen(machineId?: integer): boolean` — id verilirse sadece o makine için.
  - Kapanma koşulları (döngü içinde): ESC (`200`) ya da Backspace (`177`) — `200` her karede `DisableControlAction` ile pause menüsünden alınır; oyuncu ölü (`IsEntityDead(cache.ped)`); oyuncu makineden `Config.Interaction.maxDistance`'tan uzak.
- `cl-main.lua`:
  - `openVending(data)`: `HasShelf(machines[data.id])` ise (arm model + olentrix_vending çalışıyor + prop spawn olmuş; mevcut fonksiyon) → `openView` ile aynı sunucu kontrolü (`hype-vendingmachine:server:get-vending-data`), `currentMachine = data.id`, `currentView = "screen"`, `viewData.vending = response.data`, sonra `OpenScreen(machines[data.id])`; NUI'ye `setView`/`SetNuiFocus` yok. Diğer makineler bugünkü gibi. (Ortak kısmı `openView`'dan küçük bir yardımcıya ayır; kopya kod bırakma.)
  - `RegisterNuiCallback("screen:ready", ...)` → `{ success = true, data = { inventoryImagePath = exports['hype-core']:GetImagePath(), currency = Config.Currency, locale = Config.NumberAndDateFormat, debug = Config.Debug } }`. (`cl-functions.lua`'daki `setConfig` ile aynı değerler; tek bir `--- @return table` yardımcıya ayrılıp ikisi de onu kullanır.)
  - `removeEntity(machine)`: `IsScreenOpen(machine.data.id)` ise önce `CloseScreen()`. Bu, uzaklaşma, silme/taşıma ve `onResourceStop` durumlarını kapsar.
  - DUI sayfası `vending:get-data` ile veriyi alır: mevcut callback `viewData.vending` döndürdüğü için değişiklik gerekmez.

- [ ] **Adım 0 (risk doğrulaması, önce bunu yap):** Oyunda en küçük denemeyle doğrula: DUI'den `fetch("https://hype-vendingmachine/screen:ready")` `RegisterNuiCallback`'e ulaşıyor ve cevap dönüyor. Ulaşmıyorsa dur ve haber ver; mimarinin haberleşme kısmı değişir (`SendDuiMessage` + Lua tarafında başka bir yol).
- [ ] **Adım 1:** Config, tip ve `cl-screen.lua` aç/kapat kısmını yaz; `cl-main.lua` değişikliklerini yap.
- [ ] **Adım 2:** `cd web && pnpm build` (DUI `web/dist`'ten açılır).
- [ ] **Adım 3:** Oyun içi kontrol (`ensure hype-vendingmachine`):
  - Arm makinede "Use vending machine" → kamera ekrana döner, `vend_screen` üzerinde ürün listesi görünür; normal makinede eski menü açılır.
  - ESC ve Backspace → kamera oyuncuya döner, doku orijinaline döner, pause menüsü açılmaz.
  - Ekran açıkken `restart hype-vendingmachine` → kamera ve doku takılı kalmaz.
  - Ekran açıkken admin makineyi silerse / taşırsa → ekran kapanır.
  - Ekran açıkken oyuncu ölürse ya da `maxDistance` ötesine itilirse → ekran kapanır.

### Görev 4: Lua — fare girdisini ekrana eşleme

**Dosyalar:**
- Değiştir: `client/cl-screen.lua`

**Arayüzler:**
- Tüketir: Görev 3'teki açık ekran durumu (DUI handle, entity, `Config.Screen.corners`, `width`, `height`).
- `local function cursorToDui(entity: integer): (number?, number?)` — imleç (`GetControlNormal(0, 239)`, `GetControlNormal(0, 240)`) ekran dörtgeninin içindeyse DUI piksel koordinatı, değilse `nil`. Köşeler her karede `GetOffsetFromEntityInWorldCoords` + `GetScreenCoordFromWorldCoord` ile ekrana izdüşürülür; üç köşeden (sol üst, sağ üst, sol alt) kurulan afin eşlemenin tersi alınır:
  ```
  e1 = TR - TL, e2 = BL - TL, p = cursor - TL      (2D ekran koordinatları)
  det = e1.x*e2.y - e1.y*e2.x
  u = (p.x*e2.y - p.y*e2.x) / det,  v = (e1.x*p.y - e1.y*p.x) / det
  0 <= u <= 1 ve 0 <= v <= 1 ise → (u*width, v*height)
  ```
- Her karede: `DisableAllControlActions(0)` (sonra ESC/Backspace okumak için `IsDisabledControlJustPressed`), `SetMouseCursorActiveThisFrame()`. Koordinat varsa `SendDuiMouseMove`; `24` basıldı/bırakıldı → `SendDuiMouseDown/Up(dui, "left")`; tekerlek `241`/`242` → `SendDuiMouseWheel(dui, ±deltaY, 0)`. Koordinat `nil` ise hiçbir DUI çağrısı yapılmaz.

- [ ] **Adım 1:** Uygula.
- [ ] **Adım 2:** Oyun içi kontrol (önce config köşelerini, imleç ekranın dört köşesindeki tuşlara denk gelecek şekilde ayarla):
  - Ekranın dört köşesine yakın tuşlar (ilk kartın `+`'sı, alt çubuktaki `Quick order`) tam tıklandığı yerde tepki verir.
  - Tekerlek ızgarayı kaydırır.
  - İmleç ekran dışındayken tıklama hiçbir şey yapmaz, karakter vurmaz/ateş etmez.
  - Yan yana aynı modelden iki makine: ikisinde de ekran görünür, tıklamalar sadece açılan makinede çalışır, kamera ona odaklı.

### Görev 5: Checkout sonrası kapanma

**Dosyalar:**
- Değiştir: `client/cl-main.lua` (`RegisterNUICallback("checkout", ...)`)

**Arayüzler:**
- Tüketir: `IsScreenOpen()`, `CloseScreen()` (Görev 3), `HasShelf(machine)`.
- Başarılı checkout'ta: `IsScreenOpen()` ise `CloseScreen()`; değilse bugünkü `HasShelf` dalı (NUI `close` + `SetNuiFocus(false, false)` + `ui-closed`) aynen kalır. `cb(response)` önce çağrılır ki sayfa cevabı alsın.

- [ ] **Adım 1:** Uygula.
- [ ] **Adım 2:** Oyun içi kontrol:
  - `Quick order` → nakit/banka seçimi → öde: ekran kapanır, kol ürünü tepsiye taşır, ürün envantere girer.
  - Sepet → `Confirm cart` → öde: aynı sonuç.
  - Parası yetmeyen yöntem pasif ve sebebi yazılı; sunucu reddederse (ör. stok o anda başka alıcıyla bitti) ekran açık kalır, modal hatayı gösterir, sepet durur.
  - "Pay"e hızlı iki kez tıklama tek sipariş oluşturur (`checkingOut` koruması).
  - Arm olmayan makinede bugünkü NUI checkout'u eskisi gibi çalışır.
