# Pusula (eski adıyla Study Planner) — Proje Talimatları

Bu dosya, projenin genel bağlamını ve şu anki sprint'in kapsamını tanımlar. Her oturumda önce bu dosyayı oku.

## Proje Kimliği

- Flutter + Riverpod + Hive (yerel veri, henüz backend yok)
- Uzun vadeli hedef: Türkiye YKS kitlesine odaklı, abonelik bazlı bir ürüne ("Pusula") dönüşmek
- Tüm stratejik/teknik yol haritası `docs/` klasöründe:
  - `pusula_yol_haritasi.md` — backend/ödeme/yayın fazları (Faz 1-10)
  - `pusula_uretim_pazarlama_teknik_recete.md` — MVP kapsamı, kapsam disiplini, pazarlama
  - `ozellik_kullanilabilirlik_analizi.md` — rakip özellik/kullanılabilirlik analizi
  - `tasarim_sistemi_referans_analizi.md` — mevcut tasarım sistemi analizi (eski)

## ⚠️ Kesin Kapsam Sınırı (asla önerme/ekleme)

- Canlı ders/koçluk — asla
- Video konu anlatımı/içerik — asla
- Soru bankası/soru çözme modülü — asla

Bu üçü bilinçli olarak dışarıda tutuluyor (solo geliştirici + sıfır bütçe gerçeği). Rakip özelliği gördüğünde otomatik "ekleyelim" deme, önce sor.

## 🎯 SPRINT: UI Yeniden Tasarımı — Midnight Dark + Champagne Gold

**Durum:** P0 (saf görsel) **tamamlandı** — 2026-09-09. Palet, tipografi, buton sistemi, ikon taraması, 9 ekran IA, alt nav; cihazda offline test edildi. İş mantığı diff = 0 (kanıtlandı). Kalan: aşağıdaki "Sırada Ne Var".

**Tam spesifikasyon (rakip analizi + 8 ekran IA + buton sistemi + yol haritası):** Artifact — TR YKS pazar analizi, `docs/` yol haritasıyla birlikte okunur.

**2026-09 pivot:** Önceki yön (sıcak parşömen + lacivert hero + tek altın vurgu, açık tema) tamamen terk edildi. Yeni yön: **koyu tema** — Midnight Dark zemin, Muted Indigo ikincil, Champagne Gold vurgu, Soft Cream White metin. Sadece görsel — iş mantığı, provider'lar, repository'ler, model dosyaları değişmeyecek.

### Onaylanmış kararlar

**A) Ders paleti:** 6 rengi silme. Desatüre pastel tonlar, koyu zeminde okunur parlaklıkta (toz eriği, adaçayı, toz mavisi, bronz, toz gülü, deniz köpüğü). Altın hiçbir zaman ders rengi olarak kullanılmayacak — sadece marka/CTA vurgusu.

**B) CTA hiyerarşisi:**
- Altın (champagne gold) = birincil pozitif aksiyon (Planımı Oluştur, Görevi Ekle, Kaydet, Devam Et) — üzerinde her zaman koyu (ink) metin, beyaz değil
- Charcoal/koyu gri (ikinci bir "ink" değil, sayfa zemininden görünür ayrışan bir ton) = ikincil/nötr aksiyon (kapatma, iptal) + Geri Al (undo)
- Kırmızı aile = yıkıcı aksiyonlar (sil) — aynen kalıyor

**C) Dark-mode'a özgü kural:** `AppColors.ink` artık en koyu ton (neredeyse siyah) — koyu zeminde bir öğeyi "öne çıkarmak" için kullanılamaz (görünmez olur). Öne çıkan/aktif öğeler (bugünün günü, aktif nav sekmesi, hero kart zemini) `primary` (altın) ya da bariz daha açık özel bir ton kullanmalı, `ink` değil. `ColorScheme.fromSeed` artık `Brightness.dark`.

### Uygulanan (P0 — tümü bitti)

