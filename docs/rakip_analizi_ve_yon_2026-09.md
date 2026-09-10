# Pusula — Rakip Analizi ve Yön Kararı (2026-09-10)

Bu belge web araştırmasına dayalı güncel bir pazar okuması + Pusula'nın nerede
durduğu + önümüzdeki plandır. `CLAUDE.md`, `app_colors.dart`, `app_text_styles.dart`
ve eski `Pusula Arayüz Spesifikasyonu` artifact'i ile birlikte okunur.

> Kaynaklar belgenin sonunda. Araştırma US-merkezli arama + App Store / Play Store
> sayfaları üzerinden yapıldı; indirme sayıları store'ların açıkladığı kadarıyla.

---

## 1. Şu an neredeyiz

**Ürün:** Flutter + Riverpod + Hive, yerel-only, backend yok. Android'de cihazda
test ediliyor. `master` trunk, GitHub yok.

**Biten iş (bu ve önceki oturumlar):**

- Görsel sistem: Midnight Dark + Champagne Gold, Lora/Jakarta gömülü font, buton
  hiyerarşisi, 9 ekran IA, alt nav.
- Seviye 1.5 yerel AI (LLM'siz): `plan_parser` (serbest metin → ders/tarih/saat/
  süre/tekrar), `study_advisor` (gerekçeli ders önerisi), `plan_builder` (plan
  çekirdeği), **Çalışma Koçu** (doğal dille sorar, "sen ayarla" → devralma modu).
- Konu Takip modülü (ayrı Hive box, 12 ders YKS konu kataloğu, kapsama %'si, AI'a
  bağlı: koç boş konulardan program çıkarır).
- Odak seansı: Serbest + Pomodoro modlu kronometre, geçmiş kaydı (`FocusSession`).
- İstatistik: çaba/süreklilik odaklı — çalışma takvimi ısı haritası, ders dağılımı,
  konu ilerlemesi, odak süresi. Sıralama tahmini / net baskısı bilinçli olarak yok.
- Onboarding + hedef ayarı, kişiselleştirme, carry-over dialog, profesyonelleştirme
  geçişi (saatsiz görevler, opsiyonel süre).
- `flutter analyze` 0 · `flutter test` 67/67 · `fl_chart` kaldırıldı (tüm grafikler
  özel widget).

**Elimizde ama kullanılmayan koz:** yerel planlama zekâsı. Ücretsiz rakiplerde yok,
paralı rakiplerde abonelik duvarının arkasında. Bizde çalışıyor, bedava, backend'siz.

**Zayıf noktamız:** dağıtım. Play Store'da değiliz, ASO yok, iOS yok. En iyi
planlayıcı bile kimse kuramıyorsa fark etmiyor.

---

## 2. Pazar haritası — 7 arketip (güncel)

TR sınav-hazırlık pazarında yedi tür var. Neredeyse hiçbiri arayüzü bir kimlik
olarak ele almıyor. Pusula'nın alanı tam burası.

### A) AI-maksimalist platform  ← en gürültülü kutup
**Pakodemy** (2M+ öğrenci iddiası, 23k+ yorum, ~4.7★, 2019'dan beri) ·
**Kopilot Pro** ("TR'nin ilk yapay zeka destekli koçluk platformu", 1M+ görüşme) ·
**Öğrenci Takip: YKS AI Koç** · **Ders Takip: AI Plan Odak Koçu**

- İş: AI soru çözme + AI sohbet ("7/24 AI öğretmen") + AI flashcard + günlük AI
  program + streak/ödül. Kopilot'ta ayda 1 insan koç görüşmesi.
- Gelir: abonelik. Ders Takip AI'da ₺49,99/ay → ₺899,99/6 ay arası çok katmanlı.
- Zayıf nokta: bilişsel yük yüksek, sürekli upsell, "her şey" olmaya çalışıyor.
  Ders Takip AI yorumlarında **veri kaybı bug'ları** (çalışma puanı uçuyor, geçmiş
  düzenlenemiyor, kronometre zıplıyor). Kopilot SikayetVar'da: Instagram reklam
  yemi, koç takip etmiyor, **onaysız karttan çekim**.
- Pusula'nın buradan öğrendiği: **bu yarışa girme.** AI ile ders anlatma / soru
  çözme = `CLAUDE.md` kesin yasağı. Rakip 2M kullanıcıyla burada; onları özellikte
  değil, dürüstlük ve cilada geç.

