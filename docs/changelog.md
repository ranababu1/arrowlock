# Changelog

Reverse chronological. See `instructions.md` §8 for entry requirements.

## 2026-11-08 — Play release workflow: signed AAB, verification, test ads on APKs

Owner asked for Play Store AAB readiness (audit first, then approved): one release command makes an AAB and an APK, the upload key folder is given at build time, APKs use test ads and only the AAB uses real ads.

### Audit findings (before changes)
- Gradle build, package `dev.imrn.arrowlock`, arm64-v8a, `*.json` filter, launcher icons, Vibrate, Game ID `526309730403` and both leaderboard ids were already correct. Internet / network state come from the plugins; no extra permissions.
- Gaps: export format was APK only; signing used the internal keystore; no AAB build or verification; `release.md` still named version code 32; every build, including sideloaded APKs, served real ads.
- `aapt2` cannot read an AAB's (protobuf) manifest; downloading Google's bundletool was not permitted in this environment, so a small reader was written instead.

### Added
- `tools/build_android.sh --release <key folder or env file> [--bump] [--overwrite]`: runs tests, validates the export and data configuration, exports `build/arrowlock-<v>-b<code>.aab` (real ads) and `build/arrowlock-<v>-b<code>-arm64-v8a-upload.apk` (test ads), both with the upload key, then verifies bundle structure, package, version name and code, arm64-v8a, Play Games `APP_ID` and Game ID, the real AdMob app id, the build stamp, `jarsigner -verify`, the AAB and APK certificate SHA-1 against `57:AC:89:CF:26:6A:D1:8D:16:07:ED:4E:EA:C4:34:9C:41:50:08:75`, and prints size and SHA-256. Refuses to replace existing artifacts without `--overwrite`. Credentials come from `<folder>/upload.env` or a hidden prompt; export logs have the password masked; nothing is stored in Git or CI. The preset's export format is switched to AAB (`1`) only for that export and restored on exit, even after a failure.
- `tools/aab_manifest.py`: dependency-free reader for the AAB's protobuf manifest (package, versions, permissions, meta-data, ABIs).
- `scripts/services/build_info.gd`: reads the build stamp. The plain APK workflow is unchanged except that it now stamps `test_ads: true`.
- `Ads` obeys the stamp: a test-ads build always uses Google's test interstitial unit, whatever `data/ads.json` says.
- Godot 4.7.2 export format values checked by exporting a probe: `gradle_build/export_format=1` produced a real bundle (`BundleConfig.pb`, `base/manifest/`, `base/lib/arm64-v8a/`).
- Tests: test-ads stamp forces test ads, release stamp keeps real ads, no stamp defers to `ads.json`, a broken stamp forces nothing. 570 passed, 0 failed.

### Docs
- `release.md`: version code 38 as the candidate (subject to Play Console), both workflows, signing without passwords, the verification list, and the upload-key vs Play App Signing SHA-1 distinction (two Android OAuth credentials). AdMob notes updated for the stamp.

### Not done (owner)
- Signed release build not run yet: it needs the upload key credentials at build time.
- Play Console: upload, Play App Signing enrolment and its SHA-1, both OAuth credentials, Data safety, ads and Advertising ID declarations. No upload or publish was attempted.

## 2026-11-08 — Play Games ids, score cap from level count, build number in About (build 38)

### Changed
- `data/play_games.json`: `score_easy` = `CgkI49CE1KgPEAIQAA`, `score_difficult` = `CgkI49CE1KgPEAIQAQ`. The online leaderboard is now switched on in builds.
- Play Games Game ID `526309730403` set in the export preset (`godot_play_game_services/game_id`; the plugin writes it to the `game_services_project_id` string resource). The preset is gitignored; `docs/release.md` §2 records the value.
- Leaderboards in Play Console now accept 0 to 1,000,000 (owner). `Economy.LEADERBOARD_MAX = 1_000_000`. The saved "already sent" score is bounded by that on load, then capped at `MAX_LEVEL_POINTS × the mode's real level count` once the packs are loaded (`Progress.cap_leaderboard_sent`, called from `main.gd`). It used to be a fixed `MAX_LEVEL_POINTS × 100`, which would have wrongly capped scores after a 400-level expansion.
- About in Settings: the version already came from `project.godot` (0.3.0 since build 32; "0.2.0" was an older install). It now also shows the build number, e.g. "Arrowlock 0.3.0 (build 38)", stamped by `tools/build_android.sh` into the gitignored `data/build_info.json` on every build.
- Tests: score cap (board limit, 100- and 400-level modes, empty pack), version text with and without a build stamp. 566 passed, 0 failed.

