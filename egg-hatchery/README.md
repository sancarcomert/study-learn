# Egg Hatchery (Roblox)

Please Donate tarzi bir stand oyunu: oyuncu bir stand sahiplenir, ustundeki yumurta zamanla ve
destek satin alimlariyla buyur/evrilir. Harita "Celestial Hatchery" kodla kurulur.

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

## Harita: Sunny Park (MapBuilder + MapFX)

Gunesli, yesil bir park meydani; Please Donate tarzi stand haritasi:
- ortada cesme, genis tasli meydan, 4 yonde cimenlik parka acilan yollar
- meydanin 4 kenarinda sira sira (kenara dik) dizili 24 sade ahsap kulube: tezgah, cizgili yesil tente,
  ustunde isim tabelasi ve tabelanin ustunde kucuk yumurta (`BOOTHS_PER_SIDE` ile 6 ya da 8 => 24 ya da 32 stand)
- agaclar, calilar, cicek yataklari, banklar, lamba direkleri, citlik, uzakta tepeler, gunesli gokyuzu

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
dev/run_tests.sh /yol/luau                       # 88 kontrol: kurulum komutu, yerlesim, stand, MapFX, kayit, bagis/makbuz
dev/run_map.sh /yol/luau parts.txt               # haritayi kurup parca dokumunu yazar
python3 dev/render_preview.py parts.txt cikti/   # (pillow, numpy) 3B onizleme PNG'leri
```
