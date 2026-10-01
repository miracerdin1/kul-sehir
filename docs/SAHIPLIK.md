# Dosya sahipliği (kilit tablosu)

Bir yolda çalışmaya başlamadan önce satır ekle ve push et; iş bitince sil.
Tabloda başkasının yolu varsa dokunma, `GUNLUK.md`'ye istek yaz.

| Yol (dosya veya klasör) | Sahip | Dal | Başlangıç | Not |
| --- | --- | --- | --- | --- |
| `godot/scripts/street.gd`, `godot/scripts/world/`, `godot/tests/weather_qa.gd`, `godot/assets/characters/survivor.credits.json` | Codex | `codex/gun-gece-hava` | 2026-10-01 | Gün/gece ve hava durumu; karakter hazırlık betiğinin ürettiği kaynak kaydı. Hayatta kalma ve Claude'un hareket dosyaları kapsam dışında. |
| `godot/scripts/survivor.gd`, `godot/scripts/expedition.gd`, `godot/scripts/input_bindings.gd`, `godot/scripts/combat/`, `godot/scripts/city/`, `godot/tests/prototype_qa.gd`, `tools/prepare_character.py` | Claude | `claude/buyuk-harita` | 2026-10-01 | Karakter hareketi, animasyonlar, etkileşim, silah ve düşman sistemi, şehir haritası. |
| `tools/`, `Baslat.ps1`, `Editoru-Ac.ps1`, `Oyunu-Baslat.cmd` | Codex | `codex/ilk-sokak` | 2026-10-01 | Prototip hazırlama ve başlatma dosyaları. |
| `.gitattributes`, `.gitignore`, `README.md` | Codex | `codex/ilk-sokak` | 2026-10-01 | LFS, yerel dosya hariç tutma ve çalıştırma belgeleri. |
| `assets/KAYNAKLAR.md` | Codex | `codex/ilk-sokak` | 2026-10-01 | Aktarılan her oyun varlığının kaynak ve lisans kaydı. |

## Kalıcı alan önerisi (Miraç değiştirebilir)
Çakışmayı baştan azaltmak için geniş alanlar:
- **Codex:** `godot/scenes/world/`, `godot/assets/` içe aktarma, renderer ve performans ayarları
- **Claude:** `godot/scripts/player/`, `godot/scripts/camera/`, `godot/scripts/systems/` (envanter, açlık/ısı, silahlar)
- **Ortak, önce kilitle:** `godot/project.godot`, `godot/scenes/main.tscn`
