# Pusula Savaş Planı — Kum Tanesinden Uzaya (2026-09-11)

Bu belge `rakip_analizi_ve_yon_2026-09.md` ve `pazar_arastirmasi_ve_ai_karari_2026-09.md`'nin
üzerine inşa edilmiş, 3 paralel araştırma turuyla (fiyatlandırma mimarisi, UI/UX + dark
pattern anatomisi, şikayet madenciliği) derinleştirilmiş bir strateji dosyasıdır. Önceki
iki belgeyi tekrarlamaz — üstüne ekler. HTML/görsel versiyonu:
[Pusula Savaş Planı (Artifact)](https://claude.ai/code/artifact/0aff1cac-2205-4456-9c00-73df1327d17c).

---

## 1. Rakip Analizi & Değer Teklifi

### Doğrudan rakipler

**Kunduz — Tam hizmet koçluk.** Gerçek satış yazılım değil: "sınavı tek başına göğüslemiyorsun"
güvencesi — ebeveynin satın aldığı şey çocuğunun kaygısını devretme hissi.
- Core: 1:1 haftalık koçluk + sınırsız soru çözüm
- Secondary: 900+ saat canlı ders, KAI yapay zeka asistan
- Retention: Deneme kulübü (kargo!), 10 aylık taahhüt kilidi

**Pakodemy — AI-maksimalist içerik devi.** Gerçek satış "her şey burada, kaybolma riski yok" —
2M+ kullanıcı sosyal kanıtıyla FOMO satıyor, AI ikinci planda.
- Core: 750B soru bankası, konu özetleri, flashcard
- Secondary: 10 katmanlı fiyat merdiveni (₺49,99 → ₺10.999)
- Retention: Nakit çekiliş + Türkiye ligi (kumar-benzeri hook)

**Ders Takip AI — Kişisel AI koç niş.** Gerçek satış "seni tanıyan bir program" — ama marka
rengi bile kırmızı: kaygıyı çözecek ürün kaygı rengi taşıyor.
- Core: AI günlük program, odak notu (harf notu)
- Secondary: iki paralel fiyat A/B testi aynı anda canlı
- Retention: Streak + "Seriyi Geri Getir ₺49,99" (kayıp-korkusu satışı)

### Dolaylı rakipler (ikame ürünler)

**Duolingo — global habit benchmark.** Gerçek satış yazılım değil *alışkanlık* — 3 dakikalık
günlük ritüel, öğrenme kalitesinden çok "bugün de yaptım" duygusu. Pusula'nın öğrenmesi
gereken ürün bu, rakibi değil. Can sistemi + streak = kayıp aversiyonu ders kitabı örneği.

**YPT (Yeolpumta) — sosyal odak/study-with-me.** Gerçek satış yalnız çalışma korkusu —
"birileri seni görüyor" sosyal baskısıyla disiplin satıyor. Planlama yok. Odak sayacı meşru
bir kategori — bizde zaten var, sosyal baskısı yok.

---

## 2. UI/UX Tasarım Anatomisi

> Not: Mağaza galerileri gerçek ödeme/paywall ekranını göstermiyor (Google Play politikası) —
> paywall gözlemleri yorum/web kaynaklı, cihazda doğrulanmadı.

### Renk teorisi + psikolojik algı

| Rakip | Palet | Algı |
|---|---|---|
| **rabbit.** | Neredeyse tam monokrom — siyah zemin, beyaz metin, tek amber çizgi net-grafiğinde | Premium, soğuk, ciddi. **Pusula'nın en yakın estetik rakibi** — ama duygusal sıcaklığı yok |
| **Pakodemy** | Turkuaz/mavi + parlak turuncu/kırmızı, 3D illüstre karakterler | Mavi=güven/teknoloji, turuncu=aciliyet. Çok renkli = çok karar yorgunluğu |
| **Ders Takip AI** | Mercan-kırmızı (#EE4035 civarı) **birincil marka rengi** | Kırmızı normalde uyarı/sil anlamı taşır — verimlilik ürününde istemsizce kaygı çağrıştırıyor, Pusula'nın "sakin" konumunun tam zıddı |
| **Duolingo** | Ders başına farklı parlak renk (mavi/yeşil/mor/sarı) + kırmızı can ikonu | Oyun hissi, anlık haz, çocuksu enerji |
| **Pusula** | Midnight Dark + tek Champagne Gold | rabbit.'in soğuk nötrlüğüne karşı sıcak/insani tek vurgu — bu pazarda hiç kimsede yok |

### Onboarding sürtünmesi

| Rakip | Kayıt zorunluluğu | Neden |
|---|---|---|
| rabbit. / Pakodemy | Yapısal olarak zorunlu | Arkadaş ekleme + lider tablosu çalışmadan önce hesap gerekiyor |
| Ders Takip AI | Muhtemelen erken | Veri güvenliği panelinde *finansal bilgi* topladığı beyan ediliyor |
| Duolingo | Kayıt olmadan 1. ders | Sektör istisnası — önce değeri göster, sonra "kaybetme" korkusuyla kayda ikna et |
| **Pusula** | Hiç yok | Offline, hesapsız — bu pazarda gördüğümüz hiçbir rakipte yok |

### Dark pattern / hook envanteri

- **Pakodemy (en somut kanıt):** "Test Çözerek Çekiliş Hakkını Katla" + gerçek zamanlı geri
  sayım sayacıyla 1000₺ nakit çekilişi — sahte aciliyet + değişken ödül aynı ekranda.
  Şikayetvar'da ayrı başlık: "Premium Üyelik Adı Altında Yanıltma".
- **Duolingo:** 14 gün ücretsiz deneme, fatura tarihinden 24 saat önce iptal edilmezse otomatik
  ücretlendirme. Play Store'da "bilgim dışında çekim yapıldı" şikayetleri — global bir devde
  bile bu pattern hayatta.

### Hook Model kırılımı (Tetikleyici → Aksiyon → Değişken Ödül → Yatırım)

| Rakip | Tetikleyici | Değişken Ödül | Yatırım |
|---|---|---|---|
| rabbit. | Arkadaşının çalışma durumunu görme | Sıralamada yükselme, podyum | Biriken saat verisi |
| Pakodemy | Soru çöz bildirimi | Nakit çekiliş, Türkiye ligi | Biriken çözüm sayısı |
| Ders Takip AI | Streak bildirimi | Ateş ikonu, harf notu yükselişi | Kaybetme korkusu (₺49,99 kurtarma) |
| Duolingo | Kalp/can azalması | "Mükemmel!" övgüsü, lig yükselişi | Streak + biriken XP |
| **Pusula (kasıtlı)** | Yok — sıralama/rekabet yok | Yok — kaygı üretmeyen tasarım kararı | Konu kapsama %, çaba geçmişi |

---

## 3. Fiyatlandırma Mimarisi ve Konumlandırma

Pazar iki ayrı kümeye ayrılıyor, arada neredeyse hiç ara katman yok.

### Küme A — Mikro-abonelik (₺50–200/ay)

| Ürün | Fiyat | Psikolojik taktik |
|---|---|---|
| Pakodemy — 24 Saatlik | ₺49,99 | Mikro-taahhüt, "sadece bugün dene" çerçevesi |
| Pakodemy — Premium (tam) | ₺999,99 | 10 katmanlı merdiven, her adımda "biraz daha öde, biraz daha al" |
| Ders Takip AI — Grup 1/ay | ₺49,99 (Grup 2: ₺199,99) | İki paralel A/B fiyat testi aynı anda canlı |
| Ders Takip AI — Seriyi Geri Getir | ₺49,99 | Saf kayıp-korkusu mikro-ürünü, abonelik bile değil |
| Duolingo — Yıllık (aya bölünmüş) | ≈₺81/ay | Aylık ₺139,99'a göre %42 ucuz gösterip günlüğe böl (₺2,7/gün) — "kahve parası" |

### Küme B — Koçluk (₺2.500–6.000/ay, taahhütte ₺30–60.000)

| Ürün | Görünen / Gerçek | Psikolojik taktik |
|---|---|---|
| Kunduz — Full Paket | ₺5.999,99/ay → ~₺60.000/10ay | Büyük yıllık taahhüdü küçük "aylık" rakama böl — Duolingo'nun tersi yönde aynı numara |
| Kopilot — YKS Koçluk (yıllık) | ₺36.490 (normal ₺48.699) | Sahte/anchoring indirim — "normal fiyat" hiç uygulanmamış referans |
| Ünikazan — "sınava kadar" taahhüt | ₺24.000'e çıkan vaka | Belirsiz bitiş tarihi = belirsiz toplam maliyet |
| Kopilot — resmi iade sözü | "14 gün koşulsuz" | Fiili: 159+ şikayette ₺2.800–24.300 arası iade reddi, %3 yanıt oranı — **vaat ile fiiliyat arasındaki makas pazarın en büyük güven açığı** |

### Pusula'nın konumu

Faz 0-1'de **₺0, sınırsız, taahhütsüz** — iki kümenin de tamamen dışında. "Koç satmıyoruz,
verini istemiyoruz" artık soyut slogan değil: Kunduz'un gizli 10 aylık taahhüdü, Kopilot'un
tutulmayan iade sözü ve Ders Takip AI'nin kayıp-korkusu mikro-satışı karşısında somut,
rakamlarla kanıtlanan bir zıtlık. İleride bir Faz 2 abonelik düşünülürse pazar verisi net:
"makul" bant **₺50–150/ay** — koçluk bandına (₺500+) yaklaşmak "koç satmıyoruz" konumuyla
doğrudan çelişir.

---

## 4. Rakiplerin Kritik Eksikleri & Kullanıcı Şikayetleri

### A) Teknik / veri güvenilirliği
- **Mentor: YKS Sosyal** — uygulamadan çıkınca hesap siliniyor, kronometre sıfırlanıyor
  (3,7★/111 yorum).
- **Ders Takip AI (iOS)** — "2-3 saatlik çalışmamı atıp puanımı vermiyor... tüm puanım gitti
  iki kere" — Android'deki bilinen veri kaybı bug'ı iOS'ta da tekrarlıyor (4,6★/152 yorum).
- **Kunduz** — "ders seçeneği görünmeme, test şık hataları" ayrı şikayet başlığı (Şikayetvar,
  532 şikayet, %99 yanıt).

### B) UX körlüğü
- **Pandorina** — net grafiği sabit 0–120 aralığında; 40'tan 60'a çıkan öğrenci için değişim
  görsel olarak neredeyse fark edilmiyor (50B+ indirme).
- **Neon YKS** — kullanıcılar 2021'den 2024'e kadar aynı isteği tekrarlıyor: denemeleri
  branş/genel diye ayıramıyorlar. Tek geliştirici kişisel yanıt veriyor ama özellik
  **3 yıldır gelmiyor**.

### C) Eksik temel özellik
- **Neon YKS** — deneme sonuçlarını grup/klasöre ayıramama, silememe, yedekleyememe.
- **YKS Dostum (iOS)** — tabletler arası senkron yok, hesap sistemi yok (4,6★/25 puan).
- **Ders Takip AI** — seans düzenleme/silme/durdurma kontrolleri hâlâ yok.

### D) Güven / ticari ilişki
- **Pandorina** — bu sene aniden "3 deneme sınırı" getirilmiş, branş denemesi başına ayrı
  reklam dayatılıyor ("20 mat branşı çözmüşüm, 17'si için 17 reklam izlemem gerekti").
  Play Store paneli: "Veriler şifrelenmiyor" + "Veriler silinemiyor".
- **Pakodemy** — "sürekli indirim olmuş gibi zam yapıldı" şikayeti. Şikayetvar'da marka
  profili bile açmamış, **hiçbir şikayete yanıt vermiyor**.
- **Kunduz** — Trendyol'dan alınan ₺800'lük kod teslim edilmemiş; iptal sonrası kart
  çekimlerinin devam ettiği vakalar var.

### E) Müşteri hizmetleri
- **Kopilot Rehberlik** — 160 şikayet, %3 yanıt. "Koçun ilgisiz olduğu, randevuları
  kaçırdığı" — iOS'ta da aynı tema (4,1★/129 yorum).

### Büyük oyuncuların yapısal kör noktaları

Bunlar bug değil — iş modelinin kendisinden kaynaklanan, düzeltilemeyen kısıtlar.

1. **Kunduz — eğitmen-pazaryeri modeli kilitlenmiş.** Eğitmen başına ödeme 2018'den beri
   40-50 kuruş/soru'da sabit (Ekşi Sözlük). Düzeltmek için ya fiyat artar ya kâr marjı erir —
   yapısal, çözülemez.
2. **Pakodemy — reklam + içerik yatırımı reklamsızlığı imkânsız kılıyor.** 750 bin soruluk
   içerik yatırımı, iş modelinin temeli. Reklamsız ürün = gelir motorunu kesmek.
3. **Kopilot — bire bir koçluk vaadi ölçeklenmiyor.** 2M+ oturumda %3 yanıt oranı. Kişisel
   takip vaadiyle kitlesel operasyon yapısal olarak çelişiyor.
4. **Küçük tek-geliştiricili uygulamalar — sürdürülemez gelirsizlik kendi tuzağını kuruyor.**
   Pandorina/Neon YKS: tek gelir reklam olunca ya aniden kısıtlama gelir ya basit istekler
   yıllarca bekler. **Pusula'nın da sıfır bütçe kısıtı var ama reklamsız + abonelik-tuzağı-yok
   konumu sayesinde bu spesifik tuzağa düşme riski yapısal olarak yok.**

---

## 5. Aradan Sıyrılma — GTM & Moat Stratejimiz

### 3 Kopya Edilemez Avantaj (Moat)

**Moat 1 — Anti-Kör Nokta Avantajı.** Kunduz eğitmen ücretini, Pakodemy reklam bağımlılığını,
Kopilot ölçeklenmeyen koçluğu yapısal olarak düzeltemiyor. Pusula küçük olduğu *için* bunların
hiçbirine sahip değil. *Neden kopyalanamaz:* büyük oyuncular düzeltmek için önce mevcut gelir
modellerini kırmak zorunda.

**Moat 2 — Yerel-Öncelikli Gizlilik.** Hiçbir rakip "verini almıyoruz, offline çalışıyoruz"
demiyor — hepsi hesap+senkron+veri topluyor. *Neden kopyalanamaz:* rakiplerin iş modelleri
(reklam hedefleme, büyüme metrikleri) veri toplamaya bağımlı.

**Moat 3 — Zevk (Taste) Avantajı.** Pakodemy'yi özellikte geçemezsin ama zevkte geçersin.
rabbit. en yakın estetik rakip ama soğuk/nötr — duygusal sıcaklığı yok. *Neden kopyalanamaz:*
zevk bütçeyle satın alınamaz, komite-tasarımının tam zıddı tek kişinin net bakış açısını
gerektirir.

### Katil özellik önerileri

1. **"Verin Sende" Şeffaflık Ekranı** — Pandorina'nın "veriler silinemiyor" beyanına ve
   Kopilot'un tutulmayan iade sözüne karşı doğrudan kontrast: "Sunucumuz yok, bu yüzden verini
   sızdıramayız" gibi somut, ölçülebilir cümleler.
2. **Temelde Doğru Yapılmış Basitlik** — Neon YKS 3 yıldır "filtrele/klasörle/yedekle"
   isteğini karşılayamıyor; Konu Takip + Deneme modülü + JSON yedekleme bunu zaten baştan
   doğru çözüyor — pazarlamada açıkça konumlandır.
3. **Arka Planda Kapanmayan Kronometre + Anlık Bildirim** — rakiplerin en çok övülen özelliği.
   Pusula'da OS-alarm tabanlı bildirim zaten var; Ders Takip AI'nin ₺49,99'luk "Seriyi Geri
   Getir" satışına karşı agresif satış içermeyen tek uygulama.

### Sıfır bütçeyle ilk 10.000 kullanıcı — 3 büyüme hilesi

1. **Şikayet Platformu Avcılığı** — Kunduz'un 532, Pakodemy'nin yanıtsız, Kopilot'un 160
   şikayeti = alternatif arayan, kanıtlanmış satın alma niyeti olan mutsuz kullanıcı havuzu.
   Şikayetvar/Ekşi Sözlük/Technopat'ta samimi/faydalı katkı yoluyla organik görünürlük.
2. **Paylaşım Kartı Viral Döngüsü** — P0-10'daki paylaşılabilir seri kartını 5-50k takipçili
   mikro-influencer study hesaplarına tohumlama stratejisiyle birleştir.
3. **Şikayet-Kaynaklı ASO** — "reklamsız YKS takip", "veri kaybetmeyen çalışma programı" gibi
   bu araştırmadan doğan somut arama niyetlerini Play Store metnine işle.

---

## 6. Aksiyon Planı Matrix'i

Mevcut Faz 1 (Play Store yayın hazırlığı) planına eklenecek somut maddeler.

| Aksiyon | Kaynak bulgu | Öncelik | Efor |
|---|---|---|---|
| Hakkında ekranına "Verin Sende" şeffaflık sayfası ekle | Pandorina + Kopilot güven açığı | P0 | Düşük |
| Play Store açıklamasına şikayet-kaynaklı anahtar kelimeleri işle | 532+160 şikayet, ortak temalar | P0 | Düşük |
| Konu Takip/Deneme'yi "rakiplerin 3 yıldır çözemediği" diye konumlandır | Neon YKS 2021-2024 | P0 | Düşük |
| Şikayetvar/Ekşi Sözlük/Technopat seeding planı hazırla | Şikayet platformu avcılığı | P1 | Orta |
| 5-10 mikro-influencer study hesabına tohumlama DM'i | Paylaşım kartı viral döngüsü | P1 | Orta |
| Play Store ekran görüntülerinde "sakin" iddiasını rabbit.'e karşı görsel kanıtla | rabbit. en yakın estetik rakip, sıcaklık eksik | P1 | Orta |
| Faz 2 abonelik fiyatlandırması için ₺50-150/ay bandı referans al | Mikro-abonelik vs koçluk sentezi | P2 | Düşük |
| iOS TestFlight değerlendirmesi | Ders Takip AI: Android 3,9★ vs iOS 4,6★ | P2 | Yüksek |

---

## Kaynaklar

**Fiyatlandırma:** [Pakodemy — App Store](https://apps.apple.com/tr/app/pakodemy-kpss-yks-lgs/id1481710296?l=tr) ·
[rabbit. — Play Store](https://play.google.com/store/apps/details?id=com.ikbal.demir&hl=tr) ·
[Ders Takip AI — App Store](https://apps.apple.com/tr/app/ders-takip-ai-plan-odak-ko%C3%A7u/id1590300077?l=tr) ·
[Kopilot Pro — satın alma](https://kopilotrehberlik.com/satin-alma-formu/kopilot-pro) ·
[Kunduz — paketler](https://kunduz.com/tr/paketler/yks-2026/) ·
[Baykuş Mentörlük](https://www.baykusmentorluk.com/) ·
[Ünikazan — paketler](https://unikazan.com/paketler/) ·
[Duolingo — App Store](https://apps.apple.com/tr/app/duolingo-dil-dersleri/id570060128?l=tr)

**Şikayet madenciliği:** [Kunduz — Şikayetvar](https://www.sikayetvar.com/kunduz-app) (532) ·
[Pakodemy — Şikayetvar](https://www.sikayetvar.com/pakodemy) ·
[Kopilot — Şikayetvar](https://www.sikayetvar.com/kopilot-rehberlik) ·
[Kunduz — Ekşi Sözlük](https://eksisozluk.com/kunduz--79347) ·
[Pakodemy — Ekşi Sözlük](https://eksisozluk.com/pakodemy--6501840) ·
[Neon YKS — Play Store](https://play.google.com/store/apps/details?id=com.ei.neonyks) ·
[Pandorina — Play Store](https://play.google.com/store/apps/details?id=com.pandorina.yks_deneme_takip) ·
[Mentor: YKS Sosyal](https://play.google.com/store/apps/details?id=com.msac.mentoryks) ·
[Technopat Sosyal — YKS önerisi](https://www.technopat.net/sosyal/konu/yks-calismak-icin-mobil-uygulama-onerisi.2730743/) ·
[Kunduz — DonanımHaber forum](https://forum.donanimhaber.com/kunduz-rezaleti-resmen-dalga-geciyorlar--129984084)

**UI/UX & dark pattern:** [Pakodemy — Play Store](https://play.google.com/store/apps/details?id=com.pakodemy&hl=tr) ·
[Pakodemy çekiliş şikayeti](https://www.sikayetvar.com/pakodemy/pakodemy-cekilis-ve-premium-uyelik-sorunu) ·
[Duolingo streak psikolojisi](https://www.justanotherpm.com/blog/the-psychology-behind-duolingos-streak-feature) ·
[Duolingo gamified growth](https://medium.com/@productbrief/duolingos-gamified-growth-how-a-green-owl-turned-language-learning-into-a-14-billion-habit-d47d9fa30a77) ·
[Onboarding best practices 2026](https://adapty.io/blog/how-to-fix-your-onboarding-flow/) ·
[Onboarding sürtünme kaynağı](https://scandiweb.com/blog/user-onboarding-best-practices/)