### Not done
- Release AAB and upload-key SHA-1: dropped by the owner for now.

## 2026-11-08 — Profile screen with Play Games name and picture (build 37)

Owner: players should see a profile with their badges, leaderboard name and picture; take what Google allows from the Play account, otherwise let players enter their own details.

### Added
- **Profile screen** replaces the Trophies screen (`profile_screen.gd`, renamed from `trophies_screen.gd`); the menu's star button is now a person button.
- **Signed in to Play Games:** the card shows the Play Games gamer name and profile picture (`PlayGames.player_name`, `player_picture`). The name is the one other players see on the leaderboard; the leaderboard card says "You appear as <name>". Loaded with the plugin's `loadCurrentPlayer`; the plugin downloads the picture through Google's ImageManager into the app's private files and reports it with `imageStored`. This is Play Games' public gamer profile, not the Google account: no email, no real name, no extra permission. Read-only in the game (Google does not let apps change it).
- **Not signed in:** a local nickname (max 16 characters, cleaned of control characters) and one of 8 built-in avatars (`avatar_view.gd`), saved on the phone only and never sent anywhere. No photo upload: it would need storage access and raises privacy and moderation issues for a public leaderboard. A "Sign in with Play Games" button shows when Play Games is configured in the build.
- Save gains `profile_name` and `profile_avatar` (save stays v2; older saves get "Player" and the first avatar).
- New `person` glyph.
- Tests: name cleaning, damaged fields, save round-trip, editor flow, sign-in from the profile, gamer name and caption, picture shown only after the right `imageStored`, broken player record ignored, menu button. 559 passed, 0 failed.

### Known
- Play Games part not run on a device and inert until the Play Console setup is done (Game ID and leaderboard ids, `docs/release.md` §1).
- Play Games v2 has no in-game sign-out; players manage it in the Play Games app.

## 2026-11-08 — New app icon (build 36)

Owner supplied the icon art (navy rounded square, green and white chevrons) for the phone's app list.

### Added
- `tools/icon_source.png` (owner art, 1254x1254) and `tools/make_icon.py` (Pillow), which writes `assets/icon/`: `icon_512.png` (rounded square, transparent corners; project icon and legacy launcher icon), and Android adaptive icon layers `adaptive_foreground_432.png` (chevrons only, cut out by brightness, sized to stay inside the 66 dp safe circle), `adaptive_background_432.png` (navy gradient) and `adaptive_monochrome_432.png` (Android 13 themed icons). Adaptive layers are needed because launchers crop icons to circles or squircles; the plain square art would show black corners or be cut.
- `project.godot` `config/icon` → `res://assets/icon/icon_512.png` (was the Godot placeholder `icon.svg`).
- Export preset (gitignored, set locally and documented in `docs/release.md` §2): all four launcher icon slots point at the files above.

### Checked
- b36 APK: `mipmap/icon` is an adaptive icon with background, foreground and monochrome layers; the extracted images are the new art. Previewed under circle, rounded-square, squircle and themed masks. Tests: 542 passed, 0 failed. Not seen on a phone's launcher yet.

## 2026-11-08 — Switching difficulty keeps progress (build 35)

Owner: do not reset progress when a player swaps difficulty. This replaces the 2026-11-05 decision (`level-plan-100.md` §11) that a switch wipes progress.

### Changed
- `Progress.switch_difficulty` only changes the mode in play. Easy and Difficult levels were already stored side by side (Difficult ids are offset by 1000), so nothing else had to change and no save migration is needed.
- Coins and badges are shared between modes (as they already were within a save). Difficult still pays 2x coins, and those coins can now be spent in Easy.
- Settings: tapping the other mode switches at once; the "Reset your progress?" dialog is gone. Caption now reads "Switch any time. Each mode keeps its own progress; coins and badges are shared."
- Leaderboards were already per mode, so nothing changes there.
- Players who switched on an earlier build already lost that progress; it cannot be restored.
- Tests rewritten for the new rule: levels, stars, coins, badges and settings survive a switch and a reload, both modes keep their own clears, Difficult stays playable after switching back. 542 passed, 0 failed.

