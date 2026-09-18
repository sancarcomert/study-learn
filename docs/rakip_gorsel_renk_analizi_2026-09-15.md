# Rakip Görsel/Renk Analizi — Ekran Görüntüsü Bazlı (2026-09-15)

`rakip_analizi_ve_yon_2026-09.md` ve `pusula_savas_plani_2026-09.md`'deki
renk gözlemleri **yazılı izlenimdi**. Bu doküman aynı rakiplerin gerçek
Play Store / App Store ekran görüntülerinden piksel örneklemesiyle (canvas
`getImageData`, 48×48 ızgara, en sık geçen 8 renk) çıkarılan **doğrulanmış**
hex değerlerini ve göz gözlemiyle yerleşim/boyut notlarını içerir. Kaynak:
gerçek mağaza sayfaları, bu oturumda ziyaret edildi.

## 1. Rakip renk paletleri (doğrulanmış)

| Uygulama | Zemin | Birincil vurgu | İkincil/kart | Not |
|---|---|---|---|---|
| **rabbit.** (Play) | `#000000` / `#181818` (iki katmanlı koyu gri-siyah) | Amber çizgi — o kadar az kullanılıyor ki 48×48 örneklemede bile üst-8'e girmedi (gerçekten "tek çizgi") | `#d8d8d8` açık gri metin/ikon | Neredeyse tam monokrom, doğrulandı. En yakın estetik rakip (koyu tema) ama duygusal sıcaklığı yok. |
| **Pakodemy** (Play) | `#ffffff` / `#f0f0f0` açık | `#0060d8`–`#0078d8` **kobalt mavi** (turkuaz değil — gerçek UI'da net mavi; turkuaz sadece ikon/marketing gradyanında) | Beyaz kart, ince gölge | Işıklı, doygun mavi; yüksek kontrast CTA'lar. |
| **Ders Takip AI** (App Store) | `#f0f0ff` açık lavanta + beyaz kart | `#f04830` **mercan-kırmızı** (doküman tahmini `#EE4035` ile pratikte örtüşüyor) | `#607890` gri-mavi ikincil metin | Her ekranda sabit ~%17-24 alan kaplıyor — marka rengi gerçekten baskın, kaçınılmaz. |
| **Kopilot Rehberlik** (Play) | Beyaz | `#78d8c0` / `#00c0a8` **mint/turkuaz yeşili** | `#f0f0f0` açık gri kart | Doküman bu rakip için renk notu içermiyordu — yeni bulgu. |
| **Kunduz** (Play) | `#f0f0f0` gri taban + ekran başına değişen pastel (şeftali `#fff0f0`, nane `#d8fff0`) | `#3078ff` **mavi** — her ekranda sabit ~%2-4, marka ipliği gibi | — | Marketing kartları Duolingo mantığına benzer "her özelliğe kendi pastel fonu" yapıyor, ama sabit mavi ipliğini koruyor. |
| **Duolingo** (Play) | Beyaz | **Yok — her ekran görüntüsü kendi doygun rengini taşıyor**: turuncu `#ff9000`, gökyüzü mavisi `#18a8f0`, mor `#d878ff`, altın `#ffc000` | Yeşil `#60d800` her ekranda sabit ikincil (marka/CTA ipliği) | Confirmed: "ders başına farklı renk" iddiası doğru, ama marka yeşili her yerde sabit kalıyor — tek renk kimliksiz değiller. |

## 2. Yerleşim / boyut gözlemleri (ekran görüntülerinden göz ölçümü)

- **rabbit.** alt navigasyon: 5 ikon + üstte etiket yok (yalnız ikon), ekran
  yüksekliğinin ~%10-11'i — Dodom'un kendi alt nav'ıyla (ikon+dolu-hap aktif
  gösterge) aynı büyüklük sınıfında, standart Android 56dp aralığında.
  Kartlar köşeli değil belirgin yuvarlak (~16-20dp) köşeli, tek katman
  (gölgesiz, kontrast zeminle ayrışıyor) — Dodom'un çok-gölgeli derinlik
  yaklaşımı burada YOK, rabbit. düzlük/flat'i tercih ediyor.
- **Pakodemy**: üstte diyagonal iki renkli (mavi/beyaz) blok kesimi (marketing
  kartlarında), gerçek UI ekranlarında ise standart üst app bar + beyaz kart
  listesi + belirgin yuvarlak ikon rozetleri (ders/yayınevi ikonları daire
  içinde). CTA butonları geniş, tam-genişlik, yuvarlak uçlu (pill).
  Sınıf yapısı Dodom'un card+icon-rozet desenine (`_ProfileRow`/`_InfoRow`)
  çok yakın — zaten bu desen doğru yönde.