1. ✅ `app_colors.dart` — token isimleri korundu, değerler koyu temaya çekildi
2. ✅ `app_text_styles.dart` — **Lora** serif heading'lere, Plus Jakarta Sans body. Her ikisi de `assets/fonts/`'a **gömülü** (`GoogleFonts.config.allowRuntimeFetching = false`) — offline çalışır
3. ✅ `app_theme.dart` — `Brightness.dark`, buton pill, dialog/snackbar koyu
4. ✅ Paylaşılan widget'lar — `app_buttons.dart` (kral 64/r32, ikincil surfaceVariant/r18), `eyebrow.dart`, `week_strip`, `next_task_card`, `task_tile`, `achievement_card`, `app_snackbar`, `tap_scale` (`HitTestBehavior.opaque`). **Silindi:** `hero_progress_card.dart`, `smart_plan_banner.dart` (Home sadeleştirmesiyle kullanımdan kalktı)
5. ✅ `main_shell.dart` → yeni `widgets/app_bottom_nav.dart` (outline ikon + altın nokta indicator)
6. ✅ 9 ekran: Home (sadeleştirildi — header/hero/kral buton/bento/görev listesi), Onboarding, Smart Plan, Tasks, Day Detail, Add Task, Add Subject, Subjects, Stats, Profil, Plan
7. ✅ İkon taraması — tüm `_rounded` → `_outlined`/base (13 dosya). Aktif nav ikonu bilinçli dolu
8. ✅ Cihazda offline test + `flutter analyze` (0 error) + build ✓

**Sprint sırasında düzeltilen bug'lar:** bildirim dialog kilitlenmesi (stale State context), çift MainShell (onboarding `pushReplacement` kaldırıldı), offline font çökmesi, `TapScale` hit-test, aktif nav etiketi `ink`→`textPrimary`.

### Her aşamadan sonra zorunlu doğrulama

- `flutter analyze` çalıştır, hata varsa düzelt (UI kaynaklıysa düzelt, iş mantığı kaynaklıysa dokunma, bana sor)
- İş mantığına dokunulmadığını `git diff` ile göster — "değiştirmedim" demek yetmez, provider/repository/model dosyalarında diff olmadığını kanıtla

### Sprint sonunda rapor formatı

1. Değişen dosyalar
2. Değişen UI bileşenleri
3. Bilerek dokunulmayan şeyler (fonksiyonellik)
4. `flutter analyze`/build sonucu
5. Kalan görsel tutarsızlıklar (varsa)

## Sırada Ne Var

**Küçük görsel/temizlik (opsiyonel):**
- Onboarding başlığı "Study Planner" → "Pusula" (marka kararı, kullanıcı onayı bekliyor)
- 51 `info` lint (repo geneli `withOpacity` → `.withValues()`, `use_build_context_synchronously`) — hata değil, ayrı temizlik

**Spec yol haritası:**
- ✅ **P1 — Sınav sayacı** (commit `7014fa6`): `examDate` nullable Hive alanı, Home rozeti, İstatistik kartı, onboarding seçici.
- ✅ **P2 — Odak seansı** (commit `e69936f`): `focus_screen.dart` yerel kronometre, Plan sekmesinden giriş. v1 tek seans (Pomodoro döngüsü yok).
- ✅ **P2.5** (`9a28089` + `ea1319a` + `ed74c20`): odağı görevden başlatma; odak/görev süre ayrımı (`focusMinutes` ayrı Hive alanı, `defaultValue: 0`); duvar-saati sayaç + PopScope geri-tuş koruması; sınav sayacı Home rozeti tıklanır + geçmiş-tarih picker çökmesi.
- ✅ **Pomodoro** (`54057f9`): FocusScreen iki modlu (Serbest / Pomodoro). Çalışma bloğu → 5 dk mola → 4 turda 15 dk uzun mola. Tamamlanan blok anında `focusMinutes`'a. Bağımlılık yok.
- ✅ **IA sadeleştirme** (`d18f72a`): Profil'den "Tüm İstatistikleri Gör" kaldırıldı; Home profil halkası → ProfileScreen. İstatistik tek gerçek giriş: alt nav + Home sınav rozeti.
- ✅ **Kişiselleştirme + ipuçları** (`5fae800`): selam isimle + davranışa göre alt satır; Home'da tek seferlik görev ipucu şeridi (kaydır + ▶), `hasSeenTaskHints` alanı.
- ✅ **Seviye 1.5 yerel AI** (`2dd2a9c` → `638f2c6`, 6 commit): LLM'siz.
  - `plan_parser.dart` — serbest metin → {ders, tarih, **saat**, süre, tekrar}. Türkçe regex + `SubjectAI`. Dart `\b` Türkçe harflerde çalışmadığından elle komşu-harf denetimi. Saat: "15:30", "saat 3", "akşam 8", "sabah 9"; "akşam 1 saat" (süre) / "3 saat 15 dk" ayrımı korunur.
  - `study_advisor.dart` — dersleri ihmal süresi + tamamlama oranı + sınav yakınlığı + bugünkü denge ile puanlayıp gerekçeli öneri.
  - `plan_builder.dart` — plan üretiminin saf çekirdeği (girdi → `PlanBlock` listesi, hiçbir şey yazmaz).
  - **Akıllı Plan tek moda indi** (`671d10f`): "Günümü Planla / Sınava Hazırlan" mod seçici silindi; sınav farkındalığı artık `examDate`'ten (≤30 gün → öncelikler yükselir). Çok güne yayılan konu dağıtımı çıkarıldı → **Konu Takip** modülüne bırakıldı (ayrı karar).
  - **`smart_plan_screen.dart` silindi** → `coach_screen.dart`. **Çip YOK** — koç doğal dille sorar, kullanıcı yazar (`638f2c6` geri bildirimi). Alt bar = sadece metin alanı; onay beklerken tek "Ekle" CTA'sı. Eksik alanı tek tek sorar (ders → süre → gün → tekrar). "sen ayarla / bilmiyorum" → devralma modu, koç günü `PlanBuilder` ile kurar. Enerji sorusu yok. Home kral butonu + Plan sekmesi buraya.
  - Home: `_QuickAddBar` **eklendi sonra kaldırıldı** (`638f2c6`) — + FAB ile mükerrerdi. Bugün görev yokken `_SuggestionStrip` (StudyAdvisor önerileri) kaldı.
  - `test/` eklendi: 45 test (parser/advisor/builder). Repo'da başka test yoktu.
