# BETA PROTOCOL

Tasarım Fabrikası Game Jam için Godot 4.7 ile yapılmış, retro-pixel dokulu bir birinci şahıs nişancı. Bu repo oyunun **v0.3.1** sürümünü içeriyor: 5 kat, 4 bulmaca, 3 aşamalı Viktor Volkov boss savaşı, final sinematiği, 5 kademeli BETA evrimi, iki zorluk seviyesi, telsiz iletişimi ve 4 sekmeli ayar menüsü.

## Hikâye

Deneysel **Beta Reaktörü** çalındı. Reaktör artık **Viktor Volkov**'un elinde. Volkov'un paralı ekibi binayı ele geçirdi ve General'in BETA araştırmasını kendi ağına aktardı. **General**, ajan **Aydın**'ı göreve çağırır ve ona deneysel yenilenme cihazı olan **BETA Cihazı**'nı verir.

Hedef beş katlı bir holding binası. Çatıdaki deneysel savunma sistemi hava desteğini engellediği için Aydın binaya tek başına girer ve katları tek tek temizleyerek reaktörü en üst kattan geri almaya çalışır.

BETA Cihazı yaşam enerjisini **yeni düşmüş düşmanlardan** çeker. Kendiliğinden can dolumu yoktur. Hayatta kalmak için çatışmaya girmek gerekir.

### Hikâye akışı

1. **Açılış — Köy evi.** Sakin köy hayatı General'in telsiziyle bozulur. Aydın BETA Cihazı'nı alır ve kuleye gider.
2. **Kat 1 — Lobi.** Güvenlik hattı aşılır, hareketli kilitli güvenlik kapısı kırılır.
3. **Kat 2 — Ofis ve Arşiv.** Arşiv sunucularında BETA araştırmasının Volkov'un özel ağına aktarıldığı ortaya çıkar. Yönetici kapısı devre kilidiyle açılır.
4. **Kat 3 — Biyoteknoloji Laboratuvarı.** BETA serumuyla beslenen exo-zırh denemeleri ve "Volkov Modeli" prototipi bulunur. Biyometrik kilit çözülür.
5. **Kat 4 — VIP ve Kumarhane.** Volkov'un çatı tahliye emri ele geçirilir. Komandoların mühürlediği kasa kapısı sembol sıralamasıyla açılır.
6. **Kat 5 — Çatı ve Beta Reaktörü.** Yağmur altında, exo-zırhlı **Viktor Volkov** ile 3 aşamalı final savaşı. Volkov düşünce reaktör konsolu açılır ve savunma kulesi kapatılır.
7. **Final sinematiği.** Tahliye helikopterleri çatıya iner. Haftalar sonra Aydın köyündeki sakin hayatına döner. Özet kartıyla oyun biter.

## Oyun kapsamı (v0.3.0)

| Bölüm | İçerik |
|---|---|
| Ana menü | Yeni Oyun, Devam Et (kayıt varsa), Ayarlar, Geliştirici Ekibi, Çıkış |
| Açılış sahnesi | Köy evi, Aydın ve General diyaloğu. Basılı tutarak atlanabilir (5 sn). |
| Sistemler | Tabanca, pompalı tüfek, bıçak; düşman yapay zekâsı (IDLE → PATROL → ALERT → CHASE → ATTACK), seri atış ve sendeleme direnci; BETA emilimi ve 5 kademeli evrim; Overdrive; ölüm ekranı; duraklatma menüsü; kat başına kayıt ve can/maks can/öz/kademe aktarımı; boss can barı; telsiz iletişimi; CRT/VHS ekran filtresi |
| Ayarlar | 4 sekme: Oynanış, Görüntü & Performans, Ses, Kontroller (ayrıntı aşağıda) |

### 5 kat ve 4 bulmaca

