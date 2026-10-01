# Değişiklik ve devir günlüğü

Yeni kayıt en üste. Şablon `ORTAK_KURALLAR.md` §3'te.

## 2026-10-01 — Claude — dal: claude/karakter-hareketi
Yapılan: Miraç'ın "karakterin bazı hareketleri tuhaf" bildirimi üzerine animasyonlar ölçüldü. Neden: kaynak kütüphanedeki `Running.glb` aslında koşu değil, iki ayak yerde sabit kalıyor; karakter 5 m/s giderken ayakları kayıyordu. Ayrıca yürüme klibi doğal hızının (1.1 m/s) 2.4 katı hızda hareket ederken 1x oynuyordu. Her klibin doğal hızı yere basan ayaktan ölçülüp doğru klipler seçildi (Walk, Slow_Run, Sprint, Crouch_Idle, Crouch_Walking, Crawling, Falling). Animasyon artık tuşa göre değil gerçek yer hızına göre seçiliyor ve klip hızı yer hızına oranlanıyor. HTML'den eklenenler: çömelme (C/Ctrl), yere yatma ve sürünme (Z), Alt ile yürüme, depar/dayanıklılık oranları, havadayken düşme animasyonu, alçak tavan altında ayağa kalkamama, çömelikken depar veya zıplama ile ayağa kalkma. Kamera yüksekliği ve çarpışma kapsülü duruşa göre değişiyor.
Değişen dosyalar: `godot/scripts/survivor.gd`, `godot/scripts/input_bindings.gd`, `godot/tests/prototype_qa.gd`, `tools/prepare_character.py`, `README.md`, `docs/SAHIPLIK.md`, `docs/GUNLUK.md`.
Test edilen / edilmeyen: Godot 4.7.2 headless ile 40 kontrol geçti (eski 24 + 16 yeni hareket kontrolü). SWAT modeli bulut ortamından indirilemediği için testler aynı Mixamo iskeletiyle, görünmez yer tutucu karakterle yapıldı; gerçek SWAT görüntüsü ve MX450 performansı test edilmedi.
Açık kalan / diğer ajana not: Yeni klipler için yerelde `python tools/prepare_character.py` yeniden çalıştırılmalı (survivor.credits.json da güncellenir, commit edilmeli). Codex: `godot/` kilidin sürüyor; Miraç'ın isteğiyle yalnızca yukarıdaki dosyalara dokundum ve bu dosyaları sahiplik tablosuna Claude adına yazdım. Sıradaki önerim açlık/susuzluk/kan/ıslaklık sistemini Claude'un, gün/gece ve havayı Codex'in (`street.gd`) alması.

## 2026-10-01 — Codex — dal: codex/ilk-sokak (oynanabilir prototip)
Yapılan: Önceki yerel prototip ortak depoya aktarıldı: Godot 4.7.2 / Mobile proje, sokak, karakter hareketi ve kamera, üç malzemeli görev, çanta, ısınma, Türkçe arayüz, başlatıcılar ve hazırlık betikleri. Ücretsiz çevre modelleri/dokuları, fontlar ve sentezlenen sesler Git LFS ile eklendi. Varlıkların dosya bazlı kaynakları `assets/KAYNAKLAR.md` içinde kayıtlı.
Değişen dosyalar: `godot/`, `tools/`, `Baslat.ps1`, `Editoru-Ac.ps1`, `Oyunu-Baslat.cmd`, `.gitattributes`, `.gitignore`, `README.md`, `assets/KAYNAKLAR.md`, `docs/GUNLUK.md`. `reference/` değiştirilmedi.
Test edilen / edilmeyen: Ortak depo konumunda Godot headless import hatasız tamamlandı ve 24 oynanış kontrolü geçti. `git diff --check` kontrol edildi. Bu aktarımda yeni GPU performans testi yapılmadı; README'deki kısa FPS ölçümü önceki yerel prototipe ait. Build/export çalıştırılmadı.
Açık kalan / diğer ajana not: Claude incelemeyi `codex/ilk-sokak` dalındaki PR üzerinden yapabilir. Klondan sonra `git lfs pull`, `python tools/setup_assets.py`, `python tools/prepare_audio_fonts.py`, `python tools/prepare_character.py` ve README'deki Godot import komutu çalıştırılmalı. Mixamo ham modeli/dokuları depoda yoktur; yerel hazırlık zorunludur. `.tools/`, `.cache/`, `.godot/` ve QA ekran görüntüleri gönderilmedi. Sonrasında `Oyunu-Baslat.cmd` ile oyun, README'deki `--smoke-test` komutuyla kontroller açılır. İnceleme odağı: kamera çarpışması, animasyon uyarlaması, malzeme etkileşimleri ve sonraki modüler sahne ayrımı. Çatışma, düşman, kayıt ve geniş hayatta kalma sistemleri henüz taşınmadı. Sahiplik PR incelemesi boyunca Codex'te; Claude düzeltme yapacaksa günlük üzerinden yol devri koordine edilmeli.

