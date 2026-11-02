# Makine yerleştirme gizmosu — Tasarım

Tarih: 2026-11-02

## Amaç ve neden

Admin panelinde makine oluştururken veya düzenlerken konum bugün X/Y/Z/Heading sayı kutularıyla ya da "Use my position" ile
giriliyor. Bunun yerine admin, makinenin yarı saydam bir kopyasını oyun dünyasında 3D bir gizmo (oklar + dönme halkası) ile
taşıyıp döndürerek yerleştirsin; ne göreceğini görerek koysun.

## Hedefler

- Location bölümündeki X/Y/Z/Heading kutuları ve "Use my position" kalkar; yerine **Set machine position** butonu ve altında seçili
  konumun salt okunur özeti (x, y, z, heading) gelir. **Area label** kutusu kalır.
- Butona basınca admin paneli gizlenir, oyuncunun önünde formda seçili modelin **yarı saydam** bir kopyası (hayalet) belirir.
- Hayaletin üstünde three.js ile çizilen bir gizmo: **taşıma okları (X, Y, Z)** ve **dönme halkası (sadece dikey eksen / heading)**.
- **Yere sabitle**: bir tuşla (ve panelde bir butonla) hayalet o anki yerinden aşağıdaki zemine oturtulur. *(Benim kararım: tuş `G`.)*
- Ekranın **sol üstünde küçük bir panel**: anlık x/y/z/heading, Taşı / Döndür geçişi, Yere sabitle, tuş ipuçları, **Onayla** ve **İptal**.
- Admin yerleştirme sırasında **karakteriyle yürüyebilir**; bir tuşla (Left Alt) imleç (gizmo) ile serbest bakış arasında geçiş yapar.
- **Onayla**: panel geri gelir, form **olduğu gibi** durur (bütün doldurulmuş ayarlar korunur), konum yeni değerle dolar. Area label
  boşsa sokak adıyla dolar (bugünkü "Use my position" davranışı). **İptal**: panel geri gelir, konum değişmez.
- Aynı form hem **yeni makine** hem **makine düzenleme** ekranında kullanılır. Yeni makinede hayalet oyuncunun önünden başlar.
- **Düzenlemede sadece makinenin yanındaysan**: admin makineye `Config.Placement.editDistance` (varsayılan 10 m) içindeyse hayalet
  makinenin mevcut konumundan başlar ve yerleştirme süresince **gerçek makine gizlenir**; her bitişte (onay, iptal, ölüm, kaynak
  durması) geri gelir. Uzaktaysa yerleştirme açılmaz, "Go to the machine to move it" gibi bir uyarı gösterilir. *(Mesafe ve gizleme
  benim kararım.)*

## Hedef olmayanlar

- Harici bağımlılık yok: `object_gizmo` gibi bir kaynak gerekmez, gizmo bu kaynağın içinde yazılır. Başka kaynaktan kod kopyalanmaz.
- Eğme/yuvarlanma (pitch/roll) yok; makine sadece heading saklıyor.
- Serbest uçan kamera yok; admin kendi karakteriyle hareket eder.
- Sunucu tarafında değişiklik yok; kayıt bugünkü `admin:create-machine` / `admin:update-machine` yollarından geçer.

## Başarısızlık sayılacaklar

- Düzenlemede gerçek makinenin yerleştirme bitince görünmez kalması.

- Yerleştirmeden dönünce formdaki doldurulmuş ayarların (ad, model, sahiplik, fiyat, ürünler…) kaybolması.
- Gizmo oklarının/halkasının hayalet makinenin üstünde durmaması (kamera hareket ettikçe kayması).
- Yerleştirme bitince (onay, iptal, kaynak durması, admin ölmesi) hayaletin dünyada kalması ya da imleç/NUI odağının takılı kalması.
- Kaydedilen konumun, hayaletin gösterdiği yerden farklı spawn olması.

## Akış

