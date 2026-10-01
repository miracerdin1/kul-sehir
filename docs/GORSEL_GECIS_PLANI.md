# Kül Şehir — PC sürümü için görsel geçiş planı

> Hazırlayan: Codex. Miraç tarafından 2026-10-01'de projeye aktarıldı. İçerik değiştirilmeden alınmıştır.

## İnceleme ve karar

Kaynak: `C:/Users/mirac.erdin/Downloads/Kül Şehir.html` (depoda: `reference/kul-sehir.html`).
Bu belge kaynak kod incelemesine dayanır; oyun çalıştırılarak görsel veya performans testi yapılmadı.
Kullanıcı PC oyunu istiyor ve motor değişimine açık. Motor önerisi aşağıdadır; geçiş henüz uygulanmadı.

Mevcut uygulama tek HTML içinde Three.js r128 kullanıyor. `makeSoldier` karakterleri temel geometrilerden, `makeGuns` silahları kutu ve silindirlerden oluşturuyor. `poseSoldier` uzuv açılarını kodla değiştiriyor. Çevre dokuları canvas üzerinde üretiliyor; çevre materyallerinin önemli bölümü MeshLambertMaterial kullanıyor. Dolayısıyla gerçekçilik için yalnızca motor veya ışık değişimi yeterli değil: yeni modeller, yüzey dokuları ve iskelet animasyonları gerekli.

Yerel donanım: Intel i7-1165G7, yaklaşık 32 GB RAM, NVIDIA GeForce MX450 (sistemin bildirdiği 2 GB ekran kartı belleği), Intel Iris Xe.

Bu bilgisayarda geliştirme için öneri: Godot 4 ile küçük, optimize edilmiş üçüncü şahıs PC oyunu. İlk sahnede Mobile renderer denenmeli; performans ve sürücü durumuna göre Compatibility değerlendirilmeli. Mobile burada bir görüntüleme yöntemi adıdır, PC oyununa engel değildir. Renderer seçimi gerçek sahne ölçümleriyle kesinleştirilmeli.

Unreal seçeneği daha güçlü donanımda yeniden değerlendirilebilir. Epic'in önerdiği ekran kartı belleği 8 GB veya üzeridir. Motorun açılabilmesi ile hedef kalitede rahat üretim yapılması farklı ölçütlerdir.

## Görsel hedef

Önerilen yön: soğuk, terk edilmiş ve savaşta hasar görmüş şehir. Gerçekçi insan oranları, aşınmış kumaş ve metal, ölçekleri tutarlı nesneler, kırık duvar kenarları, kontrollü sis ve sıcak ateş ışığı.

- Oyuncu: dokulu ve iskeletli tek karakter; durma, yürüme, koşma ve nişan animasyonları. Eğilme, sürünme, doldurma ve ölüm sonraki aşamada aynı iskelete uyarlanmalı.
- Çevre: gerçekçi bina modülleri, hasarlı araç, moloz, varil ve yağmalanabilir nesneler. Kutu modeller yalnızca görünmeyen çarpışma şekli veya geçici yer tutucu olabilir; bitmiş görsel sayılmaz.
- Yüzeyler: renk, normal ve pürüzlülük haritaları; metal yüzeylerde uygun metalness. Birbirinden kopuk kalitede varlıklar karıştırılmamalı.
- Işık: ilk denemede sabit bulutlu gündüz, bir ana ışık ve sınırlı yerel ışık. Gün/gece ile dinamik hava sistemi daha sonra eklenmeli.
- Kaynaklar: ilk yaklaşım ücretsiz ve kullanıma uygun lisanslı varlıklar. Her dosya için kaynak bağlantısı, üretici, lisans ve atıf şartı kaydedilmeli. Ücretli varlıklar bütçe belirlenmeden satın alınmamalı.

## İlk oynanabilir bölüm

Yaklaşık 50 × 50 metrelik tek sokak: animasyonlu oyuncu, iki bina cephesi, girilebilir küçük bir oda, bir terk edilmiş araç, ateş varili ve üç toplanabilir nesne.

1. Önce gerçek karakter ve çevre varlıklarıyla statik görsel deneme hazırla. Mevcut oyundaki ilkel geometrileri başka motorda tekrar üretmek görsel hedefi karşılamaz.
2. Üçüncü şahıs hareketi, duvara girmeyen kamera ve nesne etkileşimi ekle.
3. Aynı sokakta en az birkaç dakika dolaşıp kamera, animasyon geçişleri, yüzeyler ve performansı ölç.
4. Başlangıç performans hedefi: MX450 üzerinde 1280 × 720 çözünürlükte tutarlı 30 FPS. Bu bir hedef; mevcut ölçüm veya garanti değildir. Sonuca göre çözünürlük ve kalite yükseltilebilir.
5. Görsel yön kullanıcı tarafından değerlendirildikten sonra hayatta kalma ve çatışma sistemlerini taşı.

## Mevcut oynanışın taşınması

HTML dosyası Godot sahnesine doğrudan dönüşmez. Oynanış kuralları ve sayısal denge referans alınarak sistemler yeniden uygulanır.

| Kaynak sistem | PC sürümündeki karşılık |
| --- | --- |
| `updatePlayer`, `setStance`, `jump` | Karakter hareketi ve duruş durumları |
| `updateCamera` | Omuz kamerası ve kamera çarpışması |
| `makeSoldier`, `poseSoldier` | İskeletli karakter sahnesi ve animasyon durum makinesi |
| `WEAPONS`, `attack`, `reload` | Veriye dayalı silah tanımları ve çatışma sistemi |
| `findInteract`, `interact`, `renderBag` | Etkileşim, envanter ve Türkçe arayüz |
| `updateEnemy`, `enemySees`, `alertNoise` | Devriye, görüş/işitme, takip ve çatışma durumları |
| `updateEnv`, `WEATHERS` | Gün/gece, hava durumu ve sıcaklık |
| `updateFires`, `shelterAt` | Isınma, yakıt ve barınak etkileri |
| `buildWorld`, `makeBuilding`, `burntCar` | Modüler çevre sahneleri ve çarpışmalar |
| `drawMinimap`, `drawBigMap` | Küçük harita ve büyük harita |

Taşıma sırası: hareket/kamera → etkileşim/envanter → açlık/susuzluk/ısı → silahlar → tek düşman → hava durumu → genişleyen şehir.

## Çalışma düzeni ve doğrulama

Mevcut HTML referans olarak korunmalı. Yeni motor projesi ayrı dizinde geliştirilmelidir. Claude CLI ile aynı dosyalarda eşzamanlı değişiklik yapılmamalı; dosya sorumlulukları açıkça ayrılmalı. (Bkz. `docs/ORTAK_KURALLAR.md`, `docs/SAHIPLIK.md`.)

Bu aşamada oyun kodu değiştirilmedi, motor kurulmadı ve yeni 3B varlık indirilmedi. Build, export veya oyun testi çalıştırılmadı.

## Resmî kaynaklar

- Unreal donanım önerileri: https://dev.epicgames.com/documentation/en-us/unreal-engine/hardware-and-software-specifications-for-unreal-engine
- Godot renderer seçenekleri: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
