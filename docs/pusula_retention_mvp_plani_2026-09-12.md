# Pusula — Retention & MVP Sentezi (2026-09-12)

Bu belge, kullanıcının istediği 5 maddelik strateji raporunun cevabıdır. **Önemli düzeltme:**
istek metni "bizim projemiz Groq API (Llama 3.1) kullanan bir AI koç" diye tarif ediyordu — bu
yanlış, kod tabanında hiçbir API/ağ isteği yok (`coach_screen.dart`, `subject_ai.dart` —
tamamen yerel kelime-kökü eşleştirmesi, `CLAUDE.md`: "LLM YOK"). Bu belge **gerçek mimariye**
göre yazıldı ve önceki iki araştırma dosyasının (`rakip_analizi_ve_yon_2026-09.md`,
`pusula_savas_plani_2026-09.md`) üzerine inşa edilir, onları tekrarlamaz — sadece istenen 3 yeni
rakibi (Doping Hafıza, Ders Lig, MentalUP) ekler ve 5 maddeyi tek yerde sentezler.

---

## 1. Rakip özellik & retention matrisi (genişletilmiş)

Önceki araştırma 7 arketipi ve ~20 uygulamayı zaten kapsıyor (bkz. `rakip_analizi_ve_yon_2026-09.md`
§2). Buraya, istekte özellikle adı geçen ve önceki dosyalarda olmayan 3 uygulama ekleniyor:

| Uygulama | Ne sunuyor | Retention sırrı | Fiyat |
|---|---|---|---|
| **Doping Hafıza** | Video konu anlatımı + soru bankası + "Refleksler/İnfografik/Akıl Haritası/Hafıza Teknikleri" adında 5 farklı anlatım formatı + "Koçum Yanımda" (randevu/mesajlaşma) | **"Her Güne 1 Doping"** — günlük tek bir küçük görev/motivasyon kartı, düşük sürtünmeli günlük dönüş kancası | Yıllık paket, 5. sınıf 12.599 TL (aylık 1.049 TL taksit) → 9-12. sınıf tam paket 13.999 TL. **Koçluk bandına yakın, mikro-abonelik değil** |
| **Ders Lig (Derslig)** | Konu anlatımı + soru bankası + paketli üyelik | Yok denecek kadar zayıf — asıl "retention" mekanizması müşteri desteğine ulaşamama nedeniyle **negatif** (kullanıcı iptal edemiyor) | Paketli, örnek: 6 aylık "Öğrenci Paketi" iadesi 3.348 TL — yani aylık ~560 TL bandı |
| **MentalUP** | YKS'ye özgü değil (genel bilişsel gelişim) — 135+ zeka oyunu, IQ testi, kişiye özel günlük plan, gelişim grafiği | **"Bitmeyen hedef" tasarımı** — sabit bir final yok, sürekli yeni oyun/skor; çocuklar arası (ebeveyn hesabına bağlı 3 çocuğa kadar) karşılaştırma | Abonelik (aylık/yıllık, kurumsal indirim var) |

**Yeni bulgu — Doping Hafıza'nın "Her Güne 1 Doping"** önceki dosyalarda görülen Hook Model'e
tam uyuyor (Tetikleyici → günlük bildirim; Değişken Ödül → günün içeriği; Yatırım → biriken
seri) ama **düşük sürtünmeli** olması dikkat çekici: koçluk/soru bankası gibi ağır bir omurgaya
sahip olsa bile günlük dönüş kancası tek bir küçük kart. Bu, Pusula'nın zaten yapmayı planladığı
"widget + bugünkü görev" fikrini (bkz. `rakip_analizi_ve_yon_2026-09.md` Katman B1) doğrulayan
üçüncü bağımsız kanıt (Duolingo, YPT'den sonra).

**Ders Lig bulgusu**, önceki dosyadaki "D) Güven/ticari ilişki" temasını güçlendiriyor: iptal
edememe/iade sorunu, sadece koçluk devlerine (Kunduz, Kopilot) özgü değil, orta ölçekli
içerik-abonelik oyuncularında da var — Pusula'nın "hesap yok, iptal edilecek bir şey yok"
konumu daha da güçlü bir zıtlık.

**MentalUP bulgusu**, doğrudan rakip değil ama retention tasarımı açısından öğretici: "bitmeyen
hedef" — Pusula'nın kaygı üretmeyen çaba-odaklı istatistik felsefesiyle (`rakip_analizi_ve_yon`
§4.5) aynı yönde, farklı bir doğrulama.

---

## 2. Biz şu an neredeyiz — DOĞRU konumlandırma

İstekteki "20-30 MB, Groq/Llama, ücretsiz/limitsiz" tarifi yanlıştı. Gerçek durum, aslında
**daha güçlü bir konumlandırma** üretiyor:

