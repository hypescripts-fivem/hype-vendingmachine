# vend_screen DUI — Tasarım

Tarih: 2026-11-02

## Amaç ve neden

Custom (olentrix, `Config.Machines` içinde `arm = true`) makinelerde satın alma, tam ekran NUI menüsü yerine makinenin kendi
ekranından yapılsın. Makine modelinde `vend_screen` adlı bir ekran dokusu var; o doku bir DUI ile değiştirilir, oyuncu kamerayla
ekrana odaklanır ve fareyle ekrandaki tuşlara basarak sipariş verir. Böylece cam arkasındaki raflar ve ürünü tepsiye taşıyan kol
ile birlikte, satın alma da makinenin "içinde" geçer.

## Hedefler

- `arm` makinelerde "Aç" (target / TextUI birincil tuş) bu akışı açar. Normal GTA makineleri bugünkü NUI menüsünü kullanmaya devam eder.
- Oyuncu etkileşime girince bir script kamerası makinenin `vend_screen` yüzeyine odaklanır; imleç görünür olur ve tıklamalar DUI'ye gider.
- DUI ekranı veyra-ui temasıyla (monokrom, beyaz vurgu, Plus Jakarta Sans) çizilir.
- Ürün kartları, sepet, hızlı sipariş ve ödeme ekranın içinden yapılır.
- Ödeme başarılı olunca kamera kapanır ve oyuncu kolun ürünü tepsiye taşımasını izler (bugünkü `arm` akışıyla aynı).

## Hedef olmayanlar

- Normal (arm olmayan) makinelerin akışını değiştirmek.
- Kimse kullanmazken ekranda bir şey göstermek, ya da başka oyuncuların bu oyuncunun ekranını görmesi. *(Benim kararım: ekran sadece
  kullanan oyuncunun istemcisinde, kullanıldığı sürece canlanır; kapanınca orijinal doku geri gelir.)*
- Kategori filtresi, arama, ürün açıklaması gibi bugünkü mağazada olan ama burada istenmeyen ekstralar.
- Owner menüsü / makine satın alma (`purchase`) akışını DUI'ye taşımak; onlar bugünkü NUI'de kalır.

## Başarısızlık sayılacaklar (çalışsa bile)

- Tıklamaların ekrandaki tuşa denk gelmemesi (imleç ile DUI koordinatları kayıyor).
- Ekranın bulanık/okunmaz olması ya da kameranın ekranı kadrajlamaması.
- Bir sipariş iki kere alınabilmesi ya da sunucunun bugünkü kontrollerinin (stok, fiyat, ödeme yöntemi, para, mesafe) atlanması.
- Kamera / DUI kapandıktan sonra imlecin, kontrollerin ya da dokunun takılı kalması.

## Kullanıcı akışı

