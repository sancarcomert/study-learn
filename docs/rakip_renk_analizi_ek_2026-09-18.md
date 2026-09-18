# Rakip Renk Analizi — Ek Tur: Yeni Rakipler + Küresel "Sıcak Minimalizm" Doygunluk Kontrolü (2026-09-18)

`rakip_gorsel_renk_analizi_2026-09-15.md`'nin devamı. O dosyadaki 6 rakip
(rabbit., Pakodemy, Ders Takip AI, Kopilot, Kunduz, Duolingo) hâlâ geçerli.
Bu tur iki soruyu cevaplıyor: (1) 15 Eylül'den beri Play Store'a yeni
girmiş/yüksek puanlı YKS rakipleri var mı, onlar da mı beyaz+doygun renk
kullanıyor? (2) Home ekranı için tasarladığımız "krem zemin + adaçayı yeşili"
konsepti — bu gerçekten farklılaşıyor mu, yoksa kendi klişesine mi
giriyoruz? Renkler gerçek Play Store ekran görüntülerinden `fetch` +
canvas `getImageData` (24×24 ızgara) ile örneklendi — göz kararı değil.

## 1. Yeni Türk YKS rakipleri (piksel doğrulamalı)

| Uygulama | Puan/İndirme | Zemin | Baskın vurgu | Not |
|---|---|---|---|---|
| **Netify: YKS, TYT & AYT** | 4,9★ · 100B+ indirme, 9,92B yorum | Koyu mor `#601090`, neredeyse siyah `#000000` | **Çok renkli aynı anda**: kırmızı `#F03020`, mor `#7030E0`, camgöbeği `#10B0F0`, sarı `#F0C000` | Maskot karakterli (maymun), Duolingo tarzı "yol/harita" ilerleme, oyunlaştırma çok baskın. En yüksek puanlı yeni rakip — pazar buna ödül veriyor. |
| **Cep Dershanesi: YKS TYT AYT** | 4,7★ | Beyaz `#F0F0F0` | Turuncu `#F09000` | Standart "beyaz + tek doygun vurgu" kalıbı, sürpriz yok. |
| **TUDU: YKS, TYT, AYT Soru Çöz** | 4,8★ | Beyaz `#F0F0F0` | Koyu indigo-mavi `#3040C0` | Aynı kalıp, vurgu rengi farklı. |

**Sonuç:** 3 yeni rakip de 15 Eylül bulgusunu birebir doğruluyor — YKS
kategorisinde zemin ya **beyaz + tek doygun vurgu** ya da **koyu +
çok-renkli oyunlaştırma** (Netify, Duolingo). İkisi de "krem/sıcak nötr +
tek pastel vurgu" değil. En yüksek puanlı yeni giriş (Netify, 4,9★) en
gürültülü/oyunlaştırılmış olanı — bu, "sakin/sade" yönünün Türkiye YKS
pazarında test edilmemiş bir bahis olduğunu, "kanıtlanmış kaybeden" bir
yön olmadığını gösteriyor, ama pazarın ödüllendirdiği şeyin de tam tersi
(yüksek enerji/oyunlaştırma) olduğunu unutmamak lazım.

## 2. Küresel "sıcak minimalizm" gerçekten var mı? (varsayımı test ettim)

Home ekranı mockup'ında kullandığım "krem zemin + adaçayı yeşili vurgu"
kavramının prodüktivite dünyasında ne kadar yaygın olduğunu üç tanınmış
uygulamada test ettim:

| Uygulama | Beklenen | Gerçek (piksel örneklemesi) |
|---|---|---|
| **Tiimo** (ADHD-dostu günlük planlayıcı, "sıcak/pastel" imajıyla bilinir) | Krem/pastel | Beyaz zemin + **doygun periwinkle-mor** `#7050C0` marka rengi |
| **Sunsama** (profesyoneller için günlük planlayıcı) | Sıcak nötr | Beyaz/açık gri zemin + **doygun mor** `#A080F0` pazarlama çerçevesi + turuncu `#F0B040` ikon vurgusu |
| **Structured – Daily Planner** (1M+ indirme, 4,6★) | Sıcak minimalizm | Pastel ama **çok renkli** (lacivert/mercan/hardal/adaçayı bir arada, öğe başına farklı renk) — tek muted vurgu değil |

