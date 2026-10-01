# Dosya sahipliği (kilit tablosu)

Bir yolda çalışmaya başlamadan önce satır ekle ve push et; iş bitince sil.
Tabloda başkasının yolu varsa dokunma, `GUNLUK.md`'ye istek yaz.

| Yol (dosya veya klasör) | Sahip | Dal | Başlangıç | Not |
| --- | --- | --- | --- | --- |
| `godot/scripts/survivor.gd`, `godot/scripts/expedition.gd`, `godot/scripts/input_bindings.gd`, `godot/scripts/combat/`, `godot/scripts/city/`, `godot/tests/`, `tools/`, `Baslat.ps1`, `Editoru-Ac.ps1`, `Oyunu-Baslat.cmd`, `Performans-Testi.cmd`, `README.md`, `.gitattributes`, `.gitignore`, `assets/KAYNAKLAR.md`, `godot/CREDITS.md`, `godot/assets/weapons/` | Claude | `claude/sehir-binalar` | 2026-10-01 | Codex'in token hakkı bitti; Miraç'ın isteğiyle Codex'in açık işleri (şehir performans testi, README, kaynak kayıtları, silah modelleri) Claude'da. Birleşmiş PR'ların eski kilitleri kaldırıldı. Codex dönünce bu satır daraltılır. |

## Kalıcı alan önerisi (Miraç değiştirebilir)
Çakışmayı baştan azaltmak için geniş alanlar:
- **Codex:** `godot/scenes/world/`, `godot/assets/` içe aktarma, renderer ve performans ayarları
- **Claude:** `godot/scripts/player/`, `godot/scripts/camera/`, `godot/scripts/systems/` (envanter, açlık/ısı, silahlar)
- **Ortak, önce kilitle:** `godot/project.godot`, `godot/scenes/main.tscn`
