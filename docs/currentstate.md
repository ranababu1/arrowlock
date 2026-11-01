# Current State

**Phase:** M1 and M3 core done and tested; M2 screen written but not visually checked. **Last updated:** 2026-11-01.
**Branch/commit:** `main`, remote `origin` = https://github.com/ranababu1/arrowlock.git

## Feature status
| Area | Status |
|---|---|
| Godot project scaffold | Implemented; loads and starts headless |
| Rules engine (M1) | Implemented; automated tests pass |
| Solver + independent cross-check | Implemented; automated tests pass |
| Puzzle screen, undo/restart (M2) | Implemented; automated tests pass; no blocked-move sound/haptics |
| Level loading + validation (M3) | Implemented; automated tests pass |
| Content | Partial: 4 of ~40 levels; no tutorial text |
| Save/progress (M3) | Implemented; automated tests pass; no level-select screen, resumes at first incomplete level |
| Settings/pause menu, audio, haptics | Planned (`sound_enabled` flag is saved but unused) |
| Safe-area insets | Planned (fixed 16px margins only) |
| Android export (M0) | Not started |

## Architecture
- `scripts/core/` — pure logic, no Node dependencies: `board_state.gd`, `move_validator.gd`, `puzzle_solver.gd`, `game_controller.gd`.
- `scripts/services/` — `puzzle_repository.gd`, `save_service.gd`.
- `scripts/ui/` — `main.gd` (screen wiring), `board_view.gd` (drawing/input only).
- `data/levels.json` — versioned level data (schema version 1). `tests/run_tests.gd` — test runner.

## Toolchain
Godot 4.7.2 stable (winget). `config/features` says 4.3; project runs on 4.7.2.

## Build/test status
Verified 2026-11-01: `godot_console --headless --path . -s tests/run_tests.gd` -> 55 passed, 0 failed. Headless startup of the main scene: no errors. Not verified: on-screen rendering, input, Android export.

## Known issues / risks
- `DirAccess.rename_absolute` overwrite behaviour on Windows is unconfirmed; save atomicity is unverified.
- Board view has no minimum cell size check for large boards.

## Next steps
1. Run the game in the editor; check touch/mouse input and layout at phone aspect ratios.
2. Add level select, tutorial prompts, settings/pause, and grow content to ~40 levels.
3. Android export spike on a physical device (M0).

## Decisions needing owner approval
None pending.
