# Release Guide (R7: Android release candidate)

How to turn `main` into a build on the Play Console internal test track. Steps marked **Owner** need your Google account, signing key or a physical phone, so an agent cannot do them. Everything else is already in the repository.

Current candidate: version name **0.3.0** (`project.godot` → `application/config/version`), build number (version code) **32**. Build with `tools/build_android.sh --bump`, which raises the build number, runs the tests and writes `build/arrowlock-<version>-b<code>-arm64-v8a.apk`. Version codes only go up: internal builds already used 31 and 32.

## 1. One-time Play Console setup (Owner)

1. Create the app in Play Console: name "Arrowlock", default language English, Game, Free.
2. Package name must be **`dev.imrn.arrowlock`** (cannot be changed later).
3. Play Games Services → create a project for this game.
   - Credentials → add an **Android** OAuth client with the package name and the **SHA-1 of the signing key** (both the upload key and Play App Signing key, see step 5).
   - Leaderboards → create two:
     | Name | Score format | Order | Limits |
     |---|---|---|---|
     | Score (Easy) | Numeric, 0 decimals | Larger is better | 0 to 50000 |
     | Score (Difficult) | Numeric, 0 decimals | Larger is better | 0 to 50000 |
   - Copy the **Game ID** (a number) and both **leaderboard IDs** (strings starting `CgkI`).
   - Publish the game services configuration (testers only is enough for the internal track; add your test accounts as testers).
4. Put the two leaderboard IDs in `data/play_games.json` (`score_easy`, `score_difficult`), commit and push. They are not secrets. While they are empty the leaderboard button stays off and nothing is sent.
5. Signing: keep the upload keystore outside Git (`*.keystore`/`*.jks` are ignored). Enrol in Play App Signing.

## 2. Export preset (Owner, once per machine)

`export_presets.cfg` is gitignored, so recreate it in the Godot editor (Project → Export → Add → Android):

| Setting | Value |
|---|---|
| Use Gradle Build | **On** (the Play Games plugin needs it). First run Project → Install Android Build Template. |
| Package → Unique Name | `dev.imrn.arrowlock` |
| Version → Code / Name | `32` / empty (empty = use `project.godot`; `tools/build_android.sh --bump` raises the code) |
| Permissions | **Vibrate** on (for the Vibration setting). Internet is added by the Play Games plugin. Nothing else. |
| GodotPlayGameServices → game_id | the Game ID from step 1.3 |
| Keystore → Release | path, alias and password of the upload key (stored in `export_credentials.cfg`, which is gitignored) |
| Export format | AAB for Play, APK for local testing |
| Resources → filters | keep `*.json` included (levels, lock file, Play Games config) |

Check that Project → Project Settings → Plugins shows **GodotPlayGameServices** enabled (it is enabled in `project.godot`).

## 3. Build and check before upload

1. On the build machine:
   ```
   godot --headless --path . -s tests/run_tests.gd
   ```
   Must end with `0 failed`.
2. Export a **release** AAB (and an APK of the same commit for sideloading).
3. Record the artifact filename, version name, version code and commit hash in `docs/changelog.md`.

## 4. Device checks (Owner, physical phone)

Do these on a real phone with the release APK. Write the result of each line in the changelog.

- [ ] Clean install starts without a crash; the menu shows Easy mode, 0 / 300 stars, 100 coins.
- [ ] Level 1 tutorial shows; a blocked tap vibrates (Vibration on) and does not when switched off.
- [ ] Win a level, close the app from the recent-apps list, reopen: stars and coins kept.
- [ ] Press Home in the middle of a level and come back: the level is still there (Difficult: check the clock did not run out while away).
- [ ] Android back: from a level goes to the menu; from the menu closes the app.
- [ ] Trophies screen: stats right; "Sign in with Play Games" signs in; after a cleared level, the score (Trophies → Score) appears on the leaderboard (can take a few minutes).
- [ ] Turn on airplane mode, clear a level, go back online and reopen: the new total is posted then.
- [ ] Notch/cutout phone: nothing hidden under the camera or the gesture bar.
- [ ] **Upgrade test:** install the previous build, clear 2 levels, then install the new one over it without uninstalling. Progress must still be there. (The automated tests cover the save format; this checks the real install path.)

## 5. Internal test track (Owner)

1. Play Console → Testing → Internal testing → Create release → upload the AAB.
2. Release notes, for example: "First test build: 100 Easy and 100 Difficult levels, badges and stats, vibration, Play Games leaderboard."
3. Add testers (email list) and share the opt-in link.

## 6. Play listing checklist (Owner, before any wider release)

- [ ] App name, short and full description, icon 512x512, feature graphic 1024x500, at least 2 phone screenshots.
- [ ] Category: Puzzle. Contact email.
- [ ] Privacy policy URL. It must mention: Google Play Games sign-in (optional), the player ID and score sent to Google's leaderboard, everything else stays on the device, no ads, no analytics.
- [ ] Data safety form: the only data leaving the phone is the Play Games player ID and the score, sent to Google only for players who sign in. Declare it as optional, used for app functionality, not shared and not sold, encrypted in transit. Nothing else is collected (no crash reports, no analytics). Check the exact categories against Google's form, since its wording changes.
- [ ] Ads declaration: no ads.
- [ ] Content rating questionnaire: no violence, no user content, no purchases → expected Everyone / PEGI 3.
- [ ] Target audience: not designed for children under 13 unless you want the Families policy (it adds requirements).
- [ ] Target SDK meets the current Play requirement (Godot 4.7 export default; confirm in Play Console's warnings).
- [ ] No production release without your explicit approval (`instructions.md` §7).

## 7. After release: levels are frozen

`data/levels.lock.json` fingerprints every shipped level. The tests fail if a released level changes, because saved stars belong to a layout. To add content later, append new levels after level 100 and re-run `tools/freeze_levels.gd`; never regenerate or edit existing ones.
