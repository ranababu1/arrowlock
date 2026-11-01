# Changelog

Reverse chronological. See `instructions.md` §8 for entry requirements.

## 2026-11-01 — Package ID is now dev.imrn.arrowlock

- Owner decision: all apps use the domain imrn.dev, so Arrowlock's Android package ID is `dev.imrn.arrowlock` (was the placeholder `com.ranababu.arrowlock`).
- Changed `package/unique_name` in the local, gitignored `export_presets.cfg`. Rebuilt the debug APK, uninstalled the old package from the Pixel_10a emulator and installed the new one: `adb shell pm list packages` shows `package:dev.imrn.arrowlock`; the app launches to the level select with a fresh save (0/300 stars, 100 coins). Old emulator save data was not migrated.
- Because `export_presets.cfg` is not committed, the ID is recorded here and in `currentstate.md`; the preset must be recreated with it on a new machine.

## 2026-11-01 — Audio, settings and visual redesign

Pushed in small steps (10 commits, `8941d5c` to `467cd94`).

### Audio
- `tools/make_audio.py` synthesises everything from scratch (numpy/scipy, ffmpeg for Ogg): 10 sound effects (`tap_clear`, `tap_blocked`, `hint`, `coin`, `star1-3`, `win`, `lose`, `click`) and a 49 s calm A-minor ambient loop (`assets/audio/`). Original audio, so no third-party licence. Deterministic; rerun to regenerate.
- `AudioManager`: Music and SFX buses, a pool of effect players, looping music, mute per bus, pauses music when the app loses focus. A click sound plays on every button. Win plays a fanfare, then one rising ding per star, then a coin ding if coins were paid.
- Settings screen (gear on the level select): Music and Sound effects toggles, saved immediately (`music_enabled`, `sound_enabled` in the save). About text with version and credits.

### Visual redesign
- Poppins font (SIL OFL, licence in `assets/fonts/`), a palette, a theme with glass, primary and icon button variations, cards, and text styles.
- Vector icons drawn in code (no icon files), animated backdrop (gradient, glow textures, faint drifting arrows on menus only), toggle switch, icon button, progress pill.
- Level select: logo, star and coin chips, Continue button (opens at the first uncleared level), a card per world with its own accent colour, name, progress and tiles (cleared / current with pulse / open / locked with a lock icon).
- Game screen: back button, level and world caption, coin chip, big moves counter with a bar that turns gold then red, board inside a card, helper buttons with icon and coin price, win and game-over panels with animated star pop-in, confetti, and fades between screens.
- Arrows: one flat rounded silhouette per arrow, coloured by direction (cyan up, mint right, coral down, lavender left), with a soft shadow; sparks when an arrow leaves; shake plus red when blocked; gold outline for hints.

### Verification
- `godot_console --headless --path . -s tests/run_tests.gd`: 266 passed, 0 failed. New tests cover the audio manager (buses, mute, unknown sound), sounds fired by game events, settings toggles and saving, design components, level-select states, and the arrow outline.
- Audio files checked objectively (not by ear): no clipping, no start/end clicks, music loop seam jump 0.0076, the "clear" effect spectrum softened after the first check showed it was hissy.
- Emulator: level select, settings (toggle off saved `"music_enabled": false`), game screen on a 3x3 and an 8x9 board, win panel with stars and confetti, menu opening at the right level. Android reports active audio players for the app.
- **Not verified:** how the audio sounds (no listening possible here), confetti and the star pop-in animation as motion (screenshots only), the blocked shake, haptics (not implemented), behaviour on a phone with a notch.
- adb on the emulator is unreliable; one run used a stale app process and showed the wrong Continue level, which a clean rerun disproved.

## 2026-11-01 — R4: interface (level select, game screen, panels, helpers)

