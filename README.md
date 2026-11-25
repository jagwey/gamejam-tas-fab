# BETA PROTOCOL

Tasarım Fabrikası Game Jam için Godot 4.7 ile yapılmış, retro-pixel dokulu bir birinci şahıs nişancı. Bu repo oyunun **tam sürümünü (v0.2.0)** içeriyor: 5 kat, 4 bulmaca, 3 aşamalı Viktor Volkov boss savaşı ve final sinematiği.

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

## Oyun kapsamı (v0.2.0)

| Bölüm | İçerik |
|---|---|
| Ana menü | Yeni Oyun, Devam Et (kayıt varsa), Ayarlar, Geliştirici Ekibi, Çıkış |
| Açılış sahnesi | Köy evi, Aydın ve General diyaloğu. Basılı tutarak atlanabilir (5 sn). |
| Sistemler | Tabanca, pompalı tüfek, bıçak; düşman yapay zekâsı (IDLE → PATROL → ALERT → CHASE → ATTACK); BETA ile can toplama; ölüm ekranı; duraklatma menüsü; kat başına kayıt ve can/silah aktarımı; boss can barı; CRT/VHS ekran filtresi |

### 5 kat ve 4 bulmaca

| Kat | Mekân | Düşmanlar | Kilit / Hedef | Çıkış |
|---|---|---|---|---|
| **1 — Lobi ve Güvenlik** | Lobi, güvenlik hattı, lore terminalleri, BETA öğretici ipucu | Lv1 Muhafız, Lv2 Paralı Asker | **Hareketli Kilit**: 3 aşamalı hareketli çubuk hizalama (`moving_lock_puzzle`) | Asansör → Kat 2 |
| **2 — Ofis ve Arşiv** | Ofis koridorları, arşiv sunucuları, yönetici odası | Lv1 Teknisyen, Lv2 Paralı Asker | **Devre Bağlantısı**: 3×3 kablo karolarını çevirip devreyi tamamla (`circuit_puzzle`) | Asansör → Kat 3 |
| **3 — Biyoteknoloji Laboratuvarı** | Biyo-tüpler, exo-zırh test odası, titreyen acil ışıklar | Lv3 Ağır Paralı Asker, Lv1 Teknisyen | **Biyolojik Renk/Sembol Eşleştirme**: 4 numuneyi doğru hazneyle eşleştir (`bio_match_puzzle`) | Asansör → Kat 4 |
| **4 — VIP ve Kumarhane** | Kumarhane salonu, VIP lounge, güvenlik odası, kasa | Lv4 Elit Komando, Lv2 Paralı Asker, Lv1 Muhafız | **Sembol Sıralaması**: 4 adımlı sembol kodunu doğru sırayla gir (`sequence_puzzle`) | Asansör → Çatı |
| **5 — Çatı ve Reaktör** | Yağmurlu çatı, Beta Reaktörü çekirdeği, işaret ışıkları | **Viktor Volkov** (boss) + aşama takviyeleri (Lv1 Muhafız/Teknisyen) | 3 aşamalı boss savaşı → **Reaktör Konsolu** (Volkov ölünce açılır) | Final sinematiği |

### Düşman seviyeleri

| Seviye | Düşman | Can | Hasar | Saldırı aralığı | BETA iyileşmesi |
|---|---|---|---|---|---|
| 1 | Güvenlik Görevlisi / Silahlı Teknisyen | 40 | 5 | 0.9 sn | +5 |
| 2 | Paralı Asker | 65 | 8 | 1.2 sn | +10 |
| 3 | Ağır Paralı Asker | 100 | 12 | 1.5 sn | +15 |
| 4 | Elit Komando | 140 | 17 | 1.9 sn | +20 |
| 5 | Exo Asker (`enemy_lv5_exo`, yedek boss verisi) | 200 | 23 | 2.3 sn | +25 |
| Boss | **Viktor Volkov** (exo-zırh, Lv5) | 450 | 7 / mermi (seri atış), 18–24 şok dalgası | 2.1 → 1.35 → 1.0 sn | +25 |

**Volkov'un 3 aşaması:**
- **Aşama 1 (%100–66):** 3 mermilik seri atış. Yakına gelince yere vurup şok dalgası yayar (4.5 m).
- **Aşama 2 (≤ %65):** hızlanır, yana atılarak kaçar, 4 mermilik yelpaze atış yapar. 2 takviye düşman gelir.
- **Aşama 3 (≤ %30):** mavi plazma moduna geçer, 6 mermilik hızlı seri atış yapar, şok dalgası 24 hasar verir. 2 takviye daha gelir.
- Ölünce cesedi BETA ile **+25 HP** verir ve reaktör konsolu açılır.

### BETA Cihazı kuralları
- Taze bir cesedin yanında **F** tuşunu **1 saniye** basılı tutarak kanal açılır.
- Düşman seviyesi başına maksimum canın **%5'i** kadar iyileştirir (en fazla 5 seviye, yani %25).
- Her ceset **bir kez** kullanılabilir.
- Can 100'ü geçmez. Can doluyken cihaz çalışmaz ve ceset harcanmaz.

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

22 kabul testi gerçek sahneleri ve fizik adımlarını kullanır. Komut satırından:

```bash
godot --headless --audio-driver Dummy --path . --script res://tests/run_tests.gd
```

Windows'ta `godot` yerine kurulu Godot konsol exe'sinin yolunu yazın (`Godot_v4.7.2-stable_win64_console.exe`).

Beklenen çıktı ve çıkış kodu:

```
==== BETA PROTOCOL ACCEPTANCE: 22/22 PASSED ====
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
- Kat 5: Volkov'un 3 aşaması, takviye dalgaları, +25 BETA, reaktör konsolu (20)
- final sinematiği: epilog, atlama, özet kartı (21)
- tam proje bütünlüğü: her `.tscn/.tres/.gdshader/.png/.wav/.gd` yüklenir, her sahne örneklenir (22)

Pencereli Forward+ görüntü kontrolü. Ekran görüntülerini işletim sisteminin temp klasörüne yazar ve `GameManager.quit_game()` ile kapanır:

```bash
godot --path . --script res://tests/render_smoke.gd
```

Kat sahnelerini yeniden üretmek için:

```bash
python tools/build_levels.py       # Kat 1
python tools/build_full_levels.py  # Kat 2–5
```