### B) Tam hizmet koçluk
**Kunduz** (1:1 koçluk, canlı ders, deneme kulübü, sınırsız soru çözüm) ·
**Baykuş Mentörlük** · **Kopilot** · **Ünikazan**

- Fiyat: online YKS koçluğu piyasada **aylık 2.500–5.000 TL** (12 taksit).
- Zayıf nokta: pahalı, SikayetVar dolu (SMS spam, söz verilen takip yapılmıyor,
  ödeme sorunları). Güven açığı büyük.
- Pusula'nın buradan öğrendiği: **fiyat + güven** açığı var. "Koç satmıyoruz,
  verini istemiyor, aylık bir kahve parası" konumu boş duruyor.

### C) Konu & deneme takibi
**YKS Konu Takip Çizelgesi** (3 durum: Çalışıldı / Soru Çözüldü / Tekrar Edildi) ·
**YKS Deneme Takip - Analiz** (Pandorina) · **Deneme Sınavı Takibi** (sonraki 6
denemeyi tahmin) · **Neon YKS** · **denemetakip.com** · **Konu Takip - YKS TYT**
(App Store)

- İş: konu checklist + deneme neti girişi + ders bazlı grafik + sıralama tahmini.
- Ton: elektronik tablo. Reklam + premium.
- Zayıf nokta: yoğun reklam, görsel kimlik yok, giriş sürtünmesi yüksek, kaygı
  üreten "sıralama tahmini".
- Pusula'nın buradan öğrendiği: Konu Takip modülümüz bunu **reklamsız + sakin**
  yapıyor. Deneme neti (E kararı) buraya girer — ama bizi "takip app'i"ne çevirme
  riski taşır.

### D) Geri sayım / sayaç + widget
**YKS Sayaç ve Widget** · **YKS Sayaç** · **Sınav Geri Sayım**

- İş: sınava kalan gün + motivasyon sözü + **ana ekran widget'ı**. Tek özellik.
- Zayıf nokta: günlük geri dönüş sebebi zayıf.
- Pusula'nın buradan öğrendiği: **widget** en ucuz sadakat kancası. `examDate`
  zaten var; bir sayaç + bugünkü görev widget'ı düşük maliyet, yüksek getiri.

### E) Ders programı / haftalık plan  ← en yakın tür
**YKS 2025: Takip & Planlayıcı** (Utku Uygun — ücretsiz, offline, kayıt yok, yerel
veri, "sade minimal arayüz", countdown + 10 günlük planlayıcı + deneme + grafik +
Pomodoro + dark/light; v1.0.2, düşük traction) · Play Store jenerik "Ders Programı"
/ "Çalışma Takvimi" app'leri

- Zayıf nokta: jenerik Material, kimliksiz, "kurulup unutulan". YKS 2025 Takip
  konumlama olarak **bizim ikizimiz** ama derinlik + tasarım yatırımı yok.
- Pusula'nın buradan öğrendiği: konumlama çakışması gerçek. Moatımız **icra
  derinliği** (yerel planlama zekâsı + Konu Takip + tasarım sistemi) — onların
  atmadığı adım.

### F) Çalışma süresi / odak
**YPT (Yeolpumta)** (kronometre + canlı grup + sıralama + 10-dk planlayıcı +
Pomodoro; ücretsiz, TR'de "study with me" kültüründe çok yaygın) · **Forest** ·
**Focus To-Do** · **Pomodoro Odaklanma Sayacı** · **Flip**

- Zayıf nokta: planlama yok; YPT'de sosyal baskı/sıralama bazı kullanıcıyı iter.
- Pusula'nın buradan öğrendiği: odak sayacı **meşru bir planlayıcı özelliği** (yasak
  değil) ve pazar talebi kanıtlı. Bizde zaten var — Pomodoro + geçmiş. Eksik olan
  "kapanış" hissi (bkz. plan B4).

### G) Tek-soru zaman takibi
**Ceyhun YKS — Süre Takip** (denemede soru başına süre, %100 cihazda, veri
toplamıyor, AdSense reklam)

- Niş ama ilgi çekici: **gizlilik**i pazarlama argümanı yapıyor. Pusula bunu daha
  ileri götürebilir (reklam bile yok).

---

## 3. Ortak zayıflıklar = Pusula'nın fırsatı

