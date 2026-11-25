# BETA PROTOCOL — PROGRESS

## Durum
- [x] Wave 1: asset, ses, FPS çekirdek, BETA cihazı, cutscene, puzzle, UI (commit cfa3868)
- [x] Wave 2A-1: entegrasyon cilası (AudioManager alias, UI CanvasLayer, ESC/pause, headless mouse guard)
- [x] Wave 2A-2: Kat 1 lobi sahnesi + controller
- [x] Wave 2A-3: Kat 2 ofis sahnesi + controller + dikey kesit konsolu
- [x] Wave 2A-4: tests/run_tests.gd 16/16 (exit 0, uyarısız)
- [x] Wave 2A-5: render kontrolü (Forward+ Vulkan, menü/Kat1/Kat2 ekran görüntüsü + CRT; graceful quit temiz. Not: `--quit-after` zorla çıkışta müzik playback'i için engine seviyesinde leak uyarısı kalıyor)
- [x] Wave 2A-6: README.md (Türkçe)

## Ajan defteri
- Delegate 2A (entegrasyon, Kat 1-2, testler, README) · claudeAgent/claude-opus-5-5 · audio_manager.gd, player_controller.gd, pause_menu.gd, death_screen.gd, locked_door.gd, lore_terminal.gd, cutscene_player.gd, main_menu.gd, scenes/levels/*, floor_0x_controller.gd, vertical_slice_console.gd, tests/run_tests.gd, README.md, game_manager.gd · durum: bitti · Kat 1-2, konsol, 16/16 test, GameManager.quit_game + WM close, F6 kat başlığı senkronu, README · kalan: orkestratör incelemesi/commit