## 2026-11-08 — Real AdMob ids (build 34)

- Owner created the AdMob app and the interstitial unit. `android_export.cfg`: `is_real=true`, app id `ca-app-pub-1106747567696734~9418380851`. `data/ads.json`: `use_real_ads=true`, unit `ca-app-pub-1106747567696734/1268428091`. Ids are public by design (they ship in every APK).
- b34 manifest checked: carries the real app id. Tests: 545 passed, 0 failed (the real-ids check now runs). Not run on a device.
- Builds from now on serve real ads, including on the owner's phones: register them as AdMob test devices so own impressions/taps are not counted as invalid traffic.

## 2026-11-08 — Interstitial ads after level 10 (build 33)

Owner: show ads after level 10, after every game. Owner choices: levels 11+ in both tiers, at most one ad per 60 seconds, wins and losses both. This approves the ads SDK that `instructions.md` §2 and §4 require approval for.

### Added
- **AdMob interstitials.** Shown when the player leaves an end-of-game panel (Next, Retry, Replay, Menu), not when the panel opens: AdMob forbids interstitials that appear over content the player is looking at, and the result and stars stay visible. "+3 moves" continues the same game, so it never shows an ad. If no ad is loaded, the game carries on at once (it never waits on the network).
- `scripts/core/ad_policy.gd` (which games earn an ad), `scripts/services/ads.gd` (consent → init → preload → show → preload the next; failed loads retry after 30 s, doubling to 5 min). Settings in `data/ads.json`.
- **Consent (UMP)** runs at launch before the SDK starts: the form appears for players who need it (EEA/UK). Without an answer (for example offline on first launch), no ads are requested that session.
- Dependency: `addons/AdmobPlugin` v7.0 + `addons/GMPShared` (MIT, github.com/godot-sdk-integrations/godot-admob, released 2026-05-27; pulls `play-services-ads:24.9.0` through Gradle). Chosen because it is maintained, MIT, supports Godot 4.4+ and includes UMP consent. Alternatives (Poing Studios, mircea35) are older or unmaintained.
- Tests: policy rules, shipped config, the two real/test switches agree, the consent paths, show/close/failed-to-show, backoff, and the game screen (no ad over the panel, ad before the menu, Replay waits, +3 moves never, level 1 never). 544 passed, 0 failed.

### Changed
- APK is about 10 MB bigger (80.6 → 90.8 MB, arm64). The manifest gains `AD_ID` and the ad-services permissions from the SDK.
- `docs/release.md`: new §6a (AdMob setup); privacy policy, Data safety and ads declarations now say the app has ads.

### Known
- Builds show **Google's test ads** until the owner creates the AdMob app and unit and sets the ids (`docs/release.md` §6a).
- Not run on a device: consent form, ad display and the return to the game are verified only with a fake plugin.
- Music may keep playing behind the ad, depending on how Godot pauses on Android; check on a phone.

## 2026-11-07 — 0.3.0 (build 32): speed score for the leaderboard, logo splash screen

Owner: the game is fairly easy, so a star leaderboard (max 300) would fill up with ties; give more points for faster solves.

