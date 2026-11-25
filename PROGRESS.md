# BETA PROTOCOL — PROGRESS

## Durum
- [x] Wave 1: asset, ses, FPS çekirdek, BETA cihazı, cutscene, puzzle, UI (commit cfa3868)
- [x] Wave 2A-1: entegrasyon cilası (AudioManager alias, UI CanvasLayer, ESC/pause, headless mouse guard)
- [x] Wave 2A-2: Kat 1 lobi sahnesi + controller
- [x] Wave 2A-3: Kat 2 ofis sahnesi + controller + dikey kesit konsolu
- [x] Wave 2A-4: tests/run_tests.gd 16/16 (exit 0, uyarısız)
- [x] Wave 2A-5: render kontrolü (Forward+ Vulkan, menü/Kat1/Kat2 ekran görüntüsü + CRT; graceful quit temiz. Not: `--quit-after` zorla çıkışta müzik playback'i için engine seviyesinde leak uyarısı kalıyor)
- [x] Wave 2A-6: README.md (Türkçe)
- [x] Wave 3: Kat 2-5 seviyeleri, Lv3/Lv4/Lv5 düşmanlar, 4 bulmaca (hareketli kilit, devre, biyo eşleştirme, sembol sıralama), Volkov 3 aşamalı boss + reaktör konsolu, final sinematiği, Kat 3-5 müzik/SFX
- [x] Wave 4: PCK düzeltmeleri (enemy_base sprite fallback, volkov stats.duplicate, build_levels.py yalnız Kat 1), tests/run_tests.gd 22/22 (exit 0, uyarısız), Forward+ render smoke Kat 3-5 + final (tests/render_smoke.gd), README v0.2.0

## Ajan defteri
- Delegate 2A (entegrasyon, Kat 1-2, testler, README) · claudeAgent/claude-opus-5-5 · audio_manager.gd, player_controller.gd, pause_menu.gd, death_screen.gd, locked_door.gd, lore_terminal.gd, cutscene_player.gd, main_menu.gd, scenes/levels/*, floor_0x_controller.gd, vertical_slice_console.gd, tests/run_tests.gd, README.md, game_manager.gd · durum: bitti · Kat 1-2, konsol, 16/16 test, GameManager.quit_game + WM close, F6 kat başlığı senkronu, README · kalan: orkestratör incelemesi/commit
- Delegate 3C (Kat 2-5 seviyeleri, düşman varyantları, GameManager kaydı) · claudeAgent/claude-opus-5-5 · game_manager.gd, enemy_lv3/4/5 .tres, enemy_heavy_lv3/commando_lv4 .tscn, tools/build_full_levels.py, floor_02..05 .tscn + controller · durum: bitti · GameManager kat 3-5 kaydı + başlıklar; heavy/commando/volkov sprite_prefix; `python tools/build_full_levels.py` Kat 2-5'i üretiyor (kat 3-5 dokuları ve bulmaca/boss/konsol sahneleri controller'da ResourceLoader.exists ile bağlanıyor); headless: 5 kat yükleniyor+instantiate 0 hata, testler 16/16 · kalan: oyun içi elle oynanış/denge kontrolü. Not (4A'da çözüldü): `tools/build_levels.py` artık yalnız Kat 1 üretir
- Delegate 4A (Wave 4 entegrasyon, PCK fix, 22/22 test, dokümantasyon) · claudeAgent/claude-opus-5-5 · enemy_base.gd, volkov_boss.gd, tools/build_levels.py, tests/run_tests.gd, tests/render_smoke.gd, README.md, PROGRESS.md · durum: bitti · 22/22 PASSED exit 0 uyarısız; render smoke Vulkan Forward+ 4 sahne 0 hata · kalan: orkestratör v0.2.0 export + GitHub Release (commit yok)
