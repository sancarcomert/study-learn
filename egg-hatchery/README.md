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
doldurur (stand sayisi ve ruh hali `MapBuilder` basindaki `BOOTH_COUNT` / `MOOD` ile degisir).

## Harita (MapBuilder + MapFX)

**Onerilen: tek komutla kurulum.** `command_bar/InstallMap.lua` dosyasinin TAMAMINI Studio'da
View > Command Bar'a yapistirip Enter'a bas. Harita KALICI kurulur (Play'e basmadan gorunur), `MapFX`
LocalScript'i otomatik olusturulur, eski `MapBuilder` scripti silinir, kamera adaya cevrilir.
Ayarlar (stand sayisi, ruh hali, Future isik) dosyanin basindaki `BOOTH_COUNT`, `MOOD`,
`USE_FUTURE_LIGHTING` satirlaridir; degistirip tekrar calistirmak eskisini siler.

Alternatif: `MapBuilder.server.lua`'yi Script olarak koyarsan harita her oyun basinda kurulur.
Bu dosya `python3 dev/build_command_bar.py` ile MapBuilder + MapFX'ten uretilir; elle duzenleme.
Onizlemeler `dev/previews/` altinda (gercek Roblox gorunumu degil, yazilim cizicisi).

## Gelistirici testleri (Roblox'suz)

`dev/` klasoru kodu gercek Luau yorumlayicisinda, katı bir Roblox API taklidi ile test eder:

```
# Luau CLI: https://github.com/luau-lang/luau/releases (luau-ubuntu.zip)
python3 dev/build_command_bar.py                 # command_bar/InstallMap.lua'yi yeniden uretir
dev/run_tests.sh /yol/luau                       # 82 kontrol: kurulum komutu, harita, stand, MapFX, kayit, bagis/makbuz
dev/run_map.sh /yol/luau parts.txt               # haritayi kurup parca dokumunu yazar
python3 dev/render_preview.py parts.txt cikti/   # (pillow, numpy) 3B onizleme PNG'leri
```