| Rakiplerin ortak sorunu | Pusula'nın cevabı |
|---|---|
| Reklam kalabalığı (ücretsiz katman) | Reklam yok, hiç |
| Agresif / şüpheli abonelik hunisi (koçluk) | Koç satmıyoruz; şeffaf, tek fiyat |
| Elektronik tablo yoğunluğu, sayfa başına çok karar | Ekran başına tek kral buton |
| Görsel kimlik yok — "jenerik Material + marka rengi" | Midnight Dark + tek altın, Lora serif |
| Koyu tema tutarsız, sonradan eklenmiş | Koyu tema **temel**, baştan tasarlandı |
| Veri kaybı bug'ları (paralı app'lerde bile) | Yerel + yedek + dışa aktar (bkz. A1) |
| Zorunlu hesap / kayıt sürtünmesi | Hesap yok, offline çalışır |
| Kaygı üreten "sıralama tahmini" | Sonuç değil çaba/süreklilik öne çıkar |
| "Her şey" olmaya çalışıp hiçbirini iyi yapmama | Kapsam sözleşmesi = ürünün kendisi |

**Tek cümle:** Pazarın tamamı gürültülüyken sakin, dürüst ve verini almayan tek
YKS planlayıcısı — bu konum boş.

---

## 4. Neden bir öğrenci Pusula'yı seçsin? (5 gerekçe)

1. **Sakin.** Açtığında ne yapacağın belli. Tek renk vurgu, tek aksiyon. Rakip
   dashboard'ları ilk saniyede nereye basılacağını söylemiyor.
2. **Güvenilir + senin.** Offline, hesapsız, reklamsız, SMS spam yok. Verin
   cihazında; yedeğini sen alırsın. "Ders Takip AI verimi sildi" yorumu bizde
   olmayacak.
3. **Dürüst kapsam.** Sahte "AI öğretmen" yok, 3.000 TL'lik koça upsell yok. Ne
   görüyorsan o. Bu, güven açığı olan bir pazarda bir pazarlama argümanı.
4. **Yerinde derinlik.** Yerel planlama zekâsı (koç + konu-farkında plan üretimi)
   ücretsiz app'lerde yok, paralı app'lerde abonelik arkasında. Bizde bedava,
   internetsiz.
5. **Çaba odaklı.** İstatistik seni sıralama tahminiyle korkutmaz; süreklilik ve
   emeği gösterir. 9–12. sınıf kitlesi için sürdürülebilir motivasyon.

---

## 5. Bizi öldürecek şeyler (riskler)

- **Dağıtım yokluğu.** #1 risk. Play Store'da değiliz. Özellik eklemeye devam edip
  yayınlamamak = boşa kürek. Bir sonraki büyük iş **feature değil, yayın**.
- **Kapsam kayması.** Her rakipte deneme takibi / forum / soru arşivi / AI sohbet
  var. "Bir tane daha ekleyelim" baskısı sürekli. Disiplin = ürün.
- **Solo dev bant genişliği.** Pakodemy'yi özellikte geçemezsin. Sadece zevkte
  (taste) geçebilirsin. Her yeni modül bu avantajı seyreltir.
- **Konumlama ikizi.** "YKS 2025 Takip" aynı "sade + ücretsiz + offline" sözünü
  veriyor. Onlar yatırım yapmıyor; bizim payımız icra. Yavaşlarsak fark kapanır.
- **iOS'ta yokluk.** Araştırma App Store'un TR'de güçlü olduğunu gösteriyor. Flutter
  çapraz platform; er ya da geç TestFlight.

---

## 6. Plan

### Katman A — Şimdi (0–2 hafta): güven + cila, SIFIR yeni kapsam

| # | İş | Neden |
|---|---|---|
| A1 | **Yerel yedek + "Verini Dışa Aktar (JSON)" + içe aktar.** Hive kutularını periyodik olarak cihaz dosyasına yaz; ayarlarda manuel dışa/içe aktar. Backend değil, dosya. | Ücretli rakiplerin bile #1 şikayeti veri kaybı. Bu bizim "asla olmaz"ımız olmalı. |
| A2 | **İlk 60 saniye turu.** Onboarding → ilk anlamlı aksiyon: kaç dokunuş, kaç saniye? Hedef < 3 dokunuş / < 30 sn. Boş durumlar, mikro-kopya, ilk açılış hissi. | "Sakin" iddiası ilk oturumda kanıtlanmalı. |
| A3 | Onboarding "Study Planner" → **"Pusula"** | Marka kararı, onay bekliyordu. |
| A4 | **Erişilebilirlik geçişi:** dokunma hedefi ≥ 48dp, kontrast AA, `prefers-reduced-motion`, TalkBack etiketleri. | Kalite sinyali + gerçek kullanıcı erişimi. |
| A5 | **Performans denetimi:** soğuk açılış < 2 sn, liste 60fps — düşük uçlu Android'de ölç. | Rakipler burada zayıf; ucuz kazanç. |
| A6 | **Tasarım tutarlılık denetimi** (bkz. §7). | Sistem "sistem" mi, yoksa 9 ayrı ekran mı? |