| İstekte yazılan (yanlış) | Gerçek (kod tabanından doğrulandı) | Neden daha güçlü |
|---|---|---|
| Groq API / Llama 3.1 kullanıyor | **Hiçbir API çağrısı yok** — tamamen yerel kelime-kökü eşleştirmesi | Groq'un ücretsiz katmanı bile rate-limit'li ve şartları ticari üretim için garanti değil (bkz. bir önceki sohbet turu). Bizde **kesilecek bir servis yok** |
| "Tamamen ücretsiz/limitsiz" | Doğru ama sebebi farklı: ücretsiz çünkü **sunucu maliyeti sıfır**, kota değil | Rakiplerin "ücretsiz" katmanları hep kısıtlı (Pandorina: "3 deneme sınırı" sonradan geldi — bkz. `pusula_savas_plani` §4D). Bizde kısıtlanacak bir üçüncü parti maliyet yok, o yüzden geri alınamaz |
| 20-30 MB | Doğrulanmadı — gerçek APK boyutu ölçülmeli (build alıp kontrol edilebilir) | Sayı yanlış olsa bile yön doğru: video/ses/ML modeli yok, sadece Flutter+Hive+font, gerçekten hafif |
| "Eski telefonlarda kasmaz" | Muhtemelen doğru (hafif widget ağacı, external state yönetimi) ama ölçülmedi | `rakip_analizi_ve_yon` §6 Katman A5'te zaten planlı: "soğuk açılış < 2 sn, düşük uçlu Android'de ölç" — henüz yapılmadı |

**Asıl konum:** Türkiye'deki hantal/pahalı eğitim pazarının, "içerik + AI + koçluk" üçlüsünü
satan hiçbir oyuncunun dolduramayacağı bir boşluk — çünkü onların iş modeli bu üçlüye bağımlı.
Pusula **planlama + takip zekâsını içerik satmadan** veriyor. Bu konum `rakip_analizi_ve_yon`
§3'te zaten net: *"Pazarın tamamı gürültülüyken sakin, dürüst ve verini almayan tek YKS
planlayıcısı."*

---

## 3. En büyük 3 eksiğimiz (gerçek mimariye göre)

1. **İçerik/veri sıfırı.** Soru bankası, video anlatım, konu özeti — hiçbiri yok ve **hiçbiri
   olmayacak** (kapsam sınırı). Bir öğrenci "bu soruyu çöz" isteğiyle gelirse elimiz boş.
2. **Dağıtım/pazarlama bütçesi sıfır.** Play Store'da bile değiliz henüz — bu, `rakip_analizi_ve_yon`
   §5'te zaten "#1 risk" olarak işaretli.
3. **İnsan gücü sıfırı — güven inşası yavaş.** Rakiplerin çoğu (Doping Hafıza'nın "Koçum Yanımda"sı,
   Kunduz'un 1:1 koçu) bir *insan* vaadi satıyor. Biz hiç satmıyoruz — bu hem moat hem açık:
   "kimse bana gerçekten bakmıyor" hissi yaşayan bir öğrenciye Pusula'nın verecek bir cevabı yok.

**Yapay zeka/growth hacking ile maskeleme — gerçekçi sınır:** Önceki sohbet turunda net konuşuldu:
gerçek bir görsel/LLM tabanlı "içerik" çözümü hem mimariye hem kapsam sözleşmesine aykırı ve
kalıcı maliyet getirir. Maskeleme burada "daha fazla AI eklemek" değil, **zaten var olan yerel
zekâyı (plan_parser + study_advisor + plan_builder) pazarlamada içerik eksikliğinin karşı
argümanı olarak konumlamak**: "İçerik satmıyoruz çünkü onu zaten öğretmenin/kitabın veriyor;
biz sadece bunu organize ediyoruz — dürüstçe." Growth hacking tarafı zaten `pusula_savas_plani`
§5'te 3 somut hamle olarak var (şikayet platformu avcılığı, paylaşım kartı viral döngüsü,
şikayet-kaynaklı ASO) — bunları tekrar üretmek yerine oraya yönlendiriyorum.

---

## 4. En yıkıcı faydamız → rakip eksiklerini vurma planı

`pusula_savas_plani_2026-09.md` §3 ve §5'te bu zaten somutlaştırılmış (3 Moat + 3 katil özellik).
Buraya sadece bu oturumda eklenen 3 rakiple güçlenen kısmı ekliyorum:

| Rakibin zayıflığı (bu tur dahil) | Pusula'nın vuruşu |
|---|---|
| Ders Lig: iptal edilemeyen abonelik, ulaşılamayan destek | Hesap yok → iptal edilecek bir şey yok. "Verin Sende" şeffaflık sayfası argümanı burada da geçerli |
| Doping Hafıza: 12-14 bin TL'lik yıllık paket, aylık taksit gizlemesi (Duolingo'nun tersi — büyük toplamı küçük göstermek) | Pusula'nın Faz 0-1 fiyatı: ₺0. Rakamla kıyaslanabilir kontrast |
| MentalUP: YKS'ye özel değil, genel bilişsel — sınav kaygısına doğrudan cevap değil | Pusula'nın Konu Takip + Deneme neti tam YKS'ye özel, sınavın kendisine göre kalibre |

