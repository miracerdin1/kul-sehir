# Kül Şehir

Godot 4.7.2 ile hazırlanan oynanabilir PC görsel prototipi. Orijinal HTML oyununa dokunulmadı. İlk sokak, yaklaşık 195 × 175 m'lik yıkık bir şehrin ortasındadır; HTML oyununun silah ve düşman sistemi taşındı, diğer sistemler sırayla taşınıyor.

## Oyna

**`Oyunu-Baslat.cmd` dosyasına çift tıkla.** Açılan oyunda **Sokağa Gir** düğmesine bas.

Yeni klondan sonra aşağıdaki hazırlık komutlarını çalıştır. Godot çalıştırıcısı `.tools/godot/` altında hazırlanır. Çevre varlıkları Git LFS ile gelir; Mixamo karakteri lisansı gereği kaynak deposunda bulunmaz ve yerelde oluşturulur. Hazırlık tamamlandıktan sonra oyun çevrimdışı çalışır.

### Kontroller

| Tuş | İşlev |
| --- | --- |
| W A S D | Hareket (varsayılan: hafif koşu) |
| Fare | Kamerayı çevir |
| Shift | Depar; dayanıklılık tüketir |
| Alt (basılı) | Yürü |
| C veya Ctrl | Çömel / kalk |
| Z | Yere yat / kalk |
| Boşluk | Zıpla; bel hizasında duvar, pencere denizliği veya kırık camın önündeyken üstünden atla (çömelik veya yatıkken ayağa kalk) |
| E | Yakındaki malzemeyi veya silahı al, cesedi ara, kapıyı aç/kapat, sobayı kullan |
| Sağ tık | Nişan al / bırak (tüfekte yakınlaştırır) |
| Sol tık | Ateş et / bıçak veya yumruk; camları kır |
| R | Şarjör değiştir |
| 1 – 4 | Silah seç (yumruk, bıçak, tabanca/pompalı, tüfek) |
| 5 | RPG seç |
| G | Mayın kur (2 sn sonra etkin) |
| H | Sargı bezi (kanamayı durdurur) |
| M | Şehir haritası |
| B | Çantayı aç veya kapat |
| F | Fener |
| Esc | Duraklat / devam et / çantayı kapat |
| F2 | FPS ve çizim istatistikleri |
| F11 | Tam ekran / pencere |

Oyundan başka pencereye geçildiğinde oynanış duraklar. Menüde **Görüntü** düğmesi dengeli ve performans ayarları arasında geçiş yapar.

### İlk görev

Kaldırımdaki yakıt bidonunu, **Erzak Deposu** içindeki erzağı ve sokağın sonuna doğru sağ kaldırımdaki metal parçayı topla. Sobaya dönüp **E** ile hazırlığı tamamla. Sonrasında sokakta dolaşmaya devam edebilirsin. Sobanın yanında durmak vücut ısısını artırır.

## Zırhlı araçlar ve patlayıcılar

Sobanın yanındaki RPG, roket ve mayınları **E** ile topla. **5** ile RPG seç, sağ tıkla nişanı aç/kapat, sol tıkla ateş et; **R** ile roket doldur. **G** yere mayın bırakır (en fazla 8 etkin mayın). Mayın 2 saniye sonra yakındaki asker veya aracı algılar; ateş ederek de patlatılabilir. Patlama sana da zarar verir, uzaklaş.

Şehir yollarında iki tank ve iki ZPT var; ilk tank başlangıç sokağının güney çıkışında. Araçlar yollarda devriye gezer: kavşaklarda döner (tank yerinde döner), önlerine çıkan insan veya araç için durur, uzun süre yol kapalıysa geri döner. Tank paletleri ve tekerleri hareketle döner; kule sokağı tarar. Araç oyuncuyu 70 m içinde görürse durur, "seni gördü" uyarısı verir ve ateş açar: tank yaklaşık 3 saniye sonra patlayıcı top mermisi atar (her 6.5–9.5 sn; koşan hedefi daha sık ıskalar), yakındaysa makineliyle de tarar; ZPT ağır makineliyle kısa seriler atar (kanama yapabilir). Siper al veya görüş hattından çık. Oyuncu araç süremez. Tank iki RPG isabetiyle, ZPT tek isabetle imha olur; yakından mayın ikisini de imha eder. Enkaz siper olarak kalır. Duvarlar patlama hasarını keser; yakındaki camlar kırılır. Araçlar ve patlayıcı modelleri mevcut modüler parçalarla üretilir.

