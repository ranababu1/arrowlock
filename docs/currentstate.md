# Current State

**Phase:** Release 1 plan (`docs/level-plan-100.md`), milestones R1 (move limits) and R2 (save v2, stars, coins, helper logic) done; R3 (level generator) is next. **Last updated:** 2026-11-01.
**Branch/commit:** `main`, remote `origin` = https://github.com/ranababu1/arrowlock.git

## Feature status
| Area | Status |
|---|---|
| Godot project scaffold | Implemented; loads and starts headless |
| Rules engine (M1) | Implemented; automated tests pass |
| Solver + independent cross-check | Implemented; automated tests pass |
| Puzzle screen, undo/restart, move limit, game over (M2/R1) | Implemented; tests pass; verified on emulator; no sound/haptics, minimal game-over UI |
| Level loading + validation (M3) | Implemented; automated tests pass |
| Content | Partial: 4 of 100 levels (release 1 target); no tutorial text |
| Save v2 + rewards (R2) | Implemented and tested: stars, coins, world unlock, badges, v1 migration. UI only shows coins and a result line; no level select, no badge screen |
| Helpers | Undo costs coins (wired). Hint and Extra moves exist as logic only, no buttons |
| Settings/pause menu, audio, haptics | Planned (`sound_enabled` flag is saved but unused) |
| Safe-area insets | Planned (fixed 16px margins only) |
| Android export (M0) | Debug APK exports and runs on the emulator; physical device not tested |

## Architecture
- `scripts/core/` — pure logic, no Node dependencies: `board_state.gd`, `move_validator.gd`, `puzzle_solver.gd`, `game_controller.gd`, `economy.gd`, `progress.gd`.
- `scripts/services/` — `puzzle_repository.gd`, `save_service.gd`.
- `scripts/ui/` — `main.gd` (screen wiring), `board_view.gd` (drawing/input only).
- `data/levels.json` — versioned level data (schema version 2, `moves_limit` required). `tests/run_tests.gd` — test runner.

## Toolchain
Godot 4.7.2 stable (winget). `config/features` says 4.3; project runs on 4.7.2.

## Build/test status
Verified 2026-11-01: `godot_console --headless --path . -s tests/run_tests.gd` -> 108 passed, 0 failed. Headless startup of the main scene: no errors. Android debug export + install + launch, tap-through of level 1 incl. move limit and game over, verified on the Pixel_10a emulator (2026-11-01). Not verified: physical device, pause/resume, save persistence across restarts.

## Known issues / risks
- Project has no icon (export warns); needed before release.
- A level is lost only at 0 moves even if it is already unwinnable.
- Economy numbers are untested guesses; tune after playtesting.
- Coins can reach 0 and Undo then refuses, but a stuck player can always Restart.
- `DirAccess.rename_absolute` overwrite behaviour on Windows is unconfirmed; save atomicity is unverified.
- Board view has no minimum cell size check for large boards.

## Next steps
1. Owner: answer the open questions in `docs/level-plan-100.md` section 11.
2. R3: level generator + validation (and reuse tooling); then UI (R4: HUD, game over, hint/extra buttons, level select) and the 100 levels.
4. Android check on a physical device (M0); test pause/resume and save persistence.

## Decisions needing owner approval
- Release 1 scope is `docs/level-plan-100.md` (100 levels, move limits, rewards, leaderboard). Open questions are in its section 11; the online leaderboard needs explicit approval. `docs/level-plan-500.md` is deferred. Nothing from these plans is implemented; the running build has unlimited moves and 4 levels.