## 2026-10-01 — Codex — dal: codex/ilk-sokak (aktarım başlangıcı)
Yapılan: Miraç oyun dosyalarının push edilmesini ve Claude tarafından incelenmesini istedi. Güncel `origin/main` üzerinden aktarım dalı açıldı; ilgili yolların sahipliği alındı.
KARAR: İlk ikili varlık eklenmeden önce Git LFS seçildi. Model tamponları, dokular, sesler ve fontlar LFS ile tutulacak. Godot çalıştırıcısı, önbellekler ve QA çıktıları depoya girmeyecek. Mixamo karakterinin ham modeli ve ayrıştırılmış dokuları herkese açık kaynak deposuna eklenmeyecek; yerel hazırlama betiği ve kaynak/lisans kaydı sağlanacak.
Değişen dosyalar: `docs/SAHIPLIK.md`, `docs/GUNLUK.md`.
Test edilen / edilmeyen: Git LFS kurulu ve depo için etkin; oyun aktarımı ve testler henüz yapılmadı. Build/export çalıştırılmadı.
Açık kalan / diğer ajana not: Claude, `codex/ilk-sokak` dalı ve açılacak PR üzerinden inceleme yapabilir. Başlangıç kilidi aktarım öncesinde push edilir; tamamlanma ve doğrulama sonuçları ayrı günlük kaydıyla eklenecek.

## 2026-10-01 — Codex — dal: codex/godot-sahiplik
Yapılan: Depo yerelde klonlandı, `git pull --ff-only` çalıştırıldı ve Codex masaüstü uygulamasında açıldı. `AGENTS.md`, `docs/ORTAK_KURALLAR.md`, `docs/SAHIPLIK.md` ve günlük okundu. Miraç'ın açık isteğiyle `godot/` yolu Codex adına sahiplik tablosuna kaydedildi.
Değişen dosyalar: `docs/SAHIPLIK.md`, `docs/GUNLUK.md`.
Test edilen / edilmeyen: Yalnızca dokümantasyon değişikliği; `git diff --check` kontrol edildi. Oyun testi ve build/export bu oturumda çalıştırılmadı.
Açık kalan / diğer ajana not: Önceki Codex çalışmasında kardeş `../Oyun/godot/` klasöründe Godot 4.7.2 / Mobile ile oynanabilir ilk sokak hazırlandı; hareket, kamera, üç malzemeli görev, çanta ve ısınma mevcut. O çalışmada 24 oynanış kontrolü geçti, MX450 üzerinde kısa görüntü kontrollerinde yaklaşık 48–60 FPS görüldü; bunlar bu deponun doğrulaması değildir. Prototip ve ikili varlıklar henüz bu depoya taşınmadı. Aktarım öncesinde Git LFS tercihi ve her varlığın `assets/KAYNAKLAR.md` kaydı tamamlanmalı. Kalıcı alan önerisi korunuyor; `godot/` kilidi ilk aktarım içindir. Claude bu alanda çalışmadan önce günlük üzerinden dosya devri koordine edilmeli. Sahiplik kaydı bu dalda push edilerek görünür olacak; PR birleştirmesi Miraç onayına bırakılacak.

## 2026-10-01 — Claude — dal: main (ilk kurulum)
Yapılan: Depo iskeleti kuruldu. Orijinal oyun `reference/kul-sehir.html` olarak eklendi. Codex'in görsel geçiş planı `docs/GORSEL_GECIS_PLANI.md` olarak eklendi. Ortak kurallar, sahiplik tablosu ve bu günlük oluşturuldu.
Değişen dosyalar: tümü yeni.
Test edilen / edilmeyen: Kod yok; motor kurulmadı, varlık indirilmedi.
Açık kalan / diğer ajana not: Codex, `ORTAK_KURALLAR.md` ve `SAHIPLIK.md`'deki kalıcı alan önerisini oku; itirazın varsa buraya yaz. İlk iş planın 1. adımı (statik görsel deneme) — kimin alacağına Miraç karar verecek.
