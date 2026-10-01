# Varlık kaynakları

## Çevre — Poly Haven, CC0-1.0

Powered by [Poly Haven](https://polyhaven.com).

Modeller: covered_car, barrel_stove, concrete_road_barrier, metal_jerrycan, long_life_food, can_rusted, rock_04.

Dokular: aerial_asphalt_01, brick_wall_001, blue_plaster_weathered, rubble. 1K renk, normal ve pürüzlülük haritaları kullanılır.

Her varlığın üreticisi, tam kaynak bağlantıları ve dosya doğrulama değerleri [assets/manifest.json](assets/manifest.json) içindedir. Lisans: https://polyhaven.com/license

## Karakter ve animasyon — Adobe Mixamo

SWAT karakteri ile Idle, Walk, Slow_Run, Sprint, Crouch_Idle, Crouch_Walking, Crawling, Jump, Kneeling_Down, Rifle_Aiming_Idle, Pistol_Idle, Rifle_Idle, Stabbing ve Death animasyonları Mixamo kaynaklıdır (oyundaki klip listesi `tools/prepare_character.py` içindeki `CLIPS`). Karakterin GLB dönüşümü three.ws, hareket kliplerinin GLB dönüşümleri deevid-mixamo-assets üzerinden alınmıştır. Yerelde animasyonlar SWAT iskeletine uyarlanmış, yatay kök hareketi kaldırılmıştır.

- Karakter kaynak kataloğu: https://github.com/nirholas/three.ws/blob/main/public/avatars/mixamo/catalog.json
- Animasyon dönüşüm kaynağı: https://github.com/MisterYI/deevid-mixamo-assets
- Adobe kullanım açıklaması: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- Tam dosya URL'leri ve SHA256 kayıtları: [assets/characters/survivor.credits.json](assets/characters/survivor.credits.json)

Bu varlıklar **CC0 değildir**. Oyun projesi içindeki kullanım için tutulur; bağımsız karakter/animasyon paketi olarak yayımlanmamalıdır. Oyunun kaynak koduna verilecek bir lisans, Adobe varlıklarının lisansını değiştirmez.

## Yazı tipi

Barlow Condensed — Copyright 2017 The Barlow Project Authors. SIL Open Font License 1.1. Lisans metni: [assets/fonts/OFL.txt](assets/fonts/OFL.txt). Kaynak: https://github.com/google/fonts/tree/main/ofl/barlowcondensed

## Sesler

Adım ve ortam sesleri bu proje için `tools/prepare_audio_fonts.py` ile sentezlendi. Harici ses kaydı kullanılmadı.

## Motor

Godot Engine 4.7.2 — MIT lisansı. https://godotengine.org/license/

Motorun üçüncü taraf bildirimleri: https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt
