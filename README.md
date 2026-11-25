# BETA PROTOCOL

Tasarım Fabrikası Game Jam için Godot 4.7 ile yapılmış, retro-pixel dokulu bir birinci şahıs nişancı. Bu repo oyunun **dikey kesitini** içeriyor.

## Hikâye

Deneysel **Beta Reaktörü** çalındı. Reaktör artık **Viktor Volkov**'un elinde. Volkov'un paralı ekibi binayı ele geçirdi ve General'in BETA araştırmasını kendi ağına aktardı. **General**, ajan **Aydın**'ı göreve çağırır ve ona deneysel yenilenme cihazı olan **BETA Cihazı**'nı verir.

Hedef beş katlı bir holding binası. Çatıdaki deneysel savunma sistemi hava desteğini engellediği için Aydın binaya tek başına girer ve katları tek tek temizleyerek reaktörü en üst kattan geri almaya çalışır.

BETA Cihazı yaşam enerjisini **yeni düşmüş düşmanlardan** çeker. Kendiliğinden can dolumu yoktur. Hayatta kalmak için çatışmaya girmek gerekir.

## Dikey kesit kapsamı

| Bölüm | İçerik |
|---|---|
| Ana menü | Yeni Oyun, Devam Et (kayıt varsa), Ayarlar, Geliştirici Ekibi, Çıkış |
| Açılış sahnesi | Aydın ve General diyaloğu. Basılı tutarak atlanabilir (5 sn). |
| **Kat 1 — Lobi ve Güvenlik** | Güvenlik hattı, Lv1 muhafızlar ve Lv2 paralı askerler, lore terminalleri, BETA öğretici ipucu, hareketli kilit bulmacasıyla açılan güvenlik kapısı, 2. kata çıkan asansör |
| **Kat 2 — Ofis ve Arşiv** | Ofis koridorları, arşiv odası, Lv1 teknisyenler ve Lv2 paralı askerler, lore terminalleri, yönetici odasındaki dikey kesit konsolu (kesit sonu raporu) |
| Sistemler | Tabanca, pompalı tüfek, bıçak; düşman yapay zekâsı (IDLE → PATROL → ALERT → CHASE → ATTACK); BETA ile can toplama; ölüm ekranı; duraklatma menüsü; kayıt ve kat geçişi; CRT/VHS ekran filtresi |

3–5. katlar (Laboratuvar, Sunucu Çekirdeği, Yönetim Katı) tam oyuna kalıyor. Düşman verileri (`enemy_lv3_heavy`, `lv4_commando`, `lv5_exo`) şimdiden hazır.

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
- `EnemyBase` bir durum makinesidir ve verisini `EnemyStats` `.tres` kaynaklarından alır.

### Klasör yapısı

```
assets/
  audio/        müzik (bgm_*) ve efektler (sfx_*), WAV
  portraits/    diyalog portreleri
  shaders/      crt_vhs.gdshader
  sprites/      silah ve düşman sprite'ları
  textures/     kat dokuları (f1_*, f2_*)
scenes/
  cutscenes/    opening_cutscene.tscn
  enemies/      enemy_base, guard_lv1, tech_lv1, merc_lv2
  levels/       floor_01_lobby.tscn, floor_02_office.tscn
  player/       player.tscn
  puzzles/      locked_door, lore_terminal, moving_lock_puzzle, level_exit, vertical_slice_console
  ui/           main_menu, hud, pause_menu, death_screen, settings_panel, credits_panel, crt_overlay
  weapons/      bullet_impact, pickup_item
scripts/
  components/   health_component, fps_camera, beta_device_controller
  managers/     settings, audio, save, game (autoload)
  resources/    enemy_stats, weapon_stats + enemies/*.tres, weapons/*.tres
  systems/      oyuncu, düşman, silah, UI, kat controller'ları, bulmaca ve terminal scriptleri
tests/
  run_tests.gd  16 kabul testi (headless)
tools/
  build_levels.py  kat sahnelerini (.tscn) üreten Python aracı
```

## Projeyi açma

1. **Godot 4.7** (standart sürüm, .NET gerekmez) indirin.
2. Godot Proje Yöneticisi'nde **İçe Aktar** deyip bu klasördeki `project.godot` dosyasını seçin.
3. İlk açılışta Godot asset'leri içe aktarır. Bu birkaç saniye sürebilir.
4. **F5** ile çalıştırın. Ana sahne `scenes/ui/main_menu.tscn`.

Proje **Forward+** renderer kullanıyor (Vulkan destekli GPU gerekir). Tek bir katı doğrudan denemek için `scenes/levels/floor_01_lobby.tscn` sahnesini açıp **F6** ile çalıştırabilirsiniz.

## Testler

16 kabul testi gerçek sahneleri ve fizik adımlarını kullanır. Komut satırından:

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

Windows'ta `godot` yerine kurulu Godot konsol exe'sinin yolunu yazın (`Godot_v4.7.2-stable_win64_console.exe`).

Beklenen çıktı ve çıkış kodu:

```
==== BETA PROTOCOL ACCEPTANCE: 16/16 PASSED ====
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

Kat sahnelerini yeniden üretmek için:

```bash
python tools/build_levels.py
```
