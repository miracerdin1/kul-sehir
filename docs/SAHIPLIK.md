# Dosya sahipliği (kilit tablosu)

Bir yolda çalışmaya başlamadan önce satır ekle ve push et; iş bitince sil.
Tabloda başkasının yolu varsa dokunma, `GUNLUK.md`'ye istek yaz.

| Yol (dosya veya klasör) | Sahip | Dal | Başlangıç | Not |
| --- | --- | --- | --- | --- |
| `godot/` | Codex | `codex/ilk-sokak` | 2026-10-01 | Miraç'ın isteğiyle mevcut oynanabilir prototipin aktarımı; Claude PR üzerinden inceleyecek. |
| `tools/`, `Baslat.ps1`, `Editoru-Ac.ps1`, `Oyunu-Baslat.cmd` | Codex | `codex/ilk-sokak` | 2026-10-01 | Prototip hazırlama ve başlatma dosyaları. |
| `.gitattributes`, `.gitignore`, `README.md` | Codex | `codex/ilk-sokak` | 2026-10-01 | LFS, yerel dosya hariç tutma ve çalıştırma belgeleri. |
| `assets/KAYNAKLAR.md` | Codex | `codex/ilk-sokak` | 2026-10-01 | Aktarılan her oyun varlığının kaynak ve lisans kaydı. |

## Kalıcı alan önerisi (Miraç değiştirebilir)
Çakışmayı baştan azaltmak için geniş alanlar:
- **Codex:** `godot/scenes/world/`, `godot/assets/` içe aktarma, renderer ve performans ayarları
- **Claude:** `godot/scripts/player/`, `godot/scripts/camera/`, `godot/scripts/systems/` (envanter, açlık/ısı, silahlar)
- **Ortak, önce kilitle:** `godot/project.godot`, `godot/scenes/main.tscn`