## Neler var?

- İskeletli, dokulu SWAT karakteri; iskelete uyarlanmış durma, yürüme, hafif koşu, depar, çömelme, sürünme, zıplama/iniş, eğilip alma, nişan, bıçak darbesi ve ölüm animasyonları. Klip hızı gerçek yer hızına göre ayarlanır, ayaklar kaymaz.
- HTML'deki silahlar: yumruk, bıçak, tabanca, pompalı ve tüfek (hasar, şarjör, sekme, ses). Nişan alırken gövde hedefe döner; kafadan vuruş ve habersiz hedefe bıçakla tek darbe.
- Devriye gezen, sesi araştıran ve çatışmaya giren askerler; görüşleri gün ışığına ve havaya bağlı. Askerler yol bulup evlere girer, kapıları açar, merdivenden üst kata çıkar ve seni içeri kadar takip eder; yaklaşan askerin ayak ve teçhizat sesi duyulur. Can, kanama, sargı bezi, ölüm ve yeniden başlama.
- Yollarla ayrılmış 12 bloklu şehir: içine girilebilen yıkık binalar, enkaz, yanmış arabalar, tanklar, siperler; binalara dağıtılmış silah ve mermiler; M ile harita.
- Başlangıç sokağı dahil iki katlı evler: eğimli çatı, baca, söve ve denizlikler; açılan kapılar, merdivenler, üst kat korkulukları, ahşap döşeme ve raflar.
- Şeffaf pencere camları: ateş veya yakından yumruk/bıçak darbesiyle kırılır; kısa parça efekti ve cam sesi çıkar, çarpışma kalkar. Kırılma sesi yakındaki askerleri uyarır.
- Gün/gece döngüsü ve değişen hava (açık, bulutlu, sis, yağmur, kar, tipi).
- Kameraya göre hareket, koşma, zıplama; duvarlara yaklaşınca kısalan omuz kamerası.
- Fotoğraf tabanlı renk, normal ve pürüzlülük dokuları; gerçek 3B araç, soba, bariyer, taş ve malzeme modelleri.
- Girilebilir yapılar, sabit atmosfer, güneş gölgeleri, sınırlı kül parçacıkları, ateş ışığı ve fener.
- Türkçe menü, görev, çanta, dayanıklılık ve ısınma sistemi.
- Orijinal üretilmiş adım sesi ve düşük seviyeli ortam uğultusu.

Henüz taşınmayanlar: açlık/susuzluk, ıslaklık, kendi ateşini yakma, dolap/sandık arama, kayıt sistemi. Silah modelleri basit yer tutucudur; şehir binaları ortak modüler parçalardan üretilir, el yapımı ayrıntılı yıkım sahneleri sonraki görsel çalışma kapsamındadır.

## Geliştirme

`Editoru-Ac.ps1` dosyası projeyi Godot düzenleyicisinde açar. Alternatif: `.tools/godot/Godot_v4.7.2-stable_win64.exe` ile `godot/project.godot` dosyasını içe aktar.

| Konum | Sorumluluk |
| --- | --- |
| `godot/scripts/expedition.gd` | Görev, etkileşim, duraklatma ve kalite ayarları |
| `godot/scripts/survivor.gd` | Hareket, animasyon ve kamera |
| `godot/scripts/street.gd` | Modüler sokak, çevre ve malzeme yerleşimi |
| `godot/scripts/hud.gd` | Türkçe arayüz |
| `godot/scripts/combat/` | Silahlar, askerler, savaş arayüzü, nişan/vuruş katmanı |
| `godot/scripts/city/` | Şehir blokları, birleşik meshler, M haritası |
| `godot/scripts/world/` | Gün/gece ve hava |
| `godot/scripts/asset_factory.gd` | Modelleri ölçekleme ve çarpışma yardımcıları |
| `godot/scripts/surfaces.gd` | Paylaşılan yüzey materyalleri |
| `godot/assets/` | Yerel oyun varlıkları ve kaynak kayıtları |
| `godot/tests/prototype_qa.gd` | Oynanış kontrolleri ve gerçek ekran yakalamaları |
| `godot/tests/city_performance_qa.gd` | Şehir FPS ölçümü |

