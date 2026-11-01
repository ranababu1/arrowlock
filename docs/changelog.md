# Changelog

Reverse chronological. See `instructions.md` §8 for entry requirements.

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