| Kat | Mekân | Düşmanlar | Kilit / Hedef | Çıkış |
|---|---|---|---|---|
| **1 — Lobi ve Güvenlik** | Lobi, güvenlik hattı, lore terminalleri, BETA öğretici ipucu | Lv1 Muhafız, Lv2 Paralı Asker | **Hareketli Kilit**: 3 aşamalı hareketli çubuk hizalama (`moving_lock_puzzle`) | Asansör → Kat 2 |
| **2 — Ofis ve Arşiv** | Ofis koridorları, arşiv sunucuları, yönetici odası | Lv1 Teknisyen, Lv2 Paralı Asker | **Devre Bağlantısı**: 3×3 kablo karolarını çevirip devreyi tamamla (`circuit_puzzle`) | Asansör → Kat 3 |
| **3 — Biyoteknoloji Laboratuvarı** | Biyo-tüpler, exo-zırh test odası, titreyen acil ışıklar | Lv3 Ağır Paralı Asker, Lv1 Teknisyen | **Biyolojik Renk/Sembol Eşleştirme**: 4 numuneyi doğru hazneyle eşleştir (`bio_match_puzzle`) | Asansör → Kat 4 |
| **4 — VIP ve Kumarhane** | Kumarhane salonu, VIP lounge, güvenlik odası, kasa | Lv4 Elit Komando, Lv2 Paralı Asker, Lv1 Muhafız | **Sembol Sıralaması**: 4 adımlı sembol kodunu doğru sırayla gir (`sequence_puzzle`) | Asansör → Çatı |
| **5 — Çatı ve Reaktör** | Yağmurlu çatı, Beta Reaktörü çekirdeği, işaret ışıkları | **Viktor Volkov** (boss) + aşama takviyeleri (Lv1 Muhafız/Teknisyen) | 3 aşamalı boss savaşı → **Reaktör Konsolu** (Volkov ölünce açılır) | Final sinematiği |

### Düşman seviyeleri

Değerler **Normal** zorluktadır. Saldırı aralığı, iki atış/seri arasındaki süredir.

| Seviye | Düşman | Can | Hasar | Saldırı aralığı | Seri | Sendeleme direnci |
|---|---|---|---|---|---|---|
| 1 | Güvenlik Görevlisi | 40 | 6 | 0.90 sn | 1 | – |
| 1 | Silahlı Teknisyen | 48 | 7 | 0.90 sn | 1 | – |
| 2 | Paralı Asker | 85 | 9 | 1.15 sn | 2 | – |
| 3 | Ağır Paralı Asker | 155 | 16 | 1.40 sn | 2 | 0.65 |
| 4 | Elit Komando | 220 | 19 | 1.55 sn | 3 | 0.45 |
| 5 | Exo Asker (`enemy_lv5_exo`, yedek boss verisi) | 800 | 22 | 1.65 sn | 3 | – |
| Boss | **Viktor Volkov** (exo-zırh, Lv5) | **800** | mermi başına seri atış + şok dalgası | aşamalarla hızlanır | – | – |

**Volkov'un 3 aşaması:**
- **Aşama 1 (%100–66):** 3 mermilik seri atış. Yakına gelince yere vurup şok dalgası yayar (4.5 m).
- **Aşama 2 (≤ %65):** hızlanır, yana atılarak kaçar, 4 mermilik yelpaze atış yapar. 2 takviye düşman gelir.
- **Aşama 3 (≤ %30):** mavi plazma moduna geçer, 6 mermilik hızlı seri atış yapar, şok dalgası 24 hasar verir. 2 takviye daha gelir.
- Ölünce cesedi BETA ile Lv5 emilimi verir (+20 maks can, M × %30 + 20 iyileşme, 100 öz) ve reaktör konsolu açılır.

### BETA Cihazı ve emilim

- Taze bir cesedin yanında **F** ile kanal açılır. Kanal **0.85 sn** sürer, Kademe 4 ve üstünde **0.60 sn**.
- Her ceset **bir kez** kullanılabilir. Kendiliğinden can dolumu yoktur.
- Emilim, mevcut maksimum canı (aşağıdaki tabloda *M*) kalıcı olarak artırır, canı doldurur ve **Biyo-Öz** verir.
- Maksimum can **100 ile başlar, en fazla 250** olur. Can tamamen doluyken de emilim yapılabilir. 250 sınırındayken maks can artmaz ama öz ve Overdrive yine verilir.
- Her emilimden sonra **Overdrive** 5 sn açılır: hareket hızı ayrıca ×1.12.

