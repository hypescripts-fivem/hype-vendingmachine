# Makine Yerleştirme Gizmosu Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Amaç:** Admin formunda konum, yarı saydam bir hayalet makine ve three.js gizmosu ile oyun dünyasında taşınıp döndürülerek seçilir.

**Mimari:** İstemci (`client/cl-placement.lua`) hayaleti oluşturur, her karede render kamerasını ve hayaletin konumunu NUI'ye yollar, tuşları (Left Alt, G, ESC) okur. NUI (`PlacementOverlay.vue`) tam ekran şeffaf bir three.js sahnesinde kamerayı eşler, hayaletin yerindeki görünmez nesneye `TransformControls` bağlar; sürükleme değişikliklerini `placement:move` ile istemciye yollar. Admin sayfası yerleştirme sırasında `v-show` ile gizlenir, form state'i kaybolmaz.

**Teknoloji:** FiveM Lua + ox_lib, Vue 3 + Pinia, three.js (`TransformControls`), veyra-ui.

**Spec:** `docs/superpowers/specs/2026-11-02-machine-placement-gizmo-design.md`

## Genel Kısıtlar

- Harici kaynak bağımlılığı yok; web'e sadece `three` (+ `@types/three`) paketi eklenir.
- Gizmo: taşıma X/Y/Z, dönme sadece Z (heading). GTA ve three.js ikisi de z-yukarı kullanılır (`camera.up = (0,0,1)`), eksen dönüşümüne gerek kalmaz; heading = `rotation.z` (derece ↔ radyan).
- Tuşlar: Left Alt (control 19) imleç ↔ serbest bakış, `G` (control 47) yere sabitle, ESC (control 200) iptal. Pause menüsü açılmaz.
- Düzenleme yalnızca admin makineye `Config.Placement.editDistance` (10.0) içindeyken; değilse hata: `Go to the machine to move it.`
- Düzenlenen makine yerleştirme süresince kaldırılır (prop + raflar + kol), her bitişte yeniden spawn edilir.
- Kalkan kod silinir: X/Y/Z/Heading kutuları, "Use my position", `admin:get-position` callback'i, `admin.getPosition`.
- Lua: her fonksiyonda `@param`/`@return`; tipler `shared/_types.lua`. Sunucu değişmez. Commit yok.
- Doğrulama: `cd web && pnpm build`, lua-language-server `--check` (Error), oyun içi kontrol listesi (kullanıcı).

## İnceleme Odağı

1. Yerleştirme sırasında admin ölür, kaynak durur ya da admin paneli başka yoldan kapanır → hayalet silinir, NUI odağı bırakılır, düzenlenen makine geri gelir.
2. Kamera hızlı dönerken / admin yürürken gizmo hayaletin üstünde kalır (kamera eşlemesi her kare).
3. İmleç kapalıyken (serbest bakış) gizmo tıklanamaz, oyun kamerası döner; imleç açıkken kamera dönmez.
4. Onaylanıp kaydedilmeden panel kapatılırsa düzenlenen makine eski yerinde geri gelir.
5. Yeni makinede model formda değiştirildikten sonra yerleştirme açılırsa yeni modelin hayaleti çıkar.

---

### Görev 1: three.js ve NUI yerleştirme katmanı

