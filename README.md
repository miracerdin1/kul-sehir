# Kül Şehir — İlk Sokak

Godot 4.7.2 ile hazırlanan oynanabilir PC görsel prototipi. Orijinal HTML oyununa dokunulmadı. Bu sürüm, yeni görsel yönün ve motor geçişinin ilk küçük bölümüdür; HTML oyununun tüm sistemlerini henüz içermez.

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
| Boşluk | Zıpla (çömelik veya yatıkken ayağa kalk) |
| E | Yakındaki malzemeyi al / sobayı kullan |
| B | Çantayı aç veya kapat |
| F | Fener |
| Esc | Duraklat / devam et / çantayı kapat |
| F2 | FPS ve çizim istatistikleri |
| F11 | Tam ekran / pencere |

Oyundan başka pencereye geçildiğinde oynanış duraklar. Menüde **Görüntü** düğmesi dengeli ve performans ayarları arasında geçiş yapar.

### İlk görev

Kaldırımdaki yakıt bidonunu, **Erzak Deposu** içindeki erzağı ve sokağın sonuna doğru sağ kaldırımdaki metal parçayı topla. Sobaya dönüp **E** ile hazırlığı tamamla. Sonrasında sokakta dolaşmaya devam edebilirsin. Sobanın yanında durmak vücut ısısını artırır.

## Neler var?

- İskeletli, dokulu SWAT karakteri; iskelete uyarlanmış durma, yürüme, hafif koşu, depar, çömelme, sürünme ve düşme animasyonları. Klip hızı gerçek yer hızına göre ayarlanır, ayaklar kaymaz.
- Kameraya göre hareket, koşma, zıplama; duvarlara yaklaşınca kısalan omuz kamerası.
- Fotoğraf tabanlı renk, normal ve pürüzlülük dokuları; gerçek 3B araç, soba, bariyer, taş ve malzeme modelleri.
- Girilebilir yapılar, sabit atmosfer, güneş gölgeleri, sınırlı kül parçacıkları, ateş ışığı ve fener.
- Türkçe menü, görev, çanta, dayanıklılık ve ısınma sistemi.
- Orijinal üretilmiş adım sesi ve düşük seviyeli ortam uğultusu.

Henüz taşınmayanlar: düşmanlar, silahlar/çatışma, açlık/susuzluk, dinamik hava ve gün/gece, kayıt sistemi, büyük harita ve prosedürel şehir. Şehir mimarisi ilk modüler düzenlemedir; el yapımı ayrıntılı yıkım sahneleri sonraki görsel çalışma kapsamındadır.

## Geliştirme

`Editoru-Ac.ps1` dosyası projeyi Godot düzenleyicisinde açar. Alternatif: `.tools/godot/Godot_v4.7.2-stable_win64.exe` ile `godot/project.godot` dosyasını içe aktar.

| Konum | Sorumluluk |
| --- | --- |
| `godot/scripts/expedition.gd` | Görev, etkileşim, duraklatma ve kalite ayarları |
| `godot/scripts/survivor.gd` | Hareket, animasyon ve kamera |
| `godot/scripts/street.gd` | Modüler sokak, çevre ve malzeme yerleşimi |
| `godot/scripts/hud.gd` | Türkçe arayüz |
| `godot/scripts/asset_factory.gd` | Modelleri ölçekleme ve çarpışma yardımcıları |
| `godot/scripts/surfaces.gd` | Paylaşılan yüzey materyalleri |
| `godot/assets/` | Yerel oyun varlıkları ve kaynak kayıtları |
| `godot/tests/prototype_qa.gd` | Oynanış kontrolleri ve gerçek ekran yakalamaları |

Sokak şu aşamada betikle oluşturulur; düzenleyicide boş ana sahne görülmesi normaldir. **F6/F5 ile çalıştırıldığında** sokak oluşur. Kalıcı sahne modüllerine dönüştürme sonraki geliştirme aşamasında yapılabilir.

Claude CLI ile devam edilirken aynı dosyalarda eşzamanlı düzenleme yapılmamalı. Bu çalışma Claude oturumuna müdahale etmedi.

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

Son komut kaynak varlıklarını Godot'a içe aktarır; oyun build/export işlemi değildir. Godot indirmesi resmi GitHub sürümünün SHA256 değeriyle, Poly Haven dosyaları API'deki MD5 değerleriyle doğrulanır. Karakter kaynaklarının SHA256 değerleri `survivor.credits.json` içinde kaydedilir.

## Doğrulama

24 oynanış kontrolü geçti: hareket, koşma maliyeti, zıplama/iniş, duvar çarpışması, kameranın normal ve çok yakın duvarda kısalması, uzaktan toplama engeli, üç malzemenin birer kez toplanması, görevin tamamlanması, ısınma, duraklatma, çanta ve kalite seçimi.

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot -- --smoke-test
```

Gerçek Vulkan/Mobile render ile menü, sokak, yürüme, soba ve çanta görüntüleri `godot/qa-output/` altında alınır:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path godot -- --capture-qa
```

MX450 üzerinde 1280 × 720 kısa görüntü kontrollerinde yaklaşık 48–60 FPS görüldü. Bu tam performans testi değildir; uzun süreli çalışma ve geniş sahne performansı henüz ölçülmedi.

**Bağımsız Windows build/export yapılmadı.** Başlatıcı, yerel Godot çalıştırıcısıyla projeyi açar. Kullanıcı talimatı gereği build komutları çalıştırılmadı. Codebase-memory MCP araçları oturumda bulunmadığından kaynaklar doğrudan incelendi.

Varlık bilgileri: [CREDITS.md](godot/CREDITS.md).


## Ortak çalışma

Önce `AGENTS.md` veya `CLAUDE.md` üzerinden `docs/ORTAK_KURALLAR.md`, `docs/SAHIPLIK.md` ve `docs/GUNLUK.md` okunur. Orijinal oyun `reference/kul-sehir.html` altında salt okunur referanstır. Varlıkların dosya bazlı dökümü `assets/KAYNAKLAR.md` içindedir.
