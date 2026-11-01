# Changelog

Reverse chronological. See `instructions.md` §8 for entry requirements.

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