Sokak şu aşamada betikle oluşturulur; düzenleyicide boş ana sahne görülmesi normaldir. **F6/F5 ile çalıştırıldığında** sokak oluşur. Kalıcı sahne modüllerine dönüştürme sonraki geliştirme aşamasında yapılabilir.

Claude ve Codex aynı dosyalarda eşzamanlı düzenleme yapmaz; kim hangi dosyada çalışıyor `docs/SAHIPLIK.md` içindedir.

### Sıfırdan yerel hazırlık

Git LFS ve Python 3.12 veya uyumlu Python 3 ile, proje kökünde:

```powershell
git lfs install --local
git lfs pull
python tools/setup_assets.py
python tools/prepare_audio_fonts.py
python tools/prepare_character.py
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path godot --import
```

`prepare_character.py` her yeni animasyon eklendiğinde yeniden çalıştırılmalıdır (`git pull` sonrası bir hareket oynamıyorsa önce bunu çalıştır). Son komut kaynak varlıklarını Godot'a içe aktarır; oyun build/export işlemi değildir. Godot indirmesi resmi GitHub sürümünün SHA256 değeriyle, Poly Haven dosyaları API'deki MD5 değerleriyle doğrulanır. Karakter kaynaklarının SHA256 değerleri `survivor.credits.json` içinde kaydedilir.

## Doğrulama

Oynanış kontrolleri: hareket, duruşlar, zıplama/iniş, eğilip alma, duvar çarpışması, kamera, malzeme toplama, görev, ısınma, duraklatma, çanta, kalite seçimi; silah alma, ateş, şarjör, nişan yönü, asker vurma, ceset arama, sesle araştırma, askerin oyuncuyu vurması, ölüm ekranı; şehir binaları, sokaktan şehre çıkış, şehir sınırı, harita ve yol devriyesi. Ayrıca `tests/weather_qa.gd` 23 iklim kontrolü yapar.

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot -- --smoke-test
```

Gerçek Vulkan/Mobile render ile menü, sokak, yürüme, soba, şehir, ev dışı/üst katı, sağlam/kırılan/kırılmış cam, harita ve çanta görüntüleri `godot/qa-output/` altında alınır:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path godot -- --capture-qa
```

### Şehir performansı

**`Performans-Testi.cmd` dosyasına çift tıkla.** Oyun yaklaşık bir dakika boyunca şehrin beş noktasında, askerlerle birlikte, iki görüntü ayarında FPS ölçer ve sonucu `godot/qa-output/city_performance.txt` dosyasına yazar. Hedef: MX450 üzerinde 1280 × 720'de dengeli ayarda en az 30 FPS.

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path godot -- --city-performance
```

2026-10-02 ölçümü: MX450 / 1280 × 720, beş noktada dengeli ayar ortalamaları 72.2–101.5 FPS; performans ayarı 89.0–118.4 FPS. Bu kısa ölçümdür; uzun süreli performans testi değildir.

**Bağımsız Windows build/export yapılmadı.** Başlatıcı, yerel Godot çalıştırıcısıyla projeyi açar. Kullanıcı talimatı gereği build komutları çalıştırılmadı. Codebase-memory MCP araçları oturumda bulunmadığından kaynaklar doğrudan incelendi.

Varlık bilgileri: [CREDITS.md](godot/CREDITS.md).


## Ortak çalışma

Önce `AGENTS.md` veya `CLAUDE.md` üzerinden `docs/ORTAK_KURALLAR.md`, `docs/SAHIPLIK.md` ve `docs/GUNLUK.md` okunur. Orijinal oyun `reference/kul-sehir.html` altında salt okunur referanstır. Varlıkların dosya bazlı dökümü `assets/KAYNAKLAR.md` içindedir.
