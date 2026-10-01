# Değişiklik ve devir günlüğü

Yeni kayıt en üste. Şablon `ORTAK_KURALLAR.md` §3'te.

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
