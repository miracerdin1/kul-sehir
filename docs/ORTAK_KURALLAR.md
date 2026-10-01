# Ortak çalışma kuralları (Claude + Codex)

`AGENTS.md` ve `CLAUDE.md` bu dosyaya yönlendirir. Kural değişikliği yalnızca burada yapılır.

## 1. Tek doğru kaynak: Git deposu
- Tüm iş bu depoda. Sohbette kalan karar yok sayılır; önemli karar `docs/GUNLUK.md`'ye yazılır.
- Her oturumun başında `git pull`, sonunda commit + push.
- `main` dalına doğrudan yazılmaz. Dal adı ajanla başlar:
  - `codex/<kisa-konu>` — ör. `codex/oyuncu-hareketi`
  - `claude/<kisa-konu>` — ör. `claude/kamera-carpisma`
- Birleştirme Pull Request ile. Diğer ajan veya Miraç inceler; Miraç onaylar.

## 2. Dosya sahipliği (aynı dosyaya aynı anda dokunulmaz)
- Bir dosyada/klasörde çalışmaya başlamadan önce `docs/SAHIPLIK.md` tablosuna satır ekle, commit + push et. Bu "kilit"tir.
- Tabloda başkasına ait bir yol varsa ona **dokunma**. Değişiklik gerekiyorsa `docs/GUNLUK.md`'ye "Diğer ajandan istek" olarak yaz.
- İş bitince (PR birleşince) satırı sil.
- Ortak dosyalar (`docs/*.md`, `AGENTS.md`, `CLAUDE.md`) kilitlenmez; küçük, ekleme yönünde değişiklik yapılır ve hemen push edilir.
- `reference/` salt okunur.

## 3. Günlük (devir notu)
Her oturum sonunda `docs/GUNLUK.md` dosyasının **en üstüne** bir kayıt eklenir:
```
## YYYY-AA-GG — Codex|Claude — dal: <dal adı>
Yapılan: ...
Değişen dosyalar: ...
Test edilen / edilmeyen: ...
Açık kalan / diğer ajana not: ...
```
"Test edilen / edilmeyen" satırı dürüst olmalı: çalıştırılmadıysa "çalıştırılmadı" yaz.

## 4. Commit mesajları
- Türkçe, kısa, başta etiket: `[Codex]` veya `[Claude]`. Ör: `[Claude] Omuz kamerasına çarpışma eklendi`
- Böylece `git log --oneline` ile kimin ne yaptığı tek bakışta görülür.

## 5. Varlıklar (3B model, doku, ses)
- Yalnızca lisansı açık, ücretsiz varlık. Satın alma Miraç onayı olmadan yapılmaz.
- Eklenen her dosya `assets/KAYNAKLAR.md` tablosuna yazılır (kaynak bağlantısı, üretici, lisans, atıf şartı).
- Büyük ikili dosyalar için Git LFS ilk varlık eklenmeden önce kararlaştırılır.

## 6. Teknik kararlar
- Motor: Godot 4, proje `godot/` klasöründe. İlk denemede Mobile renderer, gerekirse Compatibility.
- Hedef: MX450 üzerinde 1280×720'de tutarlı 30 FPS (hedef, ölçüm değil).
- Ayrıntı ve sıra: `docs/GORSEL_GECIS_PLANI.md`.
- Planı değiştiren karar günlüğe "KARAR" başlığıyla yazılır.
