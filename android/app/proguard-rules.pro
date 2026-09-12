# flutter_local_notifications zamanlanmış bildirim verisini Gson ile
# serileştiriyor — R8 bu alanları isimleriyle koruyamazsa bildirimler
# cihaz yeniden başlatıldıktan sonra sessizce bozulabilir.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