1. Admin formda ayarları doldurur (ad, model…), Location'da **Set machine position**'a basar.
2. NUI istemciye seçili modeli ve (düzenlemede) makine id'sini gönderir. Düzenlemede admin makineden uzaksa istemci reddeder ve form
   bir uyarı gösterir. Yoksa istemci modeli yükler, yerel, çarpışmasız, yarı saydam bir hayalet oluşturur: düzenlemede makinenin
   yerinde (gerçek prop gizlenir), yeni makinede oyuncunun ~2 m önünde, oyuncuya bakar şekilde, yere oturtulmuş.
3. Admin paneli gizlenir (ama sayfa ve form **mount'lu kalır**, sadece görünmez olur), gizmo katmanı ve sol üst panel görünür.
4. Gizmo modunda imleç açıktır: oklarla X/Y/Z'de sürükleme, halkayla döndürme. Her değişiklikte istemci hayaleti taşır/döndürür;
   panelde değerler güncellenir. `G` (ya da panel butonu) hayaleti alttaki zemine oturtur ve gizmo yeni yere gelir. Left Alt: imleç kapanır, admin yürüyüp etrafa bakar; tekrar Left Alt ile imleç döner.
5. **Onayla** → istemci hayaleti siler, son x/y/z/heading'i (ve sokak adını) NUI'ye verir; form güncellenir, admin paneli geri gelir.
   **İptal** (panel butonu ya da ESC) → hayalet silinir, form değişmez, panel geri gelir.

## Teknik çerçeve (kararlaştırılanlar)

- Gizmo: web tarafına `three` paketi eklenir; NUI'de tam ekran, şeffaf bir three.js canvas'ı ve `TransformControls` kullanılır.
  three.js kamerası her karede oyunun o anki render kamerasıyla eşlenir (konum, rotasyon, FOV — istemci NUI'ye gönderir), hayaletin
  konumunda görünmez bir nesneye bağlı gizmo bu sayede hayaletin üstünde durur. GTA (z yukarı) ↔ three.js (y yukarı) eksen
  dönüşümü yapılır.
- NUI odağı: gizmo modunda `SetNuiFocus(true, true)` + `SetNuiFocusKeepInput(true)` ile admin yürüyebilir; Left Alt imleci (NUI fare
  odağını) açıp kapatır. Fare bakışı imleç açıkken kapalıdır.
- Hayalet: `CreateObject` ile yerel (ağsız), `SetEntityAlpha` ile yarı saydam, `SetEntityCollision(false)`, `FreezeEntityPosition`.
  "Yere sabitle" `PlaceObjectOnGroundProperly` kullanır (spawn ile aynı native, böylece kaydedilen yer spawn ile örtüşür).
- Config: yeni `Placement = { editDistance = 10.0 }`.
- Kod yerleşimi: istemci tarafı yeni `client/cl-placement.lua`; web tarafı admin sayfasının içinde yeni bir yerleştirme katmanı ve
  sol üst panel bileşeni. Admin paneli yerleştirme sırasında `v-show` ile gizlenir, unmount edilmez.
- Tema: veyra-ui.

## Proje kuralları

- Sadece istenen kod; ölü kod bırakılmaz (kalkan X/Y/Z kutuları, "Use my position" ve artık kullanılmayan `admin:get-position`
  callback'i / `getPosition` silinir — sokak adı onay cevabında gelir).
- Her Lua fonksiyonunda `@param` / `@return`; paylaşılan Lua tipleri `shared/_types.lua`'da.
- Commit yalnızca kullanıcı isterse.

## Builder'a kalanlar

- Kamera eşleme ve eksen dönüşümünün matematiği, `TransformControls` ayarları (sadece X/Y taşıma, sadece dikey eksen dönme).
- Sol üst panelin tam düzeni ve tuş ipuçları; Taşı/Döndür için klavye kısayolu olup olmayacağı (yürümeyle çakışmamalı).
- Hayaletin saydamlık değeri, oyuncunun önünde başlama mesafesi.