| Ceset seviyesi | Maks can artışı | İyileşme | Biyo-Öz |
|---|---|---|---|
| Lv1 | +4 | M × %12 + 4 | 15 |
| Lv2 | +6 | M × %15 + 6 | 25 |
| Lv3 | +9 | M × %18 + 9 | 40 |
| Lv4 | +12 | M × %22 + 12 | 65 |
| Lv5 / Volkov | +20 | M × %30 + 20 | 100 |

Örnek: 50/100 HP iken Lv2 ceset → **71/106**. 60/100 HP iken Volkov → **110/120**.

### BETA evrim kademeleri

Toplanan Biyo-Öz kademeyi belirler. Kademe ve öz kat geçişlerinde korunur.

| Kademe | Öz eşiği | Hasar | Şarjör hızı | Hareket | Ek |
|---|---|---|---|---|---|
| 1 | 0 | ×1.00 | ×1.00 | ×1.00 | – |
| 2 | 45 | ×1.10 | ×1.12 | ×1.03 | – |
| 3 | 120 | ×1.20 | ×1.20 | ×1.07 | – |
| 4 | 230 | ×1.32 | ×1.28 | ×1.11 | Kanal 0.60 sn |
| 5 | 370 | ×1.45 | ×1.35 | ×1.15 | Kanal 0.60 sn, **yakın dövüş öldürmesi +6 HP çalar** |

### Zorluk

| Ayar | Düşman canı | Düşman hasarı | Düşman hızı |
|---|---|---|---|
| **Normal** | ×1.00 | ×1.00 | ×1.00 |
| **Bordo Bereli** | ×1.25 | ×1.30 | ×1.12 |

Çarpanlar yeni doğan her düşmanın kendi istatistik kopyasına uygulanır. Paylaşılan `.tres` dosyaları değişmez.

### Telsiz iletişimi

General Demir ve Aydın, katlar boyunca sağ üstteki telsiz kutusundan konuşur: portre, konuşan adı ve metin. Mesajlar sıraya alınır ve süre dolunca kayarak kapanır. Kod tarafında tek çağrı yeterli:

```gdscript
GameManager.send_radio("GENERAL DEMİR", "general_portrait", "BETA hazır.", 6.0)
```

Portre `res://assets/portraits/<ad>.png` dosyasından yüklenir. Kutu görev plakası ve cephane paneliyle çakışmaz.

### Ayarlar menüsü

| Sekme | İçerik |
|---|---|
| **Oynanış** | Fare hassasiyeti, görüş açısı (FOV 75–120, varsayılan 100), zorluk (Normal / Bordo Bereli), kamera sarsıntısı |
| **Görüntü & Performans** | Tam ekran, CRT/VHS filtresi, grafik kalitesi (**Düşük / Orta / Yüksek**), **VSync**, **FPS sayacı** |
| **Ses** | Ana ses, müzik, efekt |
| **Kontroller** | Tuş listesi |

Grafik kalitesi: **Yüksek** glow efektini açar. **Düşük** Kat 5 yağmur parçacıklarını 160'tan 60'a düşürür. Tüm katlarda OmniLight3D ışıkları mesafeyle söner (16 m + 8 m). CRT filtresi nearest örnekleme kullanır. "Varsayılana Sıfırla" Normal / Orta / VSync açık / FPS kapalı değerlerine döner.

## Kontroller

| Tuş | Eylem |
|---|---|
| W A S D | Hareket |
| Fare | Nişan / bakış |
| Sol tık | Ateş |
| Sağ tık | Alternatif nişan |
| Shift | Koşu (FOV artışı) |
| Ctrl | Eğilme |
| Space | Zıplama |
| R | Şarjör değiştir |
| Q | Hızlı bıçak |
| 1 / 2 / 3 | Silah seç (Tabanca / Pompalı / Bıçak) |
| E | Etkileşim (kapı, terminal, konsol) |
| F | BETA Protokolü (cesetten can topla) |
| Esc | Duraklat / bulmacadan çık |

Fare hassasiyeti, FOV (varsayılan 100), ses seviyeleri, ekran sarsıntısı ve CRT filtresi **Ayarlar** menüsünden değiştirilebilir.