1. Oyuncu `arm` makineye gelir, alt-target'ta "Aç" der (TextUI'de birincil tuş).
2. İstemci sunucudan bugünkü `hype-vendingmachine:server:get-vending-data` ile veriyi alır (kapalı makine / reddedilen istek bugünkü gibi bildirim verir, hiçbir şey açılmaz).
3. Makinenin önünde bir script kamerası açılır, `vend_screen` yüzeyini kadrajlar. `vend_screen` dokusu DUI ile değiştirilir.
4. Oyuncu imleçle ekranda gezinir; tıklama, tekerlek ve imleç hareketi DUI'ye iletilir.
5. ESC / Backspace: kamera kapanır, doku eski haline döner, DUI yok edilir, kontroller geri gelir. Sepet kaybolur.
6. Ödeme başarılı olursa kamera kapanır (5'teki gibi temizlenir) ve kol ürünü tepsiye taşır.

## Ekran (DUI)

Onaylı taslak: `.superpowers/brainstorm/1182-1793625543/content/vend-screen-v3.html` (veyra-ui teması; emojiler yer tutucu,
gerçek ekranda envanter görselleri kullanılır). Daha eski `vend-screen.html` ve `vend-screen-v2.html` geçersizdir.

### Ürünler ekranı

- Ekran dikey (tablet gibi: kısa en, uzun boy); tam çözünürlük bilinmiyor. *(Benim kararım: DUI varsayılanı 3:4 dikey, ör. 900×1200,
  config'ten değiştirilebilir. Dikey olduğu için ızgara taslaktaki 3 yerine 2 sütun.)*
- Üstte makine adı.
- Ortada dikeyde kayan ürün kartı ızgarası.
- **Kart:** sol üstte ürün tipi (kategori) etiketi, ortada ürün görseli (envanter görseli, bugünkü `ShopItem` ile aynı kaynak),
  altta solda ürün adı, sağda fiyat.
  - Sepette değilse sağ üstte beyaz **sepete ekle (+)** butonu; basınca 1 adet eklenir.
  - Sepetteyse sağ üstte kırmızı **sepetten çıkar** butonu, hemen solunda `−  adet  +` stepper'ı. `−` 1'in altına inerse ürün sepetten çıkar.
    `+` kalan stoktan fazlasına izin vermez.
  - Sepetteki kartın çerçevesi hafif vurgulanır. Stoğu biten kart soluk görünür, eklenemez, "Stokta yok" yazar.
- **Altta sabit çubuk** (ızgara kaysa da hep görünür): solda sepetteki toplam adet ve toplam tutar; sağda **Sepet** butonu (adet rozeti)
  ve hemen yanında **Hızlı sipariş ver** butonu. Sepet boşken ikisi de pasif.

### Sepet ekranı

- "Sepet" butonuyla açılır. Her satırda: küçük görsel, ad, birim fiyat, `− adet +`, satır toplamı, sil butonu. Üstte "Temizle".
- Altta toplam, **Geri** (ürünlere döner) ve **Sepeti onayla**.

### Ödeme

- **Hızlı sipariş ver** sepet ekranını açmadan doğrudan ödeme adımına gider. **Sepeti onayla** da aynı ödeme adımına gider.
- Ödeme adımı bugünkü `CheckoutModal` ile aynı mantık: toplam, nakit/banka seçimi (sahibin kabul etmediği ya da yetmeyen yöntem pasif ve
  sebebi yazılı), hata mesajı, onay. Ekranın içinde bir katman/sayfa olarak çizilir.
- Sipariş bugünkü `checkout` yolundan geçer (`hype-vendingmachine:server:checkout`, aynı `items` + `payment`); sunucu tarafında değişiklik yok.

## Teknik çerçeve (kararlaştırılanlar)

- DUI, bu kaynağın kendi web build'inden açılır (`nui://hype-vendingmachine/web/dist/index.html` + bu ekranı seçen bir parametre).
  Yeni bir sayfa/görünüm olarak `web/src` içinde yazılır; bugünkü shop store mantığı (sepet, kalan stok, checkout) tekrar kullanılır.
- Doku değişimi: `CreateDui` + `CreateRuntimeTextureFromDuiHandle` + `AddReplaceTexture(<txd>, "vend_screen", ...)`; kapanınca
  `RemoveReplaceTexture` ve `DestroyDui`.
- Makine başına gereken değerler (ekranın hangi texture dictionary'de olduğu, kameranın makineye göre konumu/açısı/FOV'u, ekranın
  makine üzerindeki köşeleri veya boyutu, DUI çözünürlüğü) config'e girer ve oyunda ayarlanır. Tüm olentrix modelleri aynı gövdeyi
  kullandığı için tek ortak değer + gerekirse model bazlı üzerine yazma yeterli.
  *(Benim kararım: varsayılan txd her modelin kendi adı, yani gömülü dictionary.)*
  *(Benim kararım: değerleri ayarlamak için ayrı bir debug komutu / araç yazılmaz; değerler config'te elle ayarlanır.)*
  *(Benim kararım: ekranın konumu/boyutu ve doku çözünürlüğü bilinmiyor; config'e yer tutucu değerler yazılır, kullanıcı oyunda ayarlar.
  Fare eşlemesi bu yüzden kameranın kadrajına bağlı kalmamalı, config'teki ekran köşelerinden hesaplanmalı.)*
- Doku değişimi modelin dokusunu değiştirdiği için, kullanan oyuncunun istemcisinde yakındaki **aynı modeldeki diğer makineler de**
  aynı ekranı gösterir. *(Benim kararım: kabul edildi; kullanıcı özellikle `vend_screen` dokusunu istedi. Diğer oyuncular etkilenmez.)*
- Bu akış sadece istemcide; sunucu callback'leri ve olaylar aynen kalır. Checkout sonrası `HasShelf` ile sayfanın kapanması bu akışta
  kameranın kapanması olarak uygulanır.

## Proje kuralları (kullanıcının çalışma tercihi)

- Sadece istenen kod yazılır; ekstra özellik yok. Kullanılmayan / ölü kalan kod silinir.
- Her Lua fonksiyonunda `@param` / `@return` açıklamaları.
- Paylaşılan tipler `shared/_types.lua` içinde (ör. yeni `View` değeri ya da config tipi).
- Admin panelindeki model listeleri `web/src/stores/admin.ts` ile `Config.Machines` aynı tutulur (bugünkü kural).

## Builder'a kalanlar

- Fare koordinatlarını ekrandan DUI'ye eşleme yöntemi (sabit kamera kadrajından doğrudan eşleme, ekran köşelerini dünyadan ekrana
  izdüşürme ya da raycast) — yeter ki tıklamalar tuşlara denk gelsin.
- DUI sayfasının Lua ile haberleşme yolu (DUI mesajları / NUI callback'leri) ve bugünkü `FetchNUI` / `isNative` yapısına nasıl oturacağı.
- Kamera geçişi (yumuşak ya da anlık), DUI çözünürlüğü, imleç görünümü, kamera açıkken kapatılacak kontroller.
- Görünüm metinleri için locale anahtarları.