- ✅ **Onboarding + hedef** (`c82e08a`): onboarding en üste "ADIN" alanı (isim soyisim → `updateUserName`); **sınav tarihi seçici kaldırıldı** — kullanıcı girmedikçe geri sayım yok (giriş artık yalnız İstatistik ekranından). `UserStatsModel.dailyGoal` 3 → 1 (yeni kayıt; migration yok). Hedef kutlaması (konfeti dialog) günde bir kez — `home_screen._celebratedOn`.
- ✅ **Konu Takip modülü** (`4423e2f` → `9e0fbe5`, 4 commit, cihazda test): **mevcut SubjectModel'e dokunulmadı** — ayrı Hive box (`topics`, typeId 6-7), `subjectId` ile bağlı.
  - `topic_model` (TopicStatus: başlanmadı/çalışıldı/tekrar — "soru çözüldü" YOK), `topic_repository`, `topic_provider` (`coverageBySubjectProvider`, `topicsForSubjectProvider`), `topic_catalog` (12 ders YKS yaygın konu listesi).
  - `konu_takip_screen` (özet: genel % + ders listesi + sütun grafiği) → `subject_topics_screen` (satıra dokun = durum döngüsü, sola kaydır = sil, "Yaygın konuları ekle", alt barda konu ekle). Plan sekmesi 3. giriş.
  - `widgets/coverage_bar_chart` (fl_chart) — Konu Takip özeti + İstatistik "KONU KAPSAMASI" kartı.
  - **AI bağlandı:** `StudyAdvisor.suggest(coveragePercent:)` düşük kapsamlı dersi öne çıkarır; `PlanBuilder.build(uncoveredTopics:, fillToCapacity:)` görev başlıklarını gerçek boş konulardan üretir. Koç "sen ayarla" → işaretlenmemiş konulardan dolu program.