Bulmaca terminalleri fareyle oynanır. Sinematiklerde **Space** 5 sn basılı tutulursa sahne atlanır.

## Mimari

Dört **autoload** var ve sırası önemli:

| Autoload | Görev |
|---|---|
| `SettingsManager` | Ayarları `user://settings.cfg` dosyasında tutar. `settings_changed` sinyalini yayar. |
| `AudioManager` | 12 kanallı SFX havuzu ve döngülü müzik çalar. Ses adlarını `res://assets/audio/` altında çözer. Eksik dosyada sessizce geçer. |
| `SaveManager` | Kat ilerlemesini ve oyuncu durumunu `user://savegame.cfg` dosyasına yazar. |
| `GameManager` | Kat akışı, görev metni, HUD ve boss bar iletimi, input güvenlik ağı, CRT katmanı, düzgün çıkış (`quit_game`). |

Oyuncu ve düşmanlar bileşenlerden oluşur:
- `HealthComponent` canı yönetir.
- `FpsCamera` bakışı, FOV'u ve sarsıntıyı yönetir.
- `WeaponManager` silahları yönetir ve verisini `WeaponStats` `.tres` kaynaklarından alır.
- `BetaDeviceController` can toplamayı yönetir.
- `EnemyBase` bir durum makinesidir ve verisini `EnemyStats` `.tres` kaynaklarından alır. Sprite kareleri `sprite_prefix` ile `assets/sprites/enemies/` altından bulunur. Dışa aktarılmış `.exe` içinde klasör listesi boş dönerse doğrudan dosya yolu yedeği devreye girer.
- `VolkovBoss` (`volkov_boss.gd`) `EnemyBase`'i genişletir: 3 aşama, şok dalgası, seri atış, yana atılma. Aşama değişiklikleri kopyalanmış `EnemyStats` üzerinde yapılır, ortak `.tres` değişmez.
- Kilitli kapılar (`locked_door.gd`) bulmaca sahnesini `puzzle_scene` ile alır. Tüm bulmacalar ortak `TerminalModal` sınıfını genişletir (`puzzle_solved`, `puzzle_cancelled`, `solve_for_test()`).
- Kat controller'ları (`floor_0X_controller.gd`) müzik, görev metni, dokular ve kapı bulmacasını kurar. Kat 5 controller'ı ayrıca boss'u, reaktör konsolunu, takviye dalgalarını ve yağmur parçacıklarını oluşturur.

### Klasör yapısı

```
assets/
  audio/        müzik (bgm_*) ve efektler (sfx_*), WAV
  portraits/    diyalog portreleri
  shaders/      crt_vhs.gdshader
  sprites/      silah, düşman (Lv1–Lv4 + Volkov) ve sinematik arka planları
  textures/     kat dokuları (f1_* … f5_*)
scenes/
  cutscenes/    opening_cutscene.tscn, ending_cutscene.tscn
  enemies/      enemy_base, guard_lv1, tech_lv1, merc_lv2, heavy_lv3, commando_lv4, boss_volkov
  levels/       floor_01_lobby … floor_05_rooftop (.tscn)
  player/       player.tscn
  puzzles/      locked_door, lore_terminal, level_exit, moving_lock_puzzle, circuit_puzzle,
                bio_match_puzzle, sequence_puzzle, reactor_console, vertical_slice_console
  ui/           main_menu, hud, pause_menu, death_screen, settings_panel, credits_panel, crt_overlay
  weapons/      bullet_impact, pickup_item
scripts/
  components/   health_component, fps_camera, beta_device_controller
  managers/     settings, audio, save, game (autoload)
  resources/    enemy_stats, weapon_stats + enemies/*.tres, weapons/*.tres
  systems/      oyuncu, düşman, silah, UI, kat controller'ları, bulmaca ve terminal scriptleri
tests/
  run_tests.gd     22 kabul testi (headless)
  render_smoke.gd  Forward+ görüntü kontrolü (pencereli, Kat 3–5 + final)
tools/
  build_levels.py       Kat 1 sahnesini üretir
  build_full_levels.py  Kat 2–5 sahnelerini üretir
  generate_*.py         pixel-art ve synth ses üreticileri
```

## Projeyi açma