**Dosyalar:**
- `web/package.json` (`pnpm add three`, `pnpm add -D @types/three`)
- Oluştur: `web/src/stores/placement.ts`
- Oluştur: `web/src/components/admin/PlacementOverlay.vue` (three.js canvas + gizmo)
- Oluştur: `web/src/components/admin/PlacementPanel.vue` (sol üst panel)
- Değiştir: `web/src/pages/AdminView.vue` (yerleştirme aktifken admin `main` `v-show` ile gizli, overlay + panel görünür)
- Değiştir: `web/src/utils/events.ts` (`placement:frame` handler'ı)

**Arayüzler:**
- `usePlacementStore()`:
  - `active: Ref<boolean>`, `mode: Ref<"translate" | "rotate">`, `cursor: Ref<boolean>`, `position: Ref<{ x; y; z; heading }>`, `camera: Ref<PlacementCamera | undefined>`
  - `start(model: string, machineId?: string): Promise<NuiResponse<MachineLocation | undefined>>` — `placement:start` çağırır; başarısızsa hatayı döner. Başarılıysa `active = true` olur ve dönen promise onay/iptalde çözülür: onayda `MachineLocation` (sokak adı `label`'da), iptalde `undefined`.
  - `move(): void` — `placement:move` ile `position`'ı yollar.
  - `snap(): void` → `placement:snap`; `confirm(): void` → `placement:confirm`; `cancel(): void` → `placement:cancel`.
  - `setFrame(frame: PlacementFrame): void` — `placement:frame` mesajından: kamera, sürüklenmiyorsa `position`, `cursor`.
  - `finish(location?: MachineLocation): void` — `placement:finish` mesajından (istemci bitirdi: onay, iptal, ölüm…) `active = false` ve bekleyen promise'i çözer.
- Mesajlar (Lua → NUI): `placement:frame` `{ camera: { x, y, z, forward: {x,y,z}, fov }, entity: { x, y, z, heading }, cursor: boolean }`; `placement:finish` `{ location?: MachineLocation }`.
- `PlacementOverlay`: `PerspectiveCamera(fov, innerWidth/innerHeight, 0.01, 1000)`, `up = (0,0,1)`, her `placement:frame`'de `position.set` + `lookAt(pos + forward)`. Görünmez `Object3D` hayaletin yerinde; `TransformControls` ona bağlı (`showX/showY/showZ` taşımada açık; dönmede `showX = showY = false`). `objectChange` → store `position` güncellenir, `move()` (requestAnimationFrame başına en fazla bir kez). Sürüklerken (`dragging-changed`) frame'deki entity konumu objeyi ezmez. `WebGLRenderer({ alpha: true })`, canvas `pointer-events` sadece `cursor` açıkken.
- `PlacementPanel`: sol üstte; x/y/z/heading (2 ondalık), Move/Rotate toggle, Snap to ground (G), Confirm, Cancel (Esc), ipucu `Left Alt: cursor / look around`.

- [ ] **Adım 1:** Paketleri ekle, store'u, iki bileşeni, AdminView ve events değişikliğini yaz.
- [ ] **Adım 2:** `cd web && pnpm build` → hatasız.

### Görev 2: Formda "Set machine position"

**Dosyalar:**
- Değiştir: `web/src/components/admin/MachineForm.vue` (kutular + "Use my position" kalkar; buton + salt okunur özet; `machineId?: string` prop)
- Değiştir: `web/src/components/admin/AdminMachineDetail.vue` (`:machine-id="machine.id"`)
- Değiştir: `web/src/stores/admin.ts` (`getPosition` silinir)

**Arayüzler:**
- Buton → `placement.start(config.model, props.machineId)`. Hata → bölümde `text-danger` ile gösterilir. Onayda `config.location = { label: config.location.label || label, x, y, z, heading }` (2 ondalık).
- Özet: konum yoksa `No position yet`, varsa `x, y, z · heading°`.

- [ ] **Adım 1:** Uygula. **Adım 2:** `pnpm build` → hatasız.

### Görev 3: İstemci — yerleştirme

**Dosyalar:**
- Oluştur: `client/cl-placement.lua`
- Değiştir: `client/cl-main.lua` (`GetMachine(id)`, `SetMachineHidden(id, hidden)`, `onEnter`'da `machine.hidden` kontrolü)
- Değiştir: `client/cl-admin.lua` (`admin:get-position` silinir)
- Değiştir: `config/config.lua` (`Placement = { editDistance = 10.0 }`), `shared/_types.lua` (`PlacementState`, `MachineEntry.hidden`)

**Arayüzler:**
- `cl-main.lua`:
  - `function GetMachine(machineId: integer): MachineEntry?`
  - `function SetMachineHidden(machineId: integer, hidden: boolean): nil` — gizle: `machine.hidden = true` + `removeEntity`; göster: `removeMachine` + `setMachine(data)` (nokta yeniden kurulur, admin yakındaysa prop + raflar spawn olur).
- `cl-placement.lua` NUI callback'leri:
  - `placement:start { model, machineId? }` → zaten aktifse hata. `machineId` varsa: makine yoksa ya da `#(ped - makine) > editDistance` → `{ success = false, error = "Go to the machine to move it." }`; varsa başlangıç = makinenin konumu/heading'i, `SetMachineHidden(id, true)`. Yoksa başlangıç = oyuncunun 2 m önü, heading = oyuncu heading + 180, yere oturtulmuş. Model `lib.requestModel`; hayalet `CreateObjectNoOffset(..., false, false, false)`, `SetEntityAlpha(160)`, `SetEntityCollision(false, false)`, `FreezeEntityPosition(true)`. `SetNuiFocus(true, true)`, `SetNuiFocusKeepInput(true)`. Döngü başlar. Cevap `{ success = true, data = { x, y, z, heading } }`.
  - `placement:move { x, y, z, heading }` → `SetEntityCoordsNoOffset` + `SetEntityHeading`.
  - `placement:snap` → `PlaceObjectOnGroundProperly(ghost)`.
  - `placement:confirm` → sonucu (konum + `GetStreetNameFromHashKey(GetStreetNameAtCoord(...))`) `finish` ile yollar.
  - `placement:cancel` → `finish(nil)`.
- Döngü (her kare): `placement:frame` mesajı (`GetFinalRenderedCamCoord`, `GetFinalRenderedCamRot(2)` → forward vektör, `GetFinalRenderedCamFov`, hayalet konumu/heading, `cursor`). İmleç açıkken `DisableControlAction` 1, 2 (bakış), 24, 25, 257, 140–142 (saldırı). Her karede 200 kapalı; `IsDisabledControlJustPressed(0, 200)` → iptal. 19 basılınca `cursor = not cursor`, `SetNuiFocus(cursor, cursor)` (+ `SetNuiFocusKeepInput(true)`). 47 → yere sabitle. Admin ölürse → iptal.
- `local function finish(location?: table): nil` — hayaleti sil, `SetNuiFocusKeepInput(false)`, `SetNuiFocus(true, true)` (admin paneli geri gelir), düzenlenen makine varsa `SetMachineHidden(id, false)`, `NuiMessage("placement:finish", { location = location })`. Kaynak durunca: hayalet silinir, makine geri gelir.

- [ ] **Adım 1:** Uygula. **Adım 2:** lua-language-server `--check` → hata yok; `pnpm build` → hatasız.
- [ ] **Adım 3 (oyun içi, kullanıcı):** yeni makine → hayalet önde, gizmo üstünde; okla taşı, halkayla döndür, G ile zemine otur, Left Alt ile yürü/bak; Confirm → form dolu ve konum dolu; Cancel/Esc → konum değişmez, pause menüsü açılmaz. Düzenle: 10 m dışı → uyarı; içinde → gerçek makine kaybolur, hayalet yerinde; onay/iptal sonrası gerçek makine geri gelir; kaydedince yeni yerde spawn olur.