**Sonuç:** Tasarladığımız "krem + tek adaçayı vurgu" kombinasyonu, gerçek
şeklinde neredeyse hiçbir gerçek uygulamada yok. Bu ya (a) gerçek bir
boşluk, ya da (b) daha çok Dribbble/marka-kimliği dünyasında yaşayan,
gerçek üründe nadiren birebir uygulanan bir "ideal" — ikisi de mümkün,
aşağıdaki 3. bölüm ayrımı netleştiriyor.

## 3. Kritik bulgu: "adaçayı yeşili" tam da şu anda (Eylül 2026) klişe ilan ediliyor

Canlı web araması, tasarım söyleminde aktif bir tepki olduğunu gösterdi:

- Adaçayı yeşili tasarımcılar tarafından **"yeni millennial gri"** olarak
  tanımlanıyor — güvenli ve öngörülebilir hale geldiği, diğer yeşil
  tonlarının sahip olduğu derinlikten yoksun olduğu belirtiliyor.
- Bir tasarım uzmanı doğrudan şunu söylüyor: *"O spesifik yumuşak
  adaçayı/okaliptüs tonu yeterince kullanıldı, artık ara vermenin
  zamanı."*
- Daha geniş bağlamda 2026, tasarımcıların "jenerik minimalizme" karşı
  açıkça isyan ettiği bir yıl olarak tanımlanıyor — "aynı beyaz zemin,
  aynı yuvarlak köşeli sans-serif buton" yorgunluğu.
- Adaçayının yerini alan tonlar: **daha derin/zengin yeşiller** (koyu
  zeytin, jade tonlu celadon), toz mavisi-yeşiller, topraksı kahve-yeşiller
  — "daha kalıcı, daha az trend-bağımlı" olarak tanımlanıyor.

**Kaynaklar:**
[The End of Minimalism — Medium](https://medium.com/@Rythmuxdesigner/the-end-of-minimalism-why-anti-minimalist-design-is-taking-over-in-2026-b66e93b5ab50) ·
[What's Replacing Sage Green In 2026 — House Digest](https://www.housedigest.com/2176726/what-is-replacing-sage-green-trend-2026/) ·
[Sage Green Is So 2025 — Homes & Gardens](https://www.homesandgardens.com/interior-design/celadon-green-trend) ·
[8 Mobile App Color Scheme Trends for 2026 — Envato](https://elements.envato.com/learn/color-scheme-trends-in-mobile-app-design)

## 4. Sonuç ve öneri

1. **Renk tonu (sakin, tek vurgu, doygun değil) fikri hâlâ doğru** — hiçbir
   YKS rakibi bunu yapmıyor, gürültüden ayrışıyor.
2. **Ama spesifik "krem zemin + pastel adaçayı" kombinasyonu iki yönden de
   riskli:** (a) YKS rakiplerinin çoğunluğuyla aynı "beyaz zemin" kovasına
   düşürüyor, (b) küresel tasarım söyleminde tam da şu anda "bitmiş trend"
   ilan ediliyor — şimdi benimsemek, düşüşe geçen bir dalgaya binmek demek.
3. **Dodom'un gerçek uygulamadaki mevcut hali (Midnight Dark + Champagne
   Gold) hem YKS kategorisinde hem küresel trend söyleminde hâlâ boş bir
   konum** — hiçbir rakip koyu+sıcak temayı birleştirmiyor, gold hiçbir
   yerde marka rengi değil, ve "koyu tema" zaten trend yorgunluğu
   tartışmasının dışında (tartışma açık/beyaz minimalizm üzerine).
4. **Eğer mockup'taki "sakin/tek-vurgu" dersini illa taşımak istersek:**
   pastel adaçayı yerine daha derin/topraksı bir ton (koyu zeytin, is
   gibi bir clay/terracotta, ya da mevcut champagne gold'un kendisi) —
   "derinliği olan, trend-bağımlı olmayan" tonlar öneriliyor, tam da
   Dodom'un zaten sahip olduğu gold'un niteliği.

**Kısaca: mockup'ın tasarım disiplini (tek odak, bol boşluk, tutarlı tek
vurgu) gerçek uygulamaya taşınmaya değer bir ders — ama krem zemin ve
adaçayı rengi, ne rakiplerden ayrıştırıyor ne de "modern" hissettiriyor;
tam tersine, şu an global ölçekte "bitmiş" ilan edilen bir kombinasyon.**