### Added
- `LevelSelect`: all 10 worlds with per-level stars (drawn shapes, `StarRow`), locked worlds greyed with the unlock rule, total stars and coins, opens scrolled to the player's current level. Buttons swallow touches, so drag-to-scroll is handled explicitly and a drag's closing tap is ignored.
- `GameScreen`: Menu button, coins, moves left and arrows left, board, Undo / Hint / Restart with prices, win panel (stars, moves and wasted taps, coins earned, world bonus, new badges, Next / Replay / Menu) and game-over panel (Retry, +3 moves for 50 coins once per attempt, Menu). A full-screen dimmer blocks board taps behind a panel.
- `BoardView`: hint highlight (green plus a pulsing outline, so not colour-only) and a shake on blocked arrows in addition to the red flash.
- `main.gd` is now a router: loads `data/packs/` (the draft 100 levels), applies safe-area margins, and maps Android back to "menu from a level, quit from the menu". `AppTheme` gives buttons and panels visible edges. `icon.svg` set as the project icon (the export no longer warns about a missing icon).
- `data/levels.json` (the original 4 levels) is no longer loaded by the game; it is still used by tests.

### Verification
- `godot_console --headless --path . -s tests/run_tests.gd`: 205 passed, 0 failed. New UI smoke tests build the real screens headless: level select counts and locking, drag scrolling and tap suppression, focus scrolling; game screen win, game over, extra moves once, hint and undo coin rules, Next at a locked world and at the end of the pack, blocked-tap flash state.
- Emulator (Pixel_10a, 1080x2424), debug APK:
  - Level select renders all 10 worlds, locked worlds greyed; a save injected with levels 1-90 cleared showed 270/300 stars, 500 coins, worlds unlocked, and the menu opened at World 10.
  - Level 1: Hint spent 30 coins and highlighted the clear arrow; 1 wasted tap then a clean finish gave 2 stars, +20 coins, "First clear" badge, 90 coins total.
  - Six blocked taps gave the game-over panel ("3 arrows left, 6 wasted taps") with all three buttons readable.
  - Level 100 (8x10, 34 arrows, 40 moves) renders with about 126 px cells.
  - Swipes did not scroll the list before the drag fix and do after it.
- Not verified on device: the red flash and shake on a blocked tap (the screenshot after `adb input tap` arrives after the 0.35 s effect ends; the earlier R1 build did capture the red flash; the state is covered by a test), safe-area margins on a device with a cutout (the emulator has none), Android back button, Hint/Undo rejection messages, extra-moves flow on device, startup time (about 10 s on this emulator; not profiled).
- adb on the emulator went offline repeatedly; several runs were discarded. One screenshot came from an unrelated old file on the emulator and was not used.

### Known gaps
- No tutorial or first-run explanation yet; level 1 teaches nothing about blocked taps. No sound or haptics. Settings screen does not exist (`sound_enabled` is saved but unused). No badge screen (badges appear only on the win panel).
- The pack is a draft: no owner review. Level 100 looks easy for a final level (17 of 34 arrows are free at the start).

## 2026-11-01 — R3: level generator, validator, reuse tooling, draft 100-level pack

