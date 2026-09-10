# Pusula — Büyüme ve Yayın Planı (2026-09-10)

Bu belge, önceki iki dokümanın (`rakip_analizi_ve_yon`, `pazar_arastirmasi_ve_ai_karari`)
kararlarını **tek bir işletme planına** bağlar. Yol haritası kısımları artık buradan
yürür.

---

## 0. Hedef — net ve ölçülebilir

**Kullanıcının hedefi:** "TR'de ilk 100 uygulama."

**Gerçekçi çeviri (aynı hedef, ölçülebilir hali):**
- **Birincil:** TR **Eğitim kategorisinde ilk 100** — ilk YKS sezonu içinde
  (yayın → 2027 Haziran). Erişilebilir; Pakodemy/Tonguç/koçluk app'leri burada.
- **Gerinme hedefi:** YKS haftası (Haziran) zirvesinde **genel listede görünürlük**.
- Genel top 100 (tüm app'ler, sürekli) sıfır bütçeli niş bir app için ulaşılabilir
  değil — WhatsApp/banka/oyun bölgesi. Sezonsal sıçrama gerçek, kalıcı yer değil.

**Bunu neyle ölçeriz:**
| Metrik | İlk sezon hedefi |
|---|---|
| Toplam indirme | ≥ 25.000 (ilk 6 ay), sezon sonu ≥ 60.000 |
| D7 retention | ≥ %25 · D30 ≥ %12 |
| Play puanı | ≥ 4.5, yorumlarda tekrar eden tema: "sade / temiz / reklamsız" |
| Eğitim kategori sırası | Top 100 (gerinme: top 50) |
| Kapsam sözleşmesi ihlali | 0 |

---

## 1. Konum — tek cümle, kime

> **"YKS için sessiz planlayıcı. Reklam yok, koç satmıyoruz, verin sende kalıyor."**

**Kime:** Türkiye lise 9–12 + mezun. Sadece 12'ye değil — 9. sınıf da alışkanlık
kurabilsin (bu yüzden sınav-paniği merkezli değiliz).

**Neden bizi seçsinler (araştırmayla doğrulandı):**
1. **Sakin.** Rakip dashboard'ları ilk saniyede kafa karıştırıyor; bizde ekran başına tek aksiyon.
2. **Verini kaybetmezsin.** Pazarın #1 yarası (Ders Takip AI iOS 4.6 → Android 3.9). Bizde otomatik yerel yedek + dışa aktar.
3. **Dürüst.** Sahte "AI öğretmen" yok, 3.000 TL'lik koça upsell yok. Koçluk segmentindeki güven krizine (ŞikayetVar) karşı en güçlü koz.
4. **Çalışır.** Offline, hesapsız, reklamsız, SMS spam yok.

---

## 2. Ürün — yayına ne girecek (öncelik sırası)

**Biten** (bu oturum + öncesi): görsel sistem, Seviye 1.5 yerel AI + Çalışma Koçu
(cilalandı), Konu Takip, A1 yerel yedek, B1 widget, B2 haftalık plan, B3 "Bugünü
kapat", erişilebilirlik geçişi.

**Yayın öncesi yapılacaklar (Faz 0):**

| # | İş | Neden | Boyut |
|---|---|---|---|
| P0-1 | **Sınıf seçimi + kişiselleştirme** — onboarding'e 9/10/11/12/Mezun. Ton, günlük hedef varsayılanı, sınav dürtmesi, önerilen dersler buna göre. | "Her kullanıcı kendine göre" — kullanıcı isteği. 9 ≠ 12. | Küçük (`UserStatsModel` nullable alan) |
| P0-2 | **Seviye / rütbe merdiveni** — seri günü + tamamlanan görev + konu kapsamasıyla yükselen seviye (Yolcu → Çırak → Kalfa → Usta → Pusula). Home + Profil'de "sonrakine N görev". | "Tırmanacak hedef" ihtiyacı — rekabetin faydası, zararı yok. Herkes tırmanır. Hacme değil **sürekliliğe** bağlı → sahte saatle şişirilemez. | Orta (yeni izole modül, `user_progress` audit'te silinmişti, typeId 3 boşta) |
| P0-3 | **Seri draması** — "serin bugün kırılabilir, 1 görev yeter" bildirimi · 7/30/100 gün kilometre taşı kutlaması · widget'ta seri. | En güçlü retention mekaniği (Duolingo). Zaten seri + dondurma var, canlandır. | Küçük–orta |
| P0-4 | **"Bu hafta geçen haftandan öndesin"** satırı (Home + İstatistik). | "Şunu geçtim" hissi, kendine karşı. | Küçük |
| P0-5 | **Odak kronometresi arka planda + kalıcı bildirim.** | Rakiplerin #1 övgüsü ("uygulama kapalıyken de sayıyor"). Şu an ekran kapanınca kontrol edilmeli. | Orta (foreground service) |
| P0-6 | **Odak seansı: duraklat + geçmişi düzenle/sil.** | Rakiplerin #1 eksik-özellik şikayeti. `focus_sessions` box var, ekran yok. | Orta |
| P0-7 | **Bildirim metinlerini kişiselleştir** — kuru "Görev zamanı geldi" değil; "Günaydın 👋 bugün 2 blok var" / "Sınava 82 gün — bugünkü tek şey: türev". | rabbit'in tek gerçek övgüsü bildirimler. | Küçük |
| P0-8 | **İlk-60-saniye + boş durum cilası** — ilk açılış sıcak, boş durumlar sistemli. | "Ürün ince hissettiriyor" riskini kapatır. | Küçük |
| P0-9 | **Deneme / net takibi** — TYT/AYT D-Y-net girişi + trend grafiği. Soru YOK, sadece skor → kapsam çizgisini geçmez. | 11–12 + mezun (kitlenin yarısı) için temel beklenti; her rakipte var. "Kapsam kayması" endişesi abartılıydı. | Orta (yeni izole modül) |
| P0-10 | **Paylaşılabilir kart** — tek dokunuşla temiz görsel ("12 günlük serim 🔥" / "Bu hafta 18 görev"). Kutlama anında, nag değil. | Öğrenci story'sine atar → bedava dağıtım. | Küçük |