### Changed
- **Leaderboard posts a score instead of the star total.** A clear scores `100 × stars + speed bonus`. Speed bonus = `round(200 × par / (par + seconds))`, par = 1.5 s per arrow: 200 for an instant solve, 100 at par, 67 at twice par, never zero. Each level keeps its best score (stars and fastest time are tracked separately, so they can come from different runs); the leaderboard gets the sum per mode, at most 50,000. Constants in `Economy` (`POINTS_PER_STAR`, `SPEED_BONUS_MAX`, `PAR_SECONDS_PER_ARROW`).
- Time is counted from the moment the level opens (not the first tap, so studying the board counts), pauses while the win or game-over panel is shown, keeps running after buying +3 moves, and resets on Retry. Time while the app is in the background is not counted.
- Coins are unchanged; speed pays no coins.
- `data/play_games.json` keys renamed `stars_easy`/`stars_difficult` → `score_easy`/`score_difficult` (no ids had been set yet). Play Console leaderboards should be named "Score (Easy/Difficult)" with limits 0 to 50000 (`docs/release.md` §1).
- Save format stays v2: levels gain `best_points` and `best_seconds`. Older saves get 100 per star and no time until a level is replayed.
- Version 0.2.0 → **0.3.0**, build number (version code) 2 → **32**: internal builds had already used 31, and Android will not install a lower code over a higher one. New `tools/build_android.sh` (`--bump` raises the build number, runs the tests, names the APK `arrowlock-<version>-b<code>-arm64-v8a.apk`).
- Boot splash is now the owner's logo (`assets/splash.png`, rounded corners, dark background) instead of the Godot logo.

### Added
- Win panel shows the time, the points of the run and the best score; Trophies shows Score.
- Tests: speed bonus shape, best-score keeping, sums per mode, old-save fallback and clamping, controller timing, time formatting (503 passed, 0 failed).

### Known
- Not tested with players: par time and the bonus size are guesses.
- Scores are computed on the phone, so a modified app could post anything; acceptable for a free game without prizes.

## 2026-11-05 — Owner decisions applied: rising difficulty, frozen packs, trophies, vibration, Play Games leaderboard, release guide

Owner answers to the open questions (recorded in `level-plan-100.md` §11) were applied without waiting for a playtest, as asked.

### Changed
- **Undo** now takes back exactly one tap, wasted or not, and refunds that move; an undone wasted tap no longer counts as wasted (so it no longer costs a star). Still 20 coins. (Before: only removals could be undone.)
- **Clock only in Difficult** (10 s per tap). Easy has no clock at all; it used to start a 20 s clock at level 31.
- **Both packs regenerated to get harder level by level** (owner: "make them incrementally difficult", no review for now). Spec changes in `tools/world_specs*.json`:
  - no breather levels (`breathers: false`); arrow ranges of neighbouring worlds no longer overlap;
  - each world has an explicit, reachable chain-depth range (`depth: [first, last]`) and the generator never picks a shallower board than the previous level (`rising_depth: true`); 250 attempts per level;
  - no reused layouts (`allow_variants: false`). Reuse question (left to the agent): none. Every level is unique, and the old limits stay in the validator only as a safety net.
  - Easy now runs 3 arrows on 3x3 (depth 1, 3 spare moves) up to 40 arrows on 8x11 (depth 16, 4 spare); spare moves fall from 100% to 10% of the arrows. Difficult runs 16 arrows on 5x7 (depth 7) up to 58 arrows on 9x12 (depth 18), always one spare move.
- **Coins retuned** (owner left it to the agent): clear reward 10 → 20, world bonus 25 → 50, 5 per star unchanged. Reason: at the old values a one-star player who bought a Hint (30) on each level was broke within 8 levels. Now that player stays at about break-even.
- Version name 0.1.0 → 0.2.0 for the release candidate.

### Added
- **Level freeze:** `scripts/core/level_fingerprint.gd`, `tools/freeze_levels.gd` and `data/levels.lock.json` (one fingerprint per level of both packs). A test fails if a locked level's layout, size or move limit changes, because saved stars belong to that layout. New levels may only be added after level 100.
- **Trophies screen** (`scripts/ui/trophies_screen.gd`, star button on the menu): stats for the current mode (levels, stars, perfect levels, finished worlds, coins, badges), all 7 badges with how to earn them, and the leaderboard button. Badge names moved to `Progress.BADGE_INFO`.
- **Vibration** (`scripts/services/haptics.gd`): 35 ms on a blocked tap, 60 ms on a win, 160 ms on a loss; a Vibration toggle in Settings (saved as `haptics_enabled`, default on). Uses `Input.vibrate_handheld` on phones only; needs the Vibrate permission in the export preset.
- **Google Play Games leaderboard** (owner approved, "build it now"):
  - Dependency: `addons/GodotPlayGameServices` v3.4.0 (commit e38b618, MIT, about 376 KB including the debug and release AARs) from github.com/godot-sdk-integrations/godot-play-game-services. Picked because it is the maintained Godot 4 plugin hosted by the Godot Foundation. Enabled as an editor plugin; its autoload is not registered, because our code uses the Android singleton directly. Adds the Internet permission to the Android build.
  - `scripts/services/play_games.gd`: optional sign-in (silent check on launch), two leaderboards (star total per mode), submits on sign-in and on each return to the menu. `scripts/core/leaderboard_sync.gd` decides what still needs sending from the saved stars (saved as `leaderboard_sent`); failed submits are retried. Without the plugin or without ids everything is a no-op, so the game works offline and signed out.
  - `data/play_games.json` holds the two leaderboard ids, empty until the Play Console project exists.
