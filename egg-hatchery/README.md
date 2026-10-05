# Egg Hatchery (Roblox)

Please Donate tarzi bir stand oyunu: oyuncu bir stand sahiplenir, ustundeki yumurta zamanla ve
destek satin alimlariyla buyur/evrilir. Harita (dogal park + gol) kodla kurulur.

## Studio'ya yerlestirme

| Dosya | Studio konumu | Tur |
|---|---|---|
| ServerScriptService/Modules/Config.lua | ServerScriptService > Modules > Config | ModuleScript |
| ServerScriptService/Modules/Remotes.lua | ServerScriptService > Modules > Remotes | ModuleScript |
| ServerScriptService/Modules/BoothRegistry.lua | ServerScriptService > Modules > BoothRegistry | ModuleScript |
| ServerScriptService/Modules/HatcheryService.lua | ServerScriptService > Modules > HatcheryService | ModuleScript |
| ServerScriptService/EconomyManager.server.lua | ServerScriptService > EconomyManager | Script |
| ServerScriptService/BoothManager.server.lua | ServerScriptService > BoothManager | Script |
| ServerScriptService/MarketplaceHook.server.lua | ServerScriptService > MarketplaceHook | Script |
| ServerScriptService/MapBuilder.server.lua | ServerScriptService > MapBuilder | Script |
| StarterGui/EggClient.client.lua | StarterGui > EggClient | LocalScript |
| StarterPlayer/StarterPlayerScripts/MapFX.client.lua | StarterPlayer > StarterPlayerScripts > MapFX | LocalScript |

Kurulum: Game Settings > Security > "Enable Studio Access to API Services" acik olmali.
`Config.PRODUCTS` icine Developer Product ID'lerini yaz. `Workspace.Booths` klasorunu `MapBuilder` kendisi
doldurur (stand sayisi `MapBuilder` basindaki `BOOTHS_PER_SIDE` ile degisir).

## Ekonomi / liderlik tablosu

Liderlik tablosu: **Raised** (standina gelen destek, Robux), **Donated** (baskalarina verdigin), **Level** (yumurta
seviyesi). Sure gecmekle puan/XP YOKTUR; yumurta yalnizca destekle buyur: seviye arttikca fiziksel olarak buyur
(`Config.EggScale`, en fazla x2.2), Rare+ nadirliklerde surekli kivilcim/isik, seviye atlayinca gecici parcacik patlamasi.

## Harita: Dogal Park (MapBuilder + MapFX)

Gunesli dogal park; Please Donate tarzi stand meydani:
- ortada cesme (8 fiskiyeli), kaldirim tasli meydan, 4 yonde parka acilan yollar, yol agizlarinda "WELCOME" kapilari
- meydanin 4 kenarinda sira sira 24 renkli pazar tezgahi (her stand kendi renginde: tente, bayrakcik, isik dizisi, meyve
  sepetleri, bagis kavanozu, saksilar); tabela on tarafta yuksekte, tabelanin ustunde yumurta (`BOOTHS_PER_SIDE` 6 ya da 8)
- gercek Roblox arazisi (Terrain): kuzey-bati golu + iskele, guney-dogu kucuk gol, ikisini baglayan dere ve +X yolu
  uzerinde ahsap kopru, tepeler; dolambacli tas patikalar, piknik alani, kosk, cicek cayirlari, kamis/nilufer/kayalar
- 4 cins agac (mese/huş/kiraz/akcaagac), banklar, cop kutulari, lambalar, saksilar, kenarda kaya + agac siralari
- arazi uretilemezse (Terrain hatasi) duz zemin parcasina geri doner

**Onerilen: tek komutla kurulum.** `command_bar/InstallMap.lua` dosyasinin TAMAMINI Studio'da
View > Command Bar'a yapistirip Enter'a bas ("Tehlikeli Komut" uyarisinda "Devam et"). Harita KALICI kurulur
(Play'e basmadan gorunur), `MapFX` LocalScript'i otomatik olusturulur, eski `MapBuilder` scripti silinir,
kamera parka cevrilir. Ayarlar dosyanin basindaki `BOOTHS_PER_SIDE`, `USE_FUTURE_LIGHTING`, `LOCK_PARTS`
satirlaridir; degistirip tekrar calistirmak eskisini silip yeniden kurar.

`MapFX` (istemci): stand yumurtasi hafifce yuzer; stand tabelasi sahipsizken "STAND 07", sahipliyken
oyuncunun adini gosterir. Alternatif: `MapBuilder.server.lua`'yi Script olarak koyarsan harita her oyun
basinda kurulur. `command_bar/InstallMap.lua` `python3 dev/build_command_bar.py` ile MapBuilder + MapFX'ten
uretilir; elle duzenleme. Onizlemeler `dev/previews/` altinda (gercek Roblox gorunumu degil, yazilim cizicisi).

## Gelistirici testleri (Roblox'suz)

`dev/` klasoru kodu gercek Luau yorumlayicisinda, katı bir Roblox API taklidi ile test eder:

```
# Luau CLI: https://github.com/luau-lang/luau/releases (luau-ubuntu.zip)
python3 dev/build_command_bar.py                 # command_bar/InstallMap.lua'yi yeniden uretir
dev/run_tests.sh /yol/luau                       # 106 kontrol: kurulum, yerlesim, arazi/su/kopru, stand, MapFX, kayit, bagis/makbuz, yumurta buyumesi
dev/run_map.sh /yol/luau parts.txt               # haritayi kurup parca dokumunu yazar
python3 dev/render_preview.py parts.txt cikti/   # (pillow, numpy) 3B onizleme PNG'leri
```