**Yayına GİRMEYECEK (kapsam sözleşmesi):** soru bankası · video içerik · **Türkiye-geneli
global lider tablosu** (küçük opt-in haftalık ligler Faz 3'te olabilir) · reklam ·
zorunlu hesap · LLM ile ders anlatan asistan.

---

## 3. Retention motoru

Ücretsiz app'in yakıtı retention + ağızdan ağıza. Kancalar:

1. **Seri + günlük döngü** (P0-3) — dön, işaretle, seriyi koru. En güçlü.
2. **Seviye merdiveni** (P0-2) — uzun vadeli "tırmanma" hedefi.
3. **Widget** (B1, bitti) — her telefon açılışında pasif hatırlatma, nag'siz.
4. **"Bugünü kapat" + sabah niyeti** (B3, bitti) — günlük ritüel.
5. **"Geçen haftanı geç"** (P0-4) — herkesin kazanabileceği yarış.
6. **Sonra (Faz 3):** opt-in, ~30 kişilik **haftalık lig** (Türkiye geneli liste
   yok) — lider tablosunun sağlıklı hali, backend ister.

---

## 4. Büyüme — sıfır bütçe, solo dev nasıl indirme alır

Reklam yok. Motor = **ASO + içerik + topluluk + sezon zamanlaması.**

### 4a. ASO (Play Store araması — bedava, en kritik)
- Başlık + kısa açıklama: "yks çalışma programı", "ders takip", "sınav sayacı",
  "pomodoro", "çalışma planı" anahtar kelimeleri doğal geçsin.
- **6 ekran görüntüsü** — Midnight Dark güzel çıkar. İlk 2 kare: konum cümlesi +
  "reklam yok / hesap yok / verin sende".
- İlk 20 puanı hızlı topla (kapalı test + arkadaşlar) — algoritma erken ivmeye bakar.
- Açıklamada "yapmadıklarımız" manifestosu — arama değil, **tıklayınca ikna** eder.

### 4b. İçerik (asıl büyüme motoru — TR study-tok/gram devasa)
Kullanıcı video/edit yapmayı kabul etti — iki koldan yürür:
- **Ekran-kaydı klipleri** (yüz yok, konuşma yok, ~10 dk iş): "widget böyle",
  "koça yazınca ne oluyor", "Bugünü kapat ritüeli". X / Reddit / Discord / Reels.
- **Tam kısa video** (gerekiyorsa): "study with me" + ekranda Pusula, "programımı
  nasıl kuruyorum", "reklamsız, verini almayan planlayıcı yaptım" (hikaye paylaşılır).
- **Tohumlama (en yüksek kaldıraç):** 5–50k takipçili study hesaplarına IG DM →
  app'i bedava ver, dürüst story/video atsınlar. Video reach'lerini ödünç alırsın.
- Tutarlılık > kalite. 3 ay istikrarlı post = dönüşen kitle. Bio'da tek link (Play).

### 4c. Topluluk (seeding — spam değil, gerçekten faydalı ol)
- r/YKS, YKS Discord sunucuları, ekşi, yksforum, Technopat — sorulara cevap ver,
  imzada/uygun yerde app'ten bahset.
- **Mikro-influencer tohumlama:** 5–50k takipçili study/YKS hesaplarına app'i
  bedava gönder, para verme. Gerçekten iyiyse bir kısmı paylaşır.

### 4d. Sezon zamanlaması
- **Eylül–Aralık:** okul açılışı, öğrenci rutinini kuruyor → **en yoğun itiş burada.**
- **Ocak–Nisan:** kriz dönemi, ikinci dalga.
- **Haziran (YKS haftası):** aramalar zirvede — hazır ol, sunucu (Faz 1 varsa) sağlam.

---

## 5. Para kazanma — sonra, nazik

- **Yayın: %100 ücretsiz, reklamsız, hesapsız.** Bu, büyüme stratejisinin kendisi.
- **Faz 3'te "Pusula Plus"** (Faz 1 backend sonrası): bulut yedek/senkron ·
  haftalık ligler · dar-kapsam LLM planlayıcı kotası. **Tek fiyat, ucuz, çekirdek
  plan hep ücretsiz.** Öğrenciye lazım olan hiçbir şey duvar arkasında değil.
- Fiyat rakamı **şimdi belirlenmez** — satılacak ürün olunca, 3.000 TL'lik koçlara
  karşı konumlanmış ("aylık bir kahve parası, taksitsiz, iptal kolay").
- **Asla:** reklam, veri satışı.

---

## 6. Zaman çizelgesi

| Faz | Ne | Kaba süre |
|---|---|---|
| **Faz 0 — Yayına hazırlık** | P0-1…P0-10 + Play kaydı, ikon, ekran görüntüleri, gizlilik politikası (veri toplamıyoruz → kolay), kapalı test | ~6–10 hafta (8+ madde, solo dev) |
| **Faz 1 — Yayın + büyüme** | Play'de yayın · ASO · haftalık 3–5 video · forum/discord seeding · mikro-influencer. Geri bildirime göre hızlı yamalar. | Sürekli, ilk 3 ay yoğun |
| **Faz 2 — Backend (Supabase)** | Ancak gerçek kullanıcı + geri bildirim varsa: Auth, şema, RLS, bulut yedek. | Faz 1'den ~2–3 ay sonra |
| **Faz 3 — Plus + ligler + LLM planlayıcı** | Para kazanma başlar. Haftalık ligler. Dar-kapsam LLM (sadece plan kurar). | Faz 2 sonrası |

**YKS sezonu (Ara–Haz)** büyüme itişinin yoğunlaştığı pencere — fazlar buna göre kaysın.

---

## 7. Başarı ölçütü (§0'ın tekrarı — panoya as)

- Eğitim kategorisi TR **top 100** (gerinme: top 50), ilk sezon.
- D7 ≥ %25 · Play ≥ 4.5 · yorumlarda "sade/temiz/reklamsız".
- İlk 6 ay ≥ 25.000 indirme.
- Kapsam ihlali: **0**.

---

## 8. Kapsam sözleşmesi (değişmez)

Canlı ders/koçluk · video içerik · soru bankası/çözme · LLM ile ders anlatan
asistan · reklam · veri satışı · zorunlu hesap · genel lider tablosu (Türkiye geneli).

Rakipte görülünce varsayılan cevap "ekleyelim" değil — §1 konumuna ve bu listeye bak.
