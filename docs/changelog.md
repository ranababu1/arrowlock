# Changelog

Reverse chronological. See `instructions.md` §8 for entry requirements.

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