### AI durumu / sınır
- "Seviye 1": `subject_ai.dart` yerel anahtar-kelime sözlüğü (ders tahmini).
- **"Seviye 1.5" (yukarıda, tamamlandı):** parser + advisor + builder + Çalışma Koçu. Hepsi yerel/kural tabanlı, salt okunur; görev oluşturma yine `taskProvider.addTask`.
- "Seviye 2" (gerçek LLM): maliyet + backend gerektirir → **Faz 1 (Supabase) + abonelik sonrası**, ve **yalnız planlama/ayrıştırma tarafında**. LLM ile ders anlatan/soru çözen asistan = kesin kapsam sınırı (yasak).
- **Konu Takip modülü — ✅ TAMAMLANDI** (`4423e2f`→`9e0fbe5`). Kalan opsiyonel: haftalık tekrarlı program üretimi (şu an tek günlük), konu bazlı güven/seviye, ders silinince konuları temizleme (şu an orphan kalıyor ama her yerde filtreleniyor).
- **P3 — Net/deneme takibi (opsiyonel):** deneme neti girişi + trend. "Soru bankası" değil (soru yok). Kapsam kayması riski — kullanıcı kararı.
- ✅ **Profesyonelleştirme geçişi** (`ca37551` + `96fe32e`, cihazda test): (1) Koç/plan görevlerine artık **saat atanmıyor** — gün-kapsamlı; saat yalnız kullanıcı açıkça söylerse. `PlanBlock.startTime`→`order`. (2) Add Task **SÜRE opsiyonel** (`_selectedDuration` nullable, çipe tekrar dokun=kaldır) — eskiden her göreve zorla 30 dk. (3) "Şu anki saate göre gecikti" yerine Home açılışında **"önceki günlerden N görev — bugüne taşı?"** dialog'u (`task_time_status.isPastDayIncompleteAt`, `updateTask` ile taşıma). (4) Stats "KONU KAPSAMASI" sütun grafiği → sade yatay ilerleme listesi; `coverage_bar_chart.dart` silindi.
- ✅ **Ufak temizlik** (`4ee8fe3`): Profil "SERİN" → "SERİ"; "Sıradaki Görev" artık yalnız bugünün zamanlı görevini alıyor + ≥90 dk bekleme "HH:MM'de başlayacak" (eski "685 dakika sonra" saçmalığı gitti).
- ✅ **Genel audit + temizlik** (`f8f92f7` + `3187cb6`, cihazda test): **Ölü kod silindi** — `day_detail_screen`, `widgets/week_strip`, `widgets/animated_progress_ring`, `user_progress` (xp/level modeli, hiç kullanılmıyordu; hive_boxes'tan çıkarıldı). **Bug:** `SubjectsScreen` hiçbir yerden açılmıyordu (ders silinemiyordu!) → Profil'e "DERSLERİM" satırı. subjects_screen'deki yanlış "görev ekle" ikonu kaldırıldı. İstatistik "SON 7 GÜN" boş grafiği → boş durum. **Temizlik:** add_task'tan **ZORLUK** alanı kaldırıldı (işlevsizdi — kaydediliyor ama hiç kullanılmıyordu; model dokunulmadı). İstatistik'ten seri/dondurma tekrarı çıkarıldı (Profil'de var). "KONU KAPSAMASI" + "DERS BAZLI İLERLEME" görsel ikizi → tek "DERS İLERLEMESİ". Başarılar + dondurma korundu (kullanıcı isteği).
- ✅ **İstatistik alanı — çaba/süreklilik** (`ae0a8da`+`619eed4`, cihazda test): rakip + TR lise 9-12 kitle araştırması sonrası. Sonuç değil **çaba** öne çıkar. Bölümler: **BU HAFTA** (2 kart: "N görev bitirdin" / "X/7 gün çalıştın") · **ÇALIŞMA TAKVİMİ** 12 haftalık ısı haritası (`widgets/activity_heatmap.dart`, GitHub tarzı, `completedAt ?? dueDate`) · **HANGİ DERSE ÇALIŞTIN** (bu hafta/ay toggle, ders başına tamamlanan görev bar) · **KONU İLERLEMESİ** (konu kapsama %). Her başlıkta açıklayıcı alt satır (öğrenci dili). "SON 7 GÜN" bar kaldırıldı, `fl_chart` importu stats_screen'den çıktı. İstatistik'ten seri/dondurma çıkarıldı (Profil'de).
- ✅ **B — Odak seansı geçmişi** (`bec6ec3`, cihazda test): `focus_session_model.dart` (`FocusSession` typeId 8: id/endedAt/minutes/mode; ayrı `focus_sessions` box; mevcut modeller dokunulmadı, build_runner ile üretildi) + `focus_session_provider.dart` (`focusMinutesByDayProvider`, `focusThisWeekMinutesProvider`). `focus_screen` iki commit noktasında `log()` çağırıyor — mevcut `addFocusMinutes` (Profil kümülatif) aynen duruyor, `stats_provider` dokunulmadı. İstatistik'e **ODAK SÜRESİ** — "Bu hafta: X sa" + 7 günlük özel mini sütun (`_FocusWeekBar`, fl_chart yok).
- **Ertelendi (E):** net/deneme takibi — 11-12 için değerli, kapsam kayması riski, kullanıcı kararı.

Not: repo lokal-only. `feature/home-redesign` → `master`'a merge edildi. GitHub yok.

**Sonra:** `pusula_yol_haritasi.md`'deki Faz 1 (Supabase backend temeli — şema, RLS, Auth). P1–P3 ile Faz 1 paralel yürütülmez.