1. **Godot 4.7** (standart sürüm, .NET gerekmez) indirin.
2. Godot Proje Yöneticisi'nde **İçe Aktar** deyip bu klasördeki `project.godot` dosyasını seçin.
3. İlk açılışta Godot asset'leri içe aktarır. Bu birkaç saniye sürebilir.
4. **F5** ile çalıştırın. Ana sahne `scenes/ui/main_menu.tscn`.

Proje **Forward+** renderer kullanıyor (Vulkan destekli GPU gerekir). Tek bir katı doğrudan denemek için `scenes/levels/` altındaki bir kat sahnesini (ör. `floor_05_rooftop.tscn`) açıp **F6** ile çalıştırabilirsiniz.

## Testler

29 kabul testi gerçek sahneleri ve fizik adımlarını kullanır. Komut satırından:

```bash
godot --headless --audio-driver Dummy --path . --script res://tests/run_tests.gd
```

Windows'ta `godot` yerine kurulu Godot konsol exe'sinin yolunu yazın (`Godot_v4.7.2-stable_win64_console.exe`).

Beklenen çıktı ve çıkış kodu:

```
==== BETA PROTOCOL ACCEPTANCE: 29/29 PASSED ====
```

Hepsi geçerse çıkış kodu `0`, değilse `1` olur. Testler kullanıcının ayar ve kayıt dosyalarını değiştirmez. Önceki kayıt varsa test sonunda geri yüklenir.

Testlerin kapsadığı alanlar:
- menü ve ayarlar
- FOV
- duvar çarpışması
- silahlar
- düşman algısı ve istatistikleri
- ölüm ekranı
- BETA can tablosu, tek kullanım ve can sınırı
- cutscene atlama
- hareketli kilit bulmacası
- kilitli kapı
- kat geçişi ve kayıt
- duraklatma
- tüm kaynakların yüklenmesi
- Kat 2: devre kilidi ve Kat 3 çıkışı (17)
- Kat 3: Lv3 ağır asker + Lv1 teknisyen, biyometrik kilit, Kat 4 çıkışı (18)
- Kat 4: Lv4 komando + Lv2 paralı asker, sembol sıralama kilidi, Kat 5 çıkışı (19)
- Kat 5: Volkov 800 HP ve 3 aşaması, takviye dalgaları, Lv5 emilimi 60/100 → 110/120, reaktör konsolu, yağmur ≤ 160 (20)
- final sinematiği: epilog, atlama, özet kartı (21)
- tam proje bütünlüğü: her `.tscn/.tres/.gdshader/.png/.wav/.gd` yüklenir, her sahne örneklenir (22)
- BETA evrimi: öz eşikleri, Kademe 5 çarpanları, hızlı kanal, Overdrive, T5 can çalma, kat geçişinde aktarım (23)
- Bordo Bereli zorluk çarpanları; paylaşılan `.tres` değişmez (24)
- sprite boyutları: 17 silah 320×200, 3 kareli ölüm animasyonları, arka planlar 480×270, portreler 160×160 (25)
- 1280×720'de sıfır çakışma UI denetimi: menüler, 4 ayar sekmesi, HUD, sinematikler, 4 bulmaca (26)
- render/performans: CRT nearest filtre, kaliteye göre glow, 5 katta ışık mesafe sönümü (27)
- Kat 1 ipucu bandı ve telsiz kutusu yerleşimi (28)
- Gerçek `[E]` etkileşimi ile Kat 1 → Kat 2 → Kat 3 → Kat 4 → Kat 5 asansör geçişi ve durum aktarımı (29)

Pencereli Forward+ (Vulkan) görüntü kontrolü. Ana menü, ayarlar, Kat 1 HUD, Kat 3 telsiz, Kat 5 ve final sinematiğinin ekran görüntülerini `<temp>/beta_protocol_render_smoke/v030_*.png` olarak yazar, FPS ölçer ve `GameManager.quit_game()` ile kapanır:

```bash
godot --path . --script res://tests/render_smoke.gd
```

Kat sahnelerini yeniden üretmek için:

```bash
python tools/build_levels.py       # Kat 1
python tools/build_full_levels.py  # Kat 2–5
```