- **`docs/release.md`:** Play Console and Play Games setup, export preset, build checks, a device and upgrade checklist, internal test track steps and the Play listing / Data safety checklist (R7).
- Tests: rising difficulty for both packs (arrows, depth, spare moves; level 100 is the peak), no reuse, frozen levels, biggest board at least 40 px per cell at 540x960 (Difficult level 100 measures 50 px), badge texts and stats, vibration and its setting, leaderboard sync, the Play Games service against a fake plugin (sign-in, submit, failure and retry, saved state, opening the board), the Trophies screen, economy balance, and save fields from 0.1.0 saves.

### Docs
- `level-plan-100.md`: status updated (no longer a proposal); §11 now records the owner's decisions.
- `instructions.md`: owner rules: no `Co-Authored-By` lines, work on `main` only, commit as the owner.
- `currentstate.md` rewritten to match the code (the old "nothing from these plans is implemented" line was stale).

### Verification
- Linux container, official Godot 4.7.2 build: `godot --headless --path . -s tests/run_tests.gd` → 472 passed, 0 failed. Generators: 100 levels each, 0 variants, 0 failures. `--quit-after 120` main-scene start: no script errors.
- Not verified: no Android export, emulator or device run today (no Android SDK in that container); the plugin has not been built with Godot 4.7.2 or run on a device; vibration not felt; leaderboard not connected to a real Play Games project; no human has played the new packs.

## 2026-11-02 — Difficulty is chosen in Settings; switching resets progress

### Changed
- The Easy / Difficult buttons moved from the menu to Settings. A player plays one mode at a time and the other is locked. The menu only names the mode in play ("Easy mode" / "Difficult mode") with its rules.
- Choosing the other mode in Settings opens a warning ("Reset your progress?") saying that all stars, coins and badges are erased, that the other mode is locked until switching back, that switching back erases the new progress too, and that it cannot be undone. "Keep my progress" changes nothing; "Erase progress and switch" resets (`Progress.switch_difficulty`): levels and badges cleared, coins back to 100, sound/volume/tips settings kept; saved immediately.
- This replaces the earlier behaviour (both modes open at once, separate progress per mode). Level ids and the Difficult pack are unchanged.

### Verification
- `godot_console --headless --path . -s tests/run_tests.gd`: 408 passed, 0 failed (warning shown first and nothing changes while it is open; cancel keeps progress; confirm erases levels, badges and coins, keeps audio settings, saves, and tells the app; switching back also resets; switching to the current mode is refused).
- Emulator, seeded save (640 coins, 2 levels, 1 badge): tapping Difficult showed the warning with the save unchanged; "Keep my progress" left it unchanged; "Erase progress and switch" wrote `difficulty 1`, 100 coins, no levels, no badges, and the menu then read "Difficult mode" with 0 / 300 stars.
- Not verified: wording by a real player; a restart of the app after switching (the save file was checked, not a cold start).

## 2026-11-01 — Easy and Difficult tiers with a per-tap countdown