Buradaki gerçek katkı: **"Her Güne 1 Doping" gibi düşük sürtünmeli günlük kancalar, ağır/pahalı
bir omurgaya sahip uygulamalarda bile işe yarıyor** — yani Pusula'nın hafif mimarisiyle aynı
kancayı kurması hem daha kolay hem daha inandırıcı (arkasında satış baskısı yok).

---

## 5. Retention planı + MVP özellik listesi

### En hafif + en etkili 3 retention özelliği (öncelik sırasıyla)

1. **Ana ekran widget'ı (sınav sayacı + bugünkü görev sayısı).** Zaten planlı
   (`rakip_analizi_ve_yon` Katman B1). En ucuz sadakat kancası — uygulamayı **açmadan** günlük
   temas sağlıyor (D arketipi tek başına bunu satıyor). Hive'da veri zaten var, ek maliyet yok.
2. **"Bugünü kapat" akşam ritüeli.** Zaten var (`daily_closeout_provider.dart`, önceki oturumda
   yeniden tasarlandı) — kısa özet + yarına 1 cümlelik niyet. Doping Hafıza'nın "Her Güne 1
   Doping" kancasının aynadaki karşılığı: onlar sabah tek kart veriyor, biz akşam tek kapanış
   veriyoruz — ikisi de düşük sürtünmeli, kaygı üretmiyor.
3. **Hafif seri (streak) göstergesi — ödül/ceza YOK.** Mevcut `currentStreak`/`freezesAvailable`
   zaten var (Profil ekranında). Duolingo/Ders Takip AI'nin "Seriyi Geri Getir ₺49,99" tarzı
   kayıp-korkusu satışına **bilinçli olarak girmiyoruz** (`pusula_savas_plani` §2 Hook Model
   tablosu — Pusula satırı: "Yok — kaygı üretmeyen tasarım kararı"). Bunu değiştirmeyi önermiyorum;
   sadece varlığını retention listesine not ediyorum çünkü zaten çalışıyor.

**Neden 3'ü de "ücretsiz" (mimariye sıfır maliyet eklemiyor):** Hepsi mevcut Hive verisiyle
çalışıyor, hiçbiri backend/API gerektirmiyor — bu oturumun başındaki maliyet analizinin
doğrudan sonucu: retention'ı satın almak yerine **zaten sahip olduğumuz veriyi daha sık
yüzeye çıkararak** elde ediyoruz.

### MVP özellik listesi (mevcut durum + eksik tek parça)

Aşağıdaki tablo mevcut kod tabanına göre — "✅ var" olanlar zaten üretimde, "⬜ eksik" olan tek
kalem widget:

| Özellik | Durum |
|---|---|
| Yerel plan/görev yönetimi (ekle/tamamla/ertele/sil) | ✅ |
| Çalışma Koçu (doğal dil → plan, yerel) | ✅ |
| Konu Takip (12 ders YKS kataloğu, kapsama %) | ✅ |
| Odak seansı (Serbest + Pomodoro, geçmiş) | ✅ |
| Deneme neti takibi (TYT/AYT, trend) | ✅ |
| İstatistik (çaba odaklı: haftalık özet, ısı haritası, ders dağılımı) | ✅ |
| Sınav geri sayımı (Home rozeti) | ✅ |
| Yerel yedek (JSON dışa/içe aktar) | ✅ |
| Paylaşılabilir başarı kartı | ✅ |
| Seri/dondurma (Profil) | ✅ |
| **Ana ekran widget'ı** | ⬜ **tek eksik kalem — B1 önceliği** |
| Play Store yayını | ⬜ dağıtım darboğazı (#1 risk) |

**Sonuç:** MVP özellik seti fonksiyonel olarak zaten tamamlanmış durumda — kalan gerçek iş
özellik değil, **widget + yayın**. Bu, önceki dosyanın vardığı sonuçla birebir örtüşüyor;
bu oturum sadece 3 yeni rakiple bu sonucu bir kez daha doğruladı.

---

## Kaynaklar (bu oturumda eklenen)

- [Doping Hafıza — Google Play](https://play.google.com/store/apps/details?id=com.dopinghafiza.mobile.app&hl=en_US)
- [Doping Hafıza — Paket/Fiyat](https://www.dopinghafiza.com/shop)
- [Derslig — Şikayetvar](https://www.sikayetvar.com/derslig)
- [Derslig — iptal/iade şikayeti örneği](https://www.sikayetvar.com/derslig/derslig-iptal-etmek-ve-para-iade-talebim)
- [MentalUP — resmi fiyatlandırma](https://mentalup.net/uygulama-ucreti-ve-fiyatlandirmasi)
- [MentalUP — App Store](https://apps.apple.com/tr/app/mentalup-ak%C4%B1l-zeka-oyunlar%C4%B1/id1284769817?l=tr)

Diğer tüm kaynaklar için bkz. `rakip_analizi_ve_yon_2026-09.md` ve `pusula_savas_plani_2026-09.md`
kaynak bölümleri (tekrarlanmadı).
