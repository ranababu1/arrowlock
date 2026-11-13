# Current State

**Phase:** Release 1 (`docs/level-plan-100.md`). R1 to R4 done; both 100-level packs are final for release 1 and frozen; badges/stats screen, vibration and the Play Games leaderboard code are in. Next: the owner-only steps of the Android release candidate (R7, `docs/release.md`). An iOS port was started on 2026-11-13 (owner request): code, export and build script are in; no iOS build has been signed or run (`docs/release-ios.md`). **Last updated:** 2026-11-13.
**Branch/commit:** `main`, remote `origin` = https://github.com/ranababu1/arrowlock.git. Version name 0.3.0 (`project.godot`), version code 38 (export preset, gitignored), the Play release candidate, subject to Play Console. Device APK: `tools/build_android.sh`; Play release (signed AAB + upload-key APK, verified): `tools/build_android.sh --release <key folder>` (`docs/release.md` §3).

## Feature status
| Area | Status |
|---|---|
| Godot project scaffold | Implemented; loads and starts headless |
| Rules engine, solvers, move limits | Implemented; tests pass. Undo takes back exactly one tap (wasted or not) and refunds it; empty-cell taps are free; a level is lost only at 0 moves (owner decision, even if already unwinnable) |
| Level select, game screen, win/game-over panels, hint/undo/extra moves | Implemented; verified on the emulator on 2026-11-01 (before today's changes) |
| Content | Easy and Difficult packs, 100 levels each, regenerated 2026-11-05 to get harder level by level (no breathers, no reused layouts) and **frozen** in `data/levels.lock.json`. Not reviewed by the owner (owner chose not to review now) |
| Level tooling | Generator with depth ranges per world, rising-depth floor and a switch to forbid reuse; validator; `tools/generate_levels.gd`, `tools/freeze_levels.gd` |
| Save v2 + rewards | Implemented and tested: stars, coins, world unlock, badges, v1 migration, vibration setting, leaderboard state. Older 0.1.0 saves load unchanged (defaults fill the new fields) |
| Score (leaderboard) | Implemented and tested: each clear scores 100 per star plus a speed bonus of up to 200 (half at par = 1.5 s per arrow, falling smoothly so ties are rare). Time counts from when the level opens, pauses while a panel is shown, and resets on Retry. Each level keeps its best score; the leaderboard posts the sum per mode (boards accept 0 to 1,000,000; the recorded value is capped at 500 × the mode's real level count, so a 400-level mode can reach 200,000). Shown on the win panel and the Profile screen. Speed pays no coins. Older saves get 100 per star until a level is replayed. Not tuned with players |
| Economy | Retuned: clear 20 + 5 per star, world bonus 50; Undo 20, Hint 30, +3 moves 50. Tests check that a one-star player can still buy a Hint on every level. Not tested with players |
| Difficulty tiers | Easy (no clock) and Difficult (10 s per tap, 2x coins). Chosen in Settings; switching is instant and keeps progress (each mode its own levels; coins and badges shared). Owner rule 2026-11-08, replacing the earlier wipe-on-switch |
| Profile screen (was Trophies) | Implemented and tested with a fake plugin (owner request 2026-11-08). Opened from the person button on the menu. Profile card: signed in to Play Games → gamer name and profile picture from Play Games (read-only; changed in the Play Games app); otherwise a local nickname (max 16 chars) and one of 8 built-in avatars, saved on the phone only, plus a sign-in button when Play Games is configured. Then stats for the current mode, the leaderboard card ("You appear as <name>") and all 7 badges. Not run on a device; the Play Games part needs the owner's Play Console setup |
| Vibration | Implemented: short buzz on a blocked tap, win and loss; Settings toggle. Needs the Vibrate permission in the export preset. Not felt on a device yet |
| Online leaderboard (Play Games) | Code implemented and tested with a fake plugin: optional sign-in, two boards (score per mode), scores sent only from the saved state and retried after failures. **Configured 2026-11-08:** Game ID `526309730403` (export preset, gitignored) and both leaderboard ids in `data/play_games.json`. Still needed from the owner: the Android OAuth credential in Play Console (SHA-1 of the signing key). Never run on a device |
| Ads (AdMob interstitial) | Implemented and tested with a fake plugin (owner request 2026-11-12): an interstitial when the player leaves the win/game-over panel (Next, Retry, Replay, Menu) on level 11+ in either tier, only when both 3 eligible rounds (level 11+, including replays) and 180 seconds have passed since the last ad (or since the first eligible finished round when none has been shown yet); counters persist in `user://ad_policy.json`; "+3 moves" never shows one. Consent form (UMP) first, then SDK init and preload. Plugin `addons/AdmobPlugin` v7.0 (MIT). Signed APK b33 builds and carries the AdMob app id. **Real AdMob ids set 2026-11-08** (app `~9418380851`, interstitial `/1268428091`); APK b34 carries the real app id. Never run on a device |
| Audio | Implemented; not yet listened to by the owner (deferred by the owner; nothing waits on it) |
| Settings | Difficulty, music, effects, tutorial tips, vibration, two volume sliders |
| Tutorial | Levels 1 to 3; still matches the new level 1 (tests check it); not user-tested |
| Safe-area insets | Implemented; not tested on a cutout device |
| Board size | Tests check that the biggest board of each pack keeps cells of at least 40 px at the 540x960 base layout |
| Release AAB workflow | Implemented 2026-11-08: `--release` builds a signed AAB (real ads) and an upload-key APK (test ads) and verifies package, version, arm64, Play Games and AdMob ids, signatures and the upload SHA-1 `57:AC:89:…:08:75`, then prints SHA-256. **Build 38 built by the owner and verified 2026-11-08** (`--verify`, all checks passed): `build/arrowlock-0.3.0-b38.aab` 33,551,529 bytes, SHA-256 `7df81ba30540c99a075a1526298b193f777add5c0b278517b247ccaceed441c5`; `build/arrowlock-0.3.0-b38-arm64-v8a-upload.apk` 91,436,002 bytes, SHA-256 `69223f6488c0dfde2d4e6612a68afe2ed0f30f123e436354a234800023e785af`; both signed with the upload key `57:AC:89:…:08:75`; built from commit `6440245`. Not uploaded; not run on a device |
| iOS (App Store) | Started 2026-11-13. In: AdMob iOS plugin binaries (`ios/plugins`), `addons/AdmobPlugin/ios_export.cfg`, per-platform ad unit id, Profile screen without Play Games or any Google wording where Play Games is not set up, 1024 icon, `tools/build_ios.sh` (device project, signed release .ipa with checks, `--verify`), `docs/release-ios.md`. Verified on the Mac with Xcode 16.4: export to an Xcode project with no errors; everything compiles; linking fails only on iOS 26 SDK symbols that Godot 4.7 needs, so **Xcode 26 is required**. **Not done:** archive, signing, .ipa, any run on an iPhone. No leaderboard on iOS (Play Games is Android-only; Game Center would need approval). No ads on iOS until the owner creates the iOS AdMob app and unit. ATT (tracking prompt) is off |
| Android export (M0) | Debug APK ran on the emulator (2026-11-01). Release candidate not built yet. Physical device not tested (deferred by the owner) |

## Architecture
- `scripts/core/` — pure logic: `board_state.gd`, `move_validator.gd`, `puzzle_solver.gd`, `game_controller.gd`, `economy.gd`, `progress.gd`, `difficulty.gd`, `tutorial.gd`, `board_canon.gd`, `level_metrics.gd`, `level_generator.gd`, `level_validator.gd`, `level_fingerprint.gd`, `leaderboard_sync.gd`.
- `scripts/services/` — `puzzle_repository.gd`, `save_service.gd`, `audio_manager.gd`, `haptics.gd`, `play_games.gd` (talks to the plugin's Android singleton; a no-op elsewhere), `ads.gd` (consent, preload and showing of interstitials through the AdmobPlugin's Admob node on Android and iOS, each with its own unit id; a no-op elsewhere). `scripts/core/ad_policy.gd` decides which game ends earn an ad and persists the frequency counters. `data/ads.json` holds the ad settings; `addons/AdmobPlugin/android_export.cfg` holds the manifest app id; `addons/AdmobPlugin/ios_export.cfg` the iOS Info.plist app id and the ATT switch. `ios/plugins/` holds the AdMob plugin's iOS libraries (v7.0).
- `scripts/ui/` — `main.gd` (router), `level_select.gd`, `settings_screen.gd`, `profile_screen.gd`, `avatar_view.gd`, `game_screen.gd`, `board_view.gd` and the design-system widgets.
- `data/packs/`, `data/packs_hard/` (levels), `data/levels.lock.json` (frozen fingerprints), `data/play_games.json` (leaderboard ids, empty for now), `data/levels.json` (4 levels, tests only).
- `addons/GodotPlayGameServices/` — third-party plugin (Android only), enabled in `project.godot`. Its autoload is not used by this game's code. Patched locally on 2026-11-13: its export hook now does nothing for other platforms (it made iOS exports report an error).
- `tools/` — `generate_levels.gd`, `freeze_levels.gd`, `world_specs.json`, `world_specs_hard.json`, `make_audio.py`, `make_icon.py`, `build_android.sh`, `aab_manifest.py`, `build_ios.sh`. `tests/run_tests.gd` — test runner.
- Docs: `plan.md` (baseline), `level-plan-100.md` (release 1 + owner decisions in §11), `release.md` (Android release steps and Play checklist), `release-ios.md` (iOS release steps and App Store checklist), `instructions.md`, `changelog.md`.

## Toolchain
Godot 4.7.2 stable. `config/features` says 4.3; the project runs on 4.7.2.

## Build/test status
Verified 2026-11-05 in a Linux container with the official Godot 4.7.2 build:
- `godot --headless --path . -s tests/run_tests.gd` → **595 passed, 0 failed (2026-11-12, Linux, Godot 4.7.2)**. Earlier: 544 passed, 0 failed (2026-11-08, Windows, Godot 4.7.2).
- `tools/build_android.sh --bump` → signed `arrowlock-0.3.0-b33-arm64-v8a.apk`, 90.8 MB (was 80.6 MB; the ads SDK adds about 10 MB). Its manifest has the AdMob app id (Google's sample) and the AD_ID permissions (2026-11-08, Windows). Not installed on a device.
- `godot --headless --path . -s tools/generate_levels.gd` (and `-- --hard`) → 100 levels each, 0 variants, 0 failures.
- `godot --headless --path . --quit-after 120` → starts with no script errors.
- 2026-11-13, macOS 15, Godot 4.7.2: `godot --headless --path . -s tests/run_tests.gd` → **608 passed, 0 failed**. `tools/build_ios.sh` → `build/ios/Arrowlock.xcodeproj` exported, no errors. `xcodebuild … -sdk iphoneos CODE_SIGNING_ALLOWED=NO build` with Xcode 16.4: compiles; link fails on `CADynamicRange*` and `MTLTensorDomain` (iOS 26 SDK); storyboard and asset catalog not compiled (no iOS platform installed in that Xcode).
- Not done here: Android export, emulator or device runs (no Android SDK in that container). The plugin's editor code was not run there either.

## Known issues / risks
- iOS: this Mac has Xcode 16.4; Godot 4.7's iOS libraries do not link with it and the App Store needs Xcode 26. Nothing on iOS has run on a device, so safe areas, audio, vibration, the consent form and ads are untested there.
- iOS: the AdMob plugin adds `NSAllowsArbitraryLoads` to Info.plist (Google's guidance); App Review may ask about it.
- `build/` sits inside the project folder, so Godot scans it. `tools/build_ios.sh` writes `build/.gdignore`; the Android script does not, so an Android export on a machine with old build output may pack `build/**/*.json` into the game (harmless, a few KB).
- The Play Games plugin v3.4.0 is documented for Godot 4.5; it has not been built with 4.7.2 yet. The first Gradle export may need a plugin update.
- No player has played the new packs; the difficulty is measured by the generator (arrows, chain depth, spare moves), not by people.
- Difficult boards go up to 9x12; cells are about 50 px at the 540x960 base layout, which is small on narrow phones.
- Economy numbers are untested with players.
- A level is lost only at 0 moves even if already unwinnable (by design).
- Emulator `adb` is flaky; `DirAccess.rename_absolute` overwrite on Windows and save atomicity are unverified.
- Levels are frozen: changing a released level breaks the tests on purpose. Add new levels only after level 100.

## Next steps
iOS (owner, `docs/release-ios.md`): Apple Developer Program and Team ID; Xcode 26; Team ID in the export preset; iOS app and interstitial unit in AdMob, then the two ids in the repo; run on an iPhone; `tools/build_ios.sh --release`; TestFlight; listing, privacy policy and App Privacy form.

Android:
0. Owner: publish the GDPR message in AdMob (Privacy & messaging) and register your phones as AdMob test devices; install b34 and check that an ad appears after a game on level 11 (new units can take an hour to serve).
1. Owner: Play Console app, Play Games project, two leaderboards, OAuth client; put the leaderboard ids in `data/play_games.json` (`docs/release.md` §1).
2. Owner: export preset with Gradle build, Vibrate permission, Game ID and signing; export the release candidate (`docs/release.md` §2–3).
3. Owner: device checks and the upgrade test on a physical phone, then the internal test track (`docs/release.md` §4–5).
4. Owner, later: listen to the audio, try the tutorial, play the packs and report anything too hard or too easy.
5. Play listing, privacy policy and Data safety (`docs/release.md` §6) before any wider release.

## Decisions needing owner approval
- None open. All decisions of 2026-11-05 are recorded in `docs/level-plan-100.md` §11. A production release still needs explicit approval (`instructions.md` §7).