### Added
- Two difficulty tiers, switched with an Easy / Difficult button on the menu (Easy is the default; the choice is saved as `difficulty`). Each tier has its own 100 levels, stars, world unlocks (8 of 10 in the previous world, per tier) and progress; Difficult levels are saved under ids 1001 to 1100 (`Difficulty`).
- Countdown (`GameController`): the clock starts at the first tap on an arrow and every later tap on an arrow (blocked or not) refills it; Undo and Hint refill it too; taps on empty cells do not. Running out of time loses the level ("Time's up"; +3 moves is not offered because it would not return the time). Difficult: 10 s on every level. Easy: no clock for levels 1 to 30, 20 s from level 31. The game screen shows the clock as a bar and seconds (capped at 0.25 s per frame so a stalled frame cannot lose a level).
- Difficult pack `data/packs_hard/` (100 levels, draft, NOT owner-reviewed), generated by `tools/generate_levels.gd -- --hard` from `tools/world_specs_hard.json`: 16 to 58 arrows on boards up to 9x12, one spare move, a 93% chance that each arrow is placed on the previous arrow's ray (new `chain` option in `LevelGenerator.generate_board`), and a pull toward few free arrows (`free_weight`). New spec fields `depth_ratio`, `min_slack`, `chain`, `free_weight` (Easy specs unchanged; the Easy pack regenerates byte-identical).
- Difficult pays twice the coins (clear, stars, world bonus). New badge "Difficult cleared" (`hard_clear`). "All 100 levels cleared" now needs 100 in one tier.

### Fixed
- The new tests caught that +3 moves would have charged 50 coins after a timeout without granting the moves; it is now refused before spending.

### Verification
- `godot_console --headless --path . -s tests/run_tests.gd`: 396 passed, 0 failed (new tests: ids, clock rules, tier progress and rewards, hard pack validity, chained generation, menu switch, countdown on the real screen).
- Emulator (dev.imrn.arrowlock): the menu switch highlights Difficult in red and shows its rule; Difficult level 1 shows 17 moves for 16 arrows and "10 s per tap, starts on your first tap"; after one tap the clock read 6.9 s three seconds later; after 10 s idle the "Time's up" panel showed with Retry and Menu only.
- Generator metrics (not a measure of how hard a human finds it): Easy world 10 averages 28 arrows, dependency depth 9, 13 free arrows at the start; Difficult world 10 averages 55 arrows, depth 18, 18 free arrows.
- Not verified: how hard Difficult feels to a person (no playtest); whether 10 s and 20 s are right; clock behaviour after pausing the app; the Easy tier from level 31 on a device.

## 2026-11-01 — Tutorial tips and volume sliders

### Added
- `Tutorial` (pure rules) for the first three levels. Level 1: a tip card and a green pulsing outline on a free arrow that blocks nothing; after the first tap, the blocked arrow is outlined in red and the arrow blocking it in white, with text explaining that tapping a blocked arrow wastes a move; then an encouraging line. Level 2: explains that every tap costs a move. Level 3: mentions Hint and its cost. Tips end once level 3 is cleared for the first time and can be switched back on in Settings ("Tutorial tips"). Saved as `tips_enabled`.
- `GameScreen` tip card and `BoardView` pointers; frames pulse brighter.
- Volume sliders in Settings for music and effects (`VolumeBar`; saved as `music_volume` and `sfx_volume`, 0..1; 1 = the mixed level; values are clamped on load). Effects slider plays a sample on release. Mute toggles still work independently.

### Verification
- `godot_console --headless --path . -s tests/run_tests.gd`: 313 passed, 0 failed. New tests cover each tutorial step against the real level 1 to 3 boards, the tip card and pointers through a full level-1 playthrough on the real screen, tips ending after level 3, the Settings toggle, volume save/clamp/load, correct dB on both buses, drag/press/release behaviour of the slider and its Settings wiring.
- Emulator (dev.imrn.arrowlock), fresh install: level 1 shows the tip and green pointer; after one tap shows the red blocked arrow, the white blocker and the explanation; Settings shows the new toggle and sliders; a real swipe on the music slider wrote `music_volume` 0.4265 to the save file.
- Not verified: how it sounds at different slider positions (no listening here); the tutorial on levels 2 and 3 on the device (covered by tests only); that new players understand the tips (no user test yet).

### Sound feedback
- Audio has not been changed beyond the earlier softening of the clear effect: there is no listening feedback yet. The sliders let the owner set a taste level; specific changes (tone, tempo, which effects feel wrong) need the owner's notes, then edit `tools/make_audio.py` and rerun it.

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