### Katman B — Sonraki özellikler (öncelik sırasıyla, hepsi yerel, kapsam içi)

1. **Ana ekran widget'ı** — (a) sınav geri sayımı, (b) bugünkü görevler / kalan
   süre. `examDate` + görev verisi zaten var. Pazarın en beklediği, en ucuz
   sadakat kancası; tek başına app olan bir kategori (D arketipi).
2. **Haftalık tekrarlı plan üretimi** — Koç şu an tek gün kuruyor. `plan_builder`
   konu-farkında; "önümüzdeki 7 gün" moduna çıkar (çok-güne konu dağıtımı +
   `examDate` yakınlığına göre yoğunluk). Konu Takip ile birleşince rakiplerin
   "AI program" iddiasına **yerel, ücretsiz, dürüst** cevap.
3. **"Bugünü kapat" ritüeli** — akşam kısa özet: bugün ne yaptın, seri durumu,
   yarına 1 cümlelik niyet. Forest/YPT'nin vermediği "kapanış" hissi. Ucuz,
   yapışkan, kimliğe uygun.
4. **Deneme neti takibi (E) — yalnızca ayrı karar verilirse.** Soru yok; sadece
   D-Y-net + trend. Ayrı Hive box, tek ekran, İstatistik'e trend kartı. 11–12.
   sınıf ile tam örtüşür, 9–10 için gereksiz. **Öneri: v1'de dahil etme** (bizi
   "planlayıcı"dan "takip app"ine kaydırır), ama mimariyi (ayrı box, ayrı typeId)
   engelleme. Widget + haftalık plan önce.

### Katman C — Yön / konumlama / dağıtım

- **Tek cümle konum (her yerde aynı):** *"YKS için sessiz planlayıcı — reklam yok,
  koç satmıyor, verin sende kalıyor."* Store açıklaması, onboarding, Hakkında.
- **Kapsam sözleşmesini ürüne yaz.** Hakkında ekranında: canlı ders yok · video yok
  · soru bankası yok · reklam yok · zorunlu hesap yok. Bu, her özellik kararında
  pusula (isim tesadüf değil).
- **Dağıtım — asıl darboğaz.** Play Store yayını + minimal ASO: ikon, 6 ekran
  görüntüsü (Midnight Dark güzel görünür), sade açıklama. Bir açılış sayfası ya da
  en azından Play linki. Bu olmadan B katmanı boşa kürek.
- **iOS:** Faz 1'den (Supabase) önce bir TestFlight değerlendir. Flutter zaten
  hazır; ROI yüksek olabilir.
- **Faz 1 (Supabase) ne zaman:** ancak (a) Play'de gerçek kullanıcı + geri bildirim
  varsa **ve** (b) abonelik için "yeter derecede iyi" ürün hissi oturduysa.
  Backend'i erken kurmak solo dev için ölüm. P1–P3 ile Faz 1 paralel yürütülmez
  (`CLAUDE.md`).

---

## 7. Tasarım yönü

**Koru (değişmez):** Midnight Dark + Champagne Gold · Lora (serif başlık) + Plus
Jakarta Sans (body), gömülü · ekran başına tek kral buton · `_outlined` ikonlar ·
bento kartlar · ders paleti 6 desatüre pastel (altın asla ders rengi değil).

**Sıkılaştır (A6 denetimi):**

- **Token disiplini:** 9 ekranda köşe yarıçapı / boşluk / gölge fiilen token'dan mı
  geliyor, yoksa elle sayı mı girilmiş? Spec'teki tabloya karşı koda bak.
- **Boş durumlar bir sistem mi?** `EmptyStateCard` birleşti — her ekran onu mu
  kullanıyor, yoksa hâlâ tek tük özel boş durum var mı?
- **Hareket dili:** `TapScale` 0.96 / 100–200ms her dokunulabilir öğede mi, yoksa
  bazı yerlerde ham `InkWell`/`GestureDetector` mi?
- **Tipografi ölçeği:** kaç farklı `fontSize` fiilen render ediliyor? 5–6'yı
  geçiyorsa buda. `app_text_styles` dışında elle `TextStyle(fontSize:)` var mı?
- **İkon boyutu:** 18 / 20 / 24 kuralı tutuyor mu, yoksa 16 / 22 / 28 kaçakları mı
  var?