### Added
- `LevelGenerator` (seeded, offline): builds boards backwards from a removal order; each new arrow's ray must be clear of arrows already placed, so boards are solvable by construction and removing arrow IDs in ascending order is a valid solution. Candidates are scored on dependency depth versus a per-world target; layouts already used are skipped. `make_variant` makes a rotated or mirrored copy under a new name (`variant_of`).
- `BoardCanon` (8 rotations/mirrors, canonical layout key for reuse detection), `LevelMetrics` (arrows, free/blocked at start, dependency depth, bait count).
- `LevelValidator`: per-level (limit >= arrows, greedy + topological + exhaustive solvers) and per-pack (unique ids and names, undeclared duplicate layouts, variant policy: max 15, none in the first 10 levels, at least 10 levels from the source, must truly be a rotation or mirror).
- `PuzzleSolver.topo_solvable` (Kahn's algorithm over the full dependency graph), `MoveValidator.ray_arrows`, `PuzzleRepository.load_dir` and `variant_of` parsing.
- `tools/world_specs.json` (10-world curve from `level-plan-100.md`, master seed 20261101) and `tools/generate_levels.gd` (writes `data/packs/world_01..10.json`, then validates).
- **Draft** pack: 100 levels in `data/packs/`, 100 unique layouts, 0 variants needed. Not owner-reviewed and not yet used by the game; the game still loads `data/levels.json` (4 levels).

### Verification
- `godot_console --headless --path . -s tools/generate_levels.gd`: "Generated 100 levels (0 variants), failures: 0", validator clean (about 16 s).
- `godot_console --headless --path . -s tests/run_tests.gd`: 176 passed, 0 failed (about 5 s). Covers: 1000 generated boards all solvable and solved by ascending IDs; greedy, topological and exhaustive solvers agree on 300 random boards (including unsolvable ones); canonical form stable under all 8 transforms; metrics on known boards; each validator rule; generation determinism; the draft pack files.
- Curve check (printed from the generated metrics): level 1 is 3x3 with 3 arrows and limit 6; level 100 is 8x10 with 34 arrows, depth 9, 17 free at start, limit 40. Arrow count, depth and bait rise by world; the 5th level of each world is a breather.

### Notes and limits
- The chain-depth target (`0.3 x arrows + 0.5 x world`) and bias values are guesses; whether levels feel good is unknown until played. World 1 levels are very small (level 1 has one blocked arrow); the plan's "blocked tap taught on level 3" is not guaranteed by generation and needs a look in review.
- Only the dependency chain is optimised; "visual difficulty" (bait, near-misses) is measured but not targeted.
- No code path uses `data/packs/` yet (R4/R5).

## 2026-11-01 — R2: save v2, stars, coins, helpers (logic)

### Added
- `Economy` (tuning constants: start coins 100, clear 10 + 5/star, world bonus 25, prices Undo 20 / Hint 30 / Extra moves 50 for +3 moves, 8-of-10 world unlock) and `stars_for`.
- `Progress` (pure rules, no IO): per-level stars / best moves / best wasted taps, coins with `spend` (cannot overspend), world unlock, first-clear and improvement payouts, world-complete bonus (paid once), badges (first_clear, clears_10/50/100, perfect_clear, world_perfect), sanitising `from_dict` (clamps negatives, drops invalid levels and unknown badges), `from_v1` migration.
- `GameController.hint()` (a clear arrow, no move cost) and `grant_extra_moves()` (only after a loss, once per attempt; restart resets).
- `SaveService` now persists `Progress` as save schema v2; v1 saves migrate (completed levels become 1 star, unknown wasted taps); corrupt or unknown-version saves fall back to defaults.
- `main.gd`: shows coins; a win records stars and coins; Undo now costs 20 coins and saves immediately.

### Not done yet (R4 UI)
- No Hint or Extra-moves buttons, level select, badge screen or star display; the logic and tests exist, the buttons do not.

### Verification
- `godot_console --headless --path . -s tests/run_tests.gd`: 108 passed, 0 failed.
- Emulator (Pixel_10a): cleared level 1 with no wasted taps -> "3 star(s), +25 coins"; force-stop and relaunch -> opens level 2 with Coins: 125 (save persisted). Undo coin spend and game-over flow with coins not re-checked on device.
- adb on the emulator went offline several times; two runs were discarded as invalid and repeated.

## 2026-11-01 — R1: move limits and game over

### Changed
- `GameController`: every tap on an arrow costs a move (blocked or clear); taps on empty cells are free. New `State` (PLAYING/WON/LOST), `moves_limit`, `moves_used`, `wasted_taps`, `moves_left()`, `lost` signal. A win on the last allowed move is a win. Undo refunds the removed arrow's move only and is disabled after win/loss. `start()` rejects a limit below the arrow count.
- Level schema bumped to version 2: `moves_limit` is required and validated against the arrow count. The 4 levels now use 100% slack (6, 10, 12, 16 moves). Version 1 files are rejected, not migrated (no v1 content exists besides this repo's own file).
- UI shows "Moves left / Arrows" and "Out of moves! Tap Restart."

### Fixed
- Each touch counted as two taps because `BoardView` handled both the touch and its emulated mouse click. Harmless before taps cost moves; now only the mouse event is handled. Found on the emulator (one tap showed 6 -> 4 moves left).

### Decisions applied (owner has not yet answered the open questions in `level-plan-100.md`; recommended defaults used)
- Empty-cell taps are free. Undo refunds one move and is free for now (coin cost arrives with the reward system, R2).

### Verification
- `godot_console --headless --path . -s tests/run_tests.gd`: 65 passed, 0 failed.
- Emulator (Pixel_10a), debug APK rebuilt: one blocked tap -> "Moves left: 5" of 6; 5 blocked taps -> "Moves left: 1"; 6th -> "Out of moves! Tap Restart."; Restart then the 3 clear taps -> "Cleared in 3 moves!".
- Note: Godot export prints "No project icon specified" as an error but still produces a signed APK; an icon is still to do before release.

### Known gap
- The game is declared lost only when moves hit 0, even if fewer moves remain than arrows (an already-unwinnable state). Left as the literal rule; an earlier "cannot win" check is an option.

## 2026-11-01 — Release 1 scope: 100 levels, move limits, rewards (docs only)

- Owner decisions (from chat): first release is 100 levels; layouts may be reused under a new name; every tap on an arrow is a move; a blocked tap wastes a move; limited moves cause game over; plan rewards and a leaderboard.
- Added `docs/level-plan-100.md` (rules, 10-world curve, reuse policy, rewards, save v2, leaderboard, milestones R1 to R8). It supersedes the scope of `level-plan-500.md`, which is now deferred.
- Departs from `plan.md` (no punishment for blocked taps in the MVP; no online leaderboard). `plan.md` unchanged. No code changes; the current build still has unlimited moves.

## 2026-11-01 — 500-level proposal (docs only)

- Added `docs/level-plan-500.md`: proposal for 500 levels in 10 worlds, seeded offline generator with solver validation, and a two-track structure. Key finding: under the MVP rules every solvable board takes exactly N moves for N arrows, so efficiency medals and "suboptimal move" difficulty from `plan.md` do not apply to the core rule.
- This departs from `plan.md` (about 40 levels; no procedural levels until generator validation) and is **not approved**. `plan.md` unchanged. No code changes.

## 2026-11-01 — Android emulator run

- Enabled ETC2/ASTC import in `project.godot` (required for Android export).
- Installed Godot 4.7.2 export templates locally; created a local `export_presets.cfg` (gitignored) for package `com.ranababu.arrowlock`, arm64-v8a + x86_64, no permissions.
- `godot_console --headless --path . --export-debug "Android Debug" build/arrowlock-debug.apk`: succeeded, signed with the Godot debug keystore (56 MB).
- Installed with `adb install -r` on the `Pixel_10a` emulator (x86_64, 1080x2424) and launched: Vulkan Mobile renderer, no errors in logcat.
- Manual check via `adb input tap`: level 1 renders correctly in portrait; tapping a blocked arrow flashes it red without changing state; tapping clear arrows removed all three and showed "Cleared in 3 moves!" with Next enabled and Undo disabled.
- Not tested: physical device, pause/resume, save persistence across restart, other levels, safe-area insets (board is not vertically centred between the title and buttons on this tall screen).

## 2026-11-01 — Initial implementation

### Added
- Godot 4 project scaffold (`project.godot`, portrait 540x960, mobile renderer, `.gitignore`).
- Rules engine (`scripts/core/`): `BoardState`, `MoveValidator` (ray-cast blocking), `PuzzleSolver` (greedy solver plus independent exhaustive DFS cross-check), `GameController` (tap, undo, restart, single-fire completion).
- Services (`scripts/services/`): `PuzzleRepository` (versioned JSON level loading with schema validation), `SaveService` (versioned local save, atomic write, safe fallback on corrupt data).
- Playable screen (`scenes/main.tscn`, `scripts/ui/`): code-drawn board, exit animation, blocked flash, Undo/Restart/Next, progress saved on completion.
- 4 hand-authored levels in `data/levels.json` (plan targets ~40).
- Test runner `tests/run_tests.gd`.

### Verification
- Installed Godot 4.7.2 via `winget install GodotEngine.GodotEngine`.
- `godot_console --headless --path . -s tests/run_tests.gd`: **55 passed, 0 failed**, exit 0. (The "Parse JSON failed" log lines are expected output from the negative tests.)
- `godot_console --headless --path . --quit-after 120`: main scene started with no errors or warnings. The UI was not looked at on screen; touch, layout and Android export are untested.
- Fix found by the solver: level 4 originally had two arrows facing each other and was unsolvable; arrow moved from (4,2) to (4,1). Also fixed a typed-array comparison in the test file.

### Notes
- No new dependencies. No deviations from `plan.md`.