- **Ders Takip AI**: kart köşe yarıçapı belirgin büyük (~20-24dp hissi),
  ikincil metin gri-mavi tonda (saf gri değil) — Dodok'un `textSecondary`
  yaklaşımına benzer bir "sıcak olmayan nötr" tercih.
- **Duolingo**: marketing ekran görüntülerinin HER BİRİ tek bir doygun renk
  bloğunu tam kadraj arka plan yapıyor (beyaz telefon çerçevesi ortada) —
  yani "ders başına renk" dedikleri şey gerçek uygulama içinde değil,
  ekran görüntüsü pazarlamasında da tekrarlanan bir sistem.

## 3. Dodom'un mevcut paletiyle konumlandırma (`lib/app_colors.dart`)

- `background #0F1115` + `surface #1A1C22` → **hiçbir rakipte koyu tema yok**
  (rabbit. hariç, o da soğuk/renksiz). Dodom bu boşlukta tek "sıcak koyu
  tema" konumunda — mevcut stratejik konumlandırmayla (savaş planı Moat 3)
  birebir örtüşüyor, değişiklik gerektirmiyor.
- `primary #D4AF6A` (champagne gold) → rakiplerin hiçbirinde altın/şampanya
  tonu yok (Pakodemy mavi, Ders Takip AI kırmızı, Kopilot mint, Kunduz mavi,
  Duolingo yeşil). Gold gerçekten **boşta bir renk kategorisi** — iyi seçim,
  dokunma.
- `vibrantMint #3DDC97` Kopilot'un `#00c0a8`'ine, `vibrantSky #4FC3F7`
  Pakodemy'nin `#0078d8`'ine kavramsal olarak yakın aile (mavi-yeşil
  spektrumu) ama **çok daha açık/pastel** — koyu zeminde doğru okunabilirlik
  için gerekli bir fark, karışma riski yok (zeminler taban olarak zaten
  100% farklı: onlar beyaz, Dodom siyah).
- `subjectPalette` (mor/teal/mavi/turuncu/pembe/turkuaz) Duolingo'nun
  "ders başına renk" mantığına yakın ama Duolingo'da bu marketing katmanında,
  Dodom'da gerçek uygulama içinde ders etiketleme olarak kullanılıyor — daha
  işlevsel bir uygulama, kopya değil.

## 4. Somut, eyleme dönük bulgular

1. **Renk tarafında acil bir boşluk yok.** Mevcut palet (gold CTA + koyu
   zemin + canlı kategori renkleri) rakiplerin hiçbiriyle çakışmıyor; en
   yakın estetik komşu rabbit. bile soğuk/monokrom kaldığı için Dodom'un
   "sıcak" konumu hâlâ boş. **Palet değişikliği önerilmiyor.**
2. **Kart/ikon-rozet deseni** (Pakodemy'nin daire-ikon + liste satırı) zaten
   Dodom'da `_ProfileRow`/`_InfoRow` ile var — bu yönde ek iş gerekmiyor.
3. **Gerçek fark yaratabilecek tek boyut notu:** rabbit. ve Pakodemy'nin
   ikisi de düz/flat kart kullanıyor (gölge neredeyse yok); Dodom'un çok
   katmanlı gölge + aurora arka plan dili zaten belirgin bir farklılaşma —
   bunu korumak (azaltmamak) rakiplerden ayrışmayı güçlendiriyor.
4. Boyut ölçümü (ör. buton yüksekliği, ikon px cinsinden) rakip ekran
   görüntülerinin çoğu pazarlama amaçlı telefon-çerçeveli/illüstrasyonlu
   olduğundan piksel-kesin ölçüm güvenilir değildi; güven aralığı yalnız
   "büyük kategori" seviyesinde (nav bar ~ekranın %10'u, kart köşe yarıçapı
   büyük/belirgin, CTA'lar tam-genişlik pill) — ileri düzey px ölçümü için
   gerçek cihazda rakip uygulamaları kurup incelemek gerekir (mağaza
   görselleri bunun yerine geçmez).

**Kaynaklar (bu oturumda ziyaret edildi):**
[rabbit. — Play Store](https://play.google.com/store/apps/details?id=com.ikbal.demir&hl=tr) ·
[Pakodemy — Play Store](https://play.google.com/store/apps/details?id=com.pakodemy&hl=tr) ·
[Ders Takip AI — App Store](https://apps.apple.com/tr/app/ders-takip-ai-plan-odak-ko%C3%A7u/id1590300077?l=tr) ·
[Kopilot Rehberlik — Play Store](https://play.google.com/store/apps/details?id=com.DBrakLYfAPgP.natively&hl=tr) ·
[Kunduz Online Eğitim — Play Store](https://play.google.com/store/apps/details?id=com.ngier.roket&hl=tr) ·
[Duolingo — Play Store](https://play.google.com/store/apps/details?id=com.duolingo&hl=tr)
