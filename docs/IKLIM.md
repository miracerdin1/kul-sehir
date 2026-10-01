# Gün/gece ve hava

Oyun 1. gün 16:30'da başlar. Bir oyun günü, duraklatılmamış 20 gerçek dakika sürer. Menü ve çanta açıkken saat ve yağış parçacıkları donar. HUD gün, saat, hava ve ortam sıcaklığını gösterir.

Hava 90–160 gerçek saniyede bir değişir: açık, bulutlu, sisli, yağmurlu, kar yağışı ve tipi. Başlangıçtaki bulutlu hava 100 saniye sürer. Geçişler yaklaşık 12 saniyelik üstel yumuşatma kullanır; HUD hedef hava türünü gösterirken etkiler kademeli değişir. Rastgelelik tekrar üretilebilir bir başlangıç tohumu kullanır. Güneş/ay ışığı, gökyüzü, sis ve sıcaklık saate ve havaya göre değişir.

## Claude için bağlantı

`expedition.gd` içinden:

```gdscript
var conditions: Dictionary = street.climate.get_environment_state()
var ambient_temperature: float = conditions.temperature_celsius
var wetness_per_second: float = conditions.wetness_rate
```

| Alan | Anlam |
| --- | --- |
| day | 1 tabanlı oyun günü |
| hour | 0–24 aralığında saat |
| weather / label | Hedef hava anahtarı / Türkçe adı |
| daylight | 0–1 gün ışığı |
| temperature_celsius | Anlık ortam sıcaklığı (vücut sıcaklığı değil) |
| rain / snow / wind | 0–1, yumuşatılmış şiddet |
| wetness_rate | Açıkta duran karakter için önerilen ıslanma puanı / gerçek saniye (0–100 ölçeği) |

Bu modül açlık, susuzluk, kanama, vücut ısısı veya ıslaklık değerlerini değiştirmez. Hayatta kalma sistemi, duraklatılmamış delta ile oranı çarpmalı, oyuncunun kendi sığınak/çatı durumunu değerlendirmeli ve 0–100 sınırını uygulamalı. Kamera üzerindeki çatı kontrolü yalnızca görsel yağışı yönetir; oyuncunun örtü altında olduğunun kanıtı değildir.

`street.climate.state.day_changed` ve `weather_changed` sinyalleri kullanılabilir. Test/geliştirme için `state.set_weather("rain", true)` anlık geçiş sağlar. Mevcut `street.sun` ve `street.environment` alanları kalite ayarı uyumluluğu için korunur.

## Görsel kapsam ve sınırlar

Yağış kamera çevresinde üretilir. Kameranın 20 metre üstüne yapılan ışın kontrolü çatı bulursa yerel yağış gizlenir. Parçacık başına bina çarpışması, kar birikmesi, ıslak zemin, yağmur sesi ve hacimsel bulutlar bu değişiklikte yoktur. Düşük kalite yağış miktarını yarıya indirir; ay ışığı ilave gölge haritası üretmez. Yeni harici varlık kullanılmadı; yağış dokusu kodla oluşturulur.

## Doğrulama

Depo kökünden (Godot çalıştırıcısının yolu yerel kuruluma göre değişebilir):

```powershell
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://tests/weather_qa.gd
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot -- --smoke-test
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --path godot --script res://tests/weather_qa.gd -- --capture-weather
```

İlk komut 23 iklim kontrolü, ikinci komut mevcut 40 oynanış kontrolü çalıştırır. Üçüncü komut aynı iklim kontrollerinin yanında dört PNG kaydını doğrular; yerel çıktılar `godot/qa-output/` altındadır ve Git'e girmez. Kısa görüntü kontrolü uzun süreli performans ölçümü değildir.
