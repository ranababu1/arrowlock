# Current State

**Phase:** Release 1 (`docs/level-plan-100.md`). R1 to R4 done; both 100-level packs are final for release 1 and frozen; badges/stats screen, vibration and the Play Games leaderboard code are in. Next: the owner-only steps of the Android release candidate (R7, `docs/release.md`). **Last updated:** 2026-11-05.
**Branch/commit:** `main`, remote `origin` = https://github.com/ranababu1/arrowlock.git. Version name 0.3.0 (`project.godot`), build number 32 (version code, in the gitignored export preset). Build with `tools/build_android.sh --bump`.

## Feature status
| Area | Status |
|---|---|
| Godot project scaffold | Implemented; loads and starts headless |
| Rules engine, solvers, move limits | Implemented; tests pass. Undo takes back exactly one tap (wasted or not) and refunds it; empty-cell taps are free; a level is lost only at 0 moves (owner decision, even if already unwinnable) |
| Level select, game screen, win/game-over panels, hint/undo/extra moves | Implemented; verified on the emulator on 2026-11-01 (before today's changes) |
| Content | Easy and Difficult packs, 100 levels each, regenerated 2026-11-05 to get harder level by level (no breathers, no reused layouts) and **frozen** in `data/levels.lock.json`. Not reviewed by the owner (owner chose not to review now) |
| Level tooling | Generator with depth ranges per world, rising-depth floor and a switch to forbid reuse; validator; `tools/generate_levels.gd`, `tools/freeze_levels.gd` |
| Save v2 + rewards | Implemented and tested: stars, coins, world unlock, badges, v1 migration, vibration setting, leaderboard state. Older 0.1.0 saves load unchanged (defaults fill the new fields) |
| Score (leaderboard) | Implemented and tested: each clear scores 100 per star plus a speed bonus of up to 200 (half at par = 1.5 s per arrow, falling smoothly so ties are rare). Time counts from when the level opens, pauses while a panel is shown, and resets on Retry. Each level keeps its best score; the leaderboard posts the sum per mode (max 50,000). Shown on the win panel and the Profile screen. Speed pays no coins. Older saves get 100 per star until a level is replayed. Not tuned with players |
| Economy | Retuned: clear 20 + 5 per star, world bonus 50; Undo 20, Hint 30, +3 moves 50. Tests check that a one-star player can still buy a Hint on every level. Not tested with players |
| Difficulty tiers | Easy (no clock) and Difficult (10 s per tap, 2x coins). Chosen in Settings; switching is instant and keeps progress (each mode its own levels; coins and badges shared). Owner rule 2026-11-08, replacing the earlier wipe-on-switch |
| Profile screen (was Trophies) | Implemented and tested with a fake plugin (owner request 2026-11-08). Opened from the person button on the menu. Profile card: signed in to Play Games → gamer name and profile picture from Play Games (read-only; changed in the Play Games app); otherwise a local nickname (max 16 chars) and one of 8 built-in avatars, saved on the phone only, plus a sign-in button when Play Games is configured. Then stats for the current mode, the leaderboard card ("You appear as <name>") and all 7 badges. Not run on a device; the Play Games part needs the owner's Play Console setup |
| Vibration | Implemented: short buzz on a blocked tap, win and loss; Settings toggle. Needs the Vibrate permission in the export preset. Not felt on a device yet |
| Online leaderboard (Play Games) | Code implemented and tested with a fake plugin: optional sign-in, two boards (score per mode: each level's best clear, 100 per star plus a speed bonus, summed), scores sent only from the saved state and retried after failures. Plugin `addons/GodotPlayGameServices` v3.4.0 (MIT) added. **Not working yet**: needs the owner's Play Console setup, leaderboard ids in `data/play_games.json`, the Game ID and a Gradle build (see `docs/release.md`). Never run on a device |
| Ads (AdMob interstitial) | Implemented and tested with a fake plugin (owner request 2026-11-08): an interstitial when the player leaves the win/game-over panel (Next, Retry, Replay, Menu) on level 11+ in either tier, at most once per 60 s; "+3 moves" never shows one. Consent form (UMP) first, then SDK init and preload. Plugin `addons/AdmobPlugin` v7.0 (MIT). Signed APK b33 builds and carries the AdMob app id. **Real AdMob ids set 2026-11-08** (app `~9418380851`, interstitial `/1268428091`); APK b34 carries the real app id. Never run on a device |
| Audio | Implemented; not yet listened to by the owner (deferred by the owner; nothing waits on it) |
| Settings | Difficulty, music, effects, tutorial tips, vibration, two volume sliders |
| Tutorial | Levels 1 to 3; still matches the new level 1 (tests check it); not user-tested |
| Safe-area insets | Implemented; not tested on a cutout device |
| Board size | Tests check that the biggest board of each pack keeps cells of at least 40 px at the 540x960 base layout |
| Android export (M0) | Debug APK ran on the emulator (2026-11-01). Release candidate not built yet. Physical device not tested (deferred by the owner) |

## Architecture
- `scripts/core/` — pure logic: `board_state.gd`, `move_validator.gd`, `puzzle_solver.gd`, `game_controller.gd`, `economy.gd`, `progress.gd`, `difficulty.gd`, `tutorial.gd`, `board_canon.gd`, `level_metrics.gd`, `level_generator.gd`, `level_validator.gd`, `level_fingerprint.gd`, `leaderboard_sync.gd`.
- `scripts/services/` — `puzzle_repository.gd`, `save_service.gd`, `audio_manager.gd`, `haptics.gd`, `play_games.gd` (talks to the plugin's Android singleton; a no-op elsewhere), `ads.gd` (consent, preload and showing of interstitials through the AdmobPlugin's Admob node; a no-op elsewhere). `scripts/core/ad_policy.gd` decides which game ends earn an ad. `data/ads.json` holds the ad settings; `addons/AdmobPlugin/android_export.cfg` holds the manifest app id.
- `scripts/ui/` — `main.gd` (router), `level_select.gd`, `settings_screen.gd`, `profile_screen.gd`, `avatar_view.gd`, `game_screen.gd`, `board_view.gd` and the design-system widgets.
- `data/packs/`, `data/packs_hard/` (levels), `data/levels.lock.json` (frozen fingerprints), `data/play_games.json` (leaderboard ids, empty for now), `data/levels.json` (4 levels, tests only).
- `addons/GodotPlayGameServices/` — third-party plugin, enabled in `project.godot`. Its autoload is not used by this game's code.
- `tools/` — `generate_levels.gd`, `freeze_levels.gd`, `world_specs.json`, `world_specs_hard.json`, `make_audio.py`. `tests/run_tests.gd` — test runner.
- Docs: `plan.md` (baseline), `level-plan-100.md` (release 1 + owner decisions in §11), `release.md` (release steps and Play checklist), `instructions.md`, `changelog.md`.

## Toolchain
Godot 4.7.2 stable. `config/features` says 4.3; the project runs on 4.7.2.

## Build/test status
Verified 2026-11-05 in a Linux container with the official Godot 4.7.2 build:
- `godot --headless --path . -s tests/run_tests.gd` → **544 passed, 0 failed (2026-11-08, Windows, Godot 4.7.2)**.
- `tools/build_android.sh --bump` → signed `arrowlock-0.3.0-b33-arm64-v8a.apk`, 90.8 MB (was 80.6 MB; the ads SDK adds about 10 MB). Its manifest has the AdMob app id (Google's sample) and the AD_ID permissions (2026-11-08, Windows). Not installed on a device.
- `godot --headless --path . -s tools/generate_levels.gd` (and `-- --hard`) → 100 levels each, 0 variants, 0 failures.
- `godot --headless --path . --quit-after 120` → starts with no script errors.
- Not done here: Android export, emulator or device runs (no Android SDK in that container). The plugin's editor code was not run there either.

## Known issues / risks
- The Play Games plugin v3.4.0 is documented for Godot 4.5; it has not been built with 4.7.2 yet. The first Gradle export may need a plugin update.
- No player has played the new packs; the difficulty is measured by the generator (arrows, chain depth, spare moves), not by people.
- Difficult boards go up to 9x12; cells are about 50 px at the 540x960 base layout, which is small on narrow phones.
- Economy numbers are untested with players.
- A level is lost only at 0 moves even if already unwinnable (by design).
- Emulator `adb` is flaky; `DirAccess.rename_absolute` overwrite on Windows and save atomicity are unverified.
- Levels are frozen: changing a released level breaks the tests on purpose. Add new levels only after level 100.

## Next steps
0. Owner: publish the GDPR message in AdMob (Privacy & messaging) and register your phones as AdMob test devices; install b34 and check that an ad appears after a game on level 11 (new units can take an hour to serve).
1. Owner: Play Console app, Play Games project, two leaderboards, OAuth client; put the leaderboard ids in `data/play_games.json` (`docs/release.md` §1).
2. Owner: export preset with Gradle build, Vibrate permission, Game ID and signing; export the release candidate (`docs/release.md` §2–3).
3. Owner: device checks and the upgrade test on a physical phone, then the internal test track (`docs/release.md` §4–5).
4. Owner, later: listen to the audio, try the tutorial, play the packs and report anything too hard or too easy.
5. Play listing, privacy policy and Data safety (`docs/release.md` §6) before any wider release.

## Decisions needing owner approval
- None open. All decisions of 2026-11-05 are recorded in `docs/level-plan-100.md` §11. A production release still needs explicit approval (`instructions.md` §7).