**Ekle:** "sakin" ölçülebilir olmalı — ilk açılış → ilk anlamlı aksiyon: dokunuş
sayısı ve süre. Bunu bir kez ölç, hedef koy (< 3 dokunuş / < 30 sn), regresyon
olursa fark et.

---

## 8. Başarı ölçütü (doğru yönde miyiz?)

- **D7 geri dönüş oranı** — planlayıcıda tek gerçek metrik. (Yayın sonrası Play
  Console'dan.)
- İlk oturumda **plan ya da görev oluşturan** kullanıcı %'si.
- Store puanı **≥ 4.5** ve yorumlarda tekrar eden tema: "sade / temiz / reklamsız /
  şık".
- **Kapsam sözleşmesi ihlali: 0.** (Canlı ders / video / soru bankası / reklam /
  zorunlu hesap eklenmedi.)
- Cila metrikleri: soğuk açılış < 2 sn, `flutter analyze` 0, testler yeşil.

---

## Kaynaklar

- [Kunduz YKS 2026 paketleri](https://kunduz.com/tr/paketler/yks-2026/) · [Kunduz ana sayfa](https://kunduz.com/tr/)
- [YKS Koçluk Fiyatları 2026-2027 — Atlas Rehberlik](https://www.atlasrehberlik.com/yks-kocluk-fiyatlari-2026-2027/)
- [Pakodemy: KPSS YKS LGS — App Store](https://apps.apple.com/tr/app/pakodemy-kpss-yks-lgs/id1481710296?l=tr) · [pakodemy.com](https://pakodemy.com/)
- [Pickledemy YKS Takip Planlama — Google Play](https://play.google.com/store/apps/details?id=com.pickle.program&hl=en_US)
- [Kopilot Pro — YKS Koçluk (Yapay Zeka)](https://kopilotrehberlik.com/urun-detay/kopilot-pro) · [Kopilot ana sayfa](https://kopilotrehberlik.com/)
- [Baykuş Mentörlük](https://www.baykusmentorluk.com/mentorluk/)
- [Kopilot Rehberlik şikayetleri — Şikayetvar](https://www.sikayetvar.com/kopilot-rehberlik) · [Baykuş Mentörlük — Şikayetvar](https://www.sikayetvar.com/baykus-mentorluk)
- [Ders Takip: AI Plan Odak Koçu — App Store](https://apps.apple.com/tr/app/ders-takip-ai-plan-odak-ko%C3%A7u/id1590300077?l=tr)
- [YKS 2025: Takip & Planlayıcı — App Store](https://apps.apple.com/us/app/yks-2025-takip-planlay%C4%B1c%C4%B1/id6745474861)
- [YKS Dostum — App Store](https://apps.apple.com/hn/app/yks-dostum/id6755319810)
- [YKS Konu Takip Çizelgesi — Google Play](https://play.google.com/store/apps/details?id=com.ykstakip&hl=tr)
- [YKS Deneme Takip - Analiz (Pandorina) — Google Play](https://play.google.com/store/apps/details?id=com.pandorina.yks_deneme_takip&hl=en_US)
- [Deneme Sınavı Takip — Google Play](https://play.google.com/store/apps/details?id=com.sinav.takip&hl=en_US) · [Neon YKS — Google Play](https://play.google.com/store/apps/details?id=com.ei.neonyks&hl=en_US)
- [denemetakip.com](https://www.denemetakip.com/)
- [Ceyhun YKS — Süre Takip](https://ceyhunyks.com/)
- [YPT — Study Group (MWM)](https://mwm.ai/apps/ypt-study-group/1441909643)
- [Öğrenci Takip: YKS AI Koç — Google Play](https://play.google.com/store/apps/details?id=com.koctakip.app&hl=en_US)
- [YKS Sayaç ve Widget — App Store](https://apps.apple.com/us/app/yks-saya%C3%A7-ve-widget/id1536300435)
- [Konu Takip - YKS, TYT — App Store](https://apps.apple.com/tr/app/konu-takip-yks-tyt/id1447372131?l=tr)
- [Pomodoro Tekniği ile YKS — Gedik Üniversitesi](https://aday.gedik.edu.tr/blog/pomodoro-teknigi)
- [YKS'ye faydalı 7 mobil uygulama — Webtekno](https://www.webtekno.com/yks-mobil-uygulamalar-android-ios-h106549.html)
- [Ders çalışma uygulamaları listesi — Tamindir](https://www.tamindir.com/liste/ders-calisma-uygulamalari/)
