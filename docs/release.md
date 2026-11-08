# Release Guide (R7: Android release candidate)

How to turn `main` into a build on the Play Console internal test track. Steps marked **Owner** need your Google account, signing key or a physical phone, so an agent cannot do them. Everything else is already in the repository.

Current candidate: version name **0.3.0** (`project.godot` → `application/config/version`), version code **38**, subject to Play Console: Play has received no upload yet, so 38 is free there. Local sideload APKs have used codes up to 38; Play only rejects codes it has itself received. Release build: `tools/build_android.sh --release <key folder>` (§3).

## 1. One-time Play Console setup (Owner)

1. Create the app in Play Console: name "Arrowlock", default language English, Game, Free.
2. Package name must be **`dev.imrn.arrowlock`** (cannot be changed later).
3. Play Games Services → create a project for this game.
   - Credentials → add **two Android** OAuth clients, both with package `dev.imrn.arrowlock`, one per certificate (they are different keys and are not interchangeable):
     - **Upload key** SHA-1 `57:AC:89:CF:26:6A:D1:8D:16:07:ED:4E:EA:C4:34:9C:41:50:08:75` (`D:\Keys\Arrowlock\arrowlock-upload.jks`, alias `arrowlock-upload`): covers APKs you sign and sideload yourself.
     - **Play App Signing key** SHA-1: Play Console → Test and release → App integrity → App signing, after enrolling in Play App Signing with the first upload. Covers every install from Play (Google re-signs those). Without it, sign-in fails for Play installs.
   - Leaderboards → create two:
     | Name | Score format | Order | Limits |
     |---|---|---|---|
     | Score (Easy) | Numeric, 0 decimals | Larger is better | 0 to 1000000 (done 2026-11-08, id `CgkI49CE1KgPEAIQAA`) |
     | Score (Difficult) | Numeric, 0 decimals | Larger is better | 0 to 1000000 (done 2026-11-08, id `CgkI49CE1KgPEAIQAQ`) |
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
| Version → Code / Name | `38` / empty (empty = use `project.godot`; `--bump` on the build script raises the code) |
| Permissions | **Vibrate** on (for the Vibration setting). Internet is added by the Play Games plugin. Nothing else. |
| GodotPlayGameServices → game_id | `526309730403` (the plugin writes it to `game_services_project_id` in strings.xml) |
| Keystore → Release | leave empty: the build script passes the key through `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables (§3) |
| Gradle Build → Export Format | leave **APK** (`0`). The release script switches it to AAB (`1`, checked against Godot 4.7.2 by inspecting the exported bundle) for the AAB export and puts it back |
| Resources → filters | keep `*.json` included (levels, lock file, Play Games config, ads config) |
| Launcher Icons → Main 192x192 | `res://assets/icon/icon_512.png` |
| Launcher Icons → Adaptive Foreground / Background / Monochrome 432x432 | `res://assets/icon/adaptive_foreground_432.png`, `adaptive_background_432.png`, `adaptive_monochrome_432.png` (regenerate with `python -I tools/make_icon.py` from `tools/icon_source.png`) |

Check that Project → Project Settings → Plugins shows **GodotPlayGameServices** enabled (it is enabled in `project.godot`).

## 3. Build and check before upload

Two workflows, both in `tools/build_android.sh` (Git Bash on Windows):

| Command | Output | Signed with | Ads |
|---|---|---|---|
| `tools/build_android.sh [--bump]` | `build/arrowlock-<v>-b<code>-arm64-v8a.apk` | internal key (`~/.arrowlock/signing.env`) | Google **test** ads |
| `tools/build_android.sh --release <key folder or env file> [--bump] [--overwrite]` | `build/arrowlock-<v>-b<code>.aab` **and** `build/arrowlock-<v>-b<code>-arm64-v8a-upload.apk` | Play **upload key** | AAB: **real** ads. APK: **test** ads |

Every build is stamped with `data/build_info.json` (gitignored): its build number (shown in Settings → About) and whether it must use test ads. The ads service obeys the stamp, so APKs on your own phones never load real ads, whatever `data/ads.json` says.

**Signing (release).** Keystore `D:\Keys\Arrowlock\arrowlock-upload.jks`, alias `arrowlock-upload`. Pass the folder at build time. The script reads, in order:
1. `<folder>/upload.env` (or an env file passed directly) with three lines:
   ```
   GODOT_ANDROID_KEYSTORE_RELEASE_PATH="D:/Keys/Arrowlock/arrowlock-upload.jks"
   GODOT_ANDROID_KEYSTORE_RELEASE_USER="arrowlock-upload"
   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="..."
   ```
2. otherwise the single `*.jks` in the folder plus a hidden password prompt (needs a terminal).

The password never goes on a command line, into the repository, or into logs: export logs in `build/logs/` have it replaced with `<hidden>`. Nothing about the key is stored in Git or CI.

**What `--release` checks before it reports success** (any failure stops it):
1. All automated tests pass.
2. Export configuration: package `dev.imrn.arrowlock`, Gradle build, arm64-v8a, Vibrate, Play Games Game ID set, launcher icons set, both leaderboard ids, AdMob real app id and unit id.
3. Existing artifacts are not replaced unless `--overwrite` is given.
4. AAB manifest (read by `tools/aab_manifest.py`, no third-party tool): it is an app bundle, package, versionName and versionCode match, arm64-v8a native libs present, Play Games `APP_ID` and the real AdMob app id present, Game ID in the resources, build stamp says real ads.
5. AAB signature: `jarsigner -verify` passes and `keytool -printcert -jarfile` shows the upload key SHA-1 (`$UPLOAD_SHA1`, default above).
6. APK signature: `apksigner verify` passes with the same SHA-1, and the APK is stamped for test ads.
7. Prints each artifact's path, size and SHA-256.

To re-run only the checks on artifacts that already exist (no rebuild, no key): `tools/build_android.sh --verify`.

Godot 4.7 puts the game files (`res://`) of an AAB in an install-time asset pack, `assetPackInstallTime/assets/`, not in `base/assets/`; the checks look there.

Record the artifact names, version, commit and SHA-256 in `docs/changelog.md`.

**Installing on your phone.** An app signed with one key cannot be updated in place by one signed with another. Uninstall internal-key builds before installing the `-upload.apk`, and uninstall sideloaded builds before installing from Play (Play installs carry the Play App Signing key).

## 4. Device checks (Owner, physical phone)

Do these on a real phone with the release APK. Write the result of each line in the changelog.

- [ ] Clean install starts without a crash; the menu shows Easy mode, 0 / 300 stars, 100 coins.
- [ ] Level 1 tutorial shows; a blocked tap vibrates (Vibration on) and does not when switched off.
- [ ] Win a level, close the app from the recent-apps list, reopen: stars and coins kept.
- [ ] Press Home in the middle of a level and come back: the level is still there (Difficult: check the clock did not run out while away).
- [ ] Android back: from a level goes to the menu; from the menu closes the app.
- [ ] Profile screen (person button): stats right; "Sign in with Play Games" signs in; your Play Games name and picture replace the local profile; after a cleared level, the score (Profile → Score) appears on the leaderboard (can take a few minutes).
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
- [ ] Privacy policy URL. It must mention: Google Play Games sign-in (optional), the player ID and score sent to Google's leaderboard, **ads served by Google AdMob, which collects the advertising ID, device and usage data (Google's policy: https://policies.google.com/technologies/partner-sites)**, no analytics. AdMob also requires the policy URL.
- [ ] Data safety form: Play Games player ID and score (optional, app functionality). **AdMob: Device or other IDs (advertising ID), App interactions, Diagnostics, Approximate location (from IP); collected and shared with Google for advertising; encrypted in transit.** Check Google's own AdMob Data-safety guidance, since the form's wording changes.
- [ ] Ads declaration: **Yes, the app contains ads.**
- [ ] Advertising ID declaration (App content → Advertising ID): **Yes, used for advertising.** The ads SDK adds the `AD_ID` permission to the manifest.
- [ ] Content rating questionnaire: no violence, no user content, no purchases → expected Everyone / PEGI 3.
- [ ] Target audience: not designed for children under 13 unless you want the Families policy (it adds requirements).
- [ ] Target SDK meets the current Play requirement (Godot 4.7 export default; confirm in Play Console's warnings).
- [ ] No production release without your explicit approval (`instructions.md` §7).

## 6a. Ads (AdMob) (Owner)

The game shows an interstitial when the player leaves the win or game-over panel (Next, Retry, Replay or Menu) on level 11 or higher in either tier, at most once every 60 seconds. "+3 moves" never shows an ad. Settings are in `data/ads.json` (`first_level`, `min_seconds_between`, `enabled`). Plugin: `addons/AdmobPlugin` v7.0 (MIT, Google Mobile Ads 24.9.0).

The real ids are set (2026-11-08). Only the Play AAB serves real ads; every APK from `tools/build_android.sh` is stamped to use Google's test ad unit (§3). Never tap your own real ads; AdMob bans accounts for it.

1. https://admob.google.com → Apps → Add app → Android → "Is the app listed on a store?" No for now (link it after the Play listing exists). Name: Arrowlock.
2. Copy the **App ID** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`).
3. Ad units → Add ad unit → **Interstitial** → name "After game". Copy the **unit id** (`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`).
4. Privacy & messaging → GDPR → create a message for Arrowlock and publish it (needs the privacy policy URL). Without it, players in the EEA/UK get no consent form and **no ads**.
5. In the repo, all three must change together (a test fails if the two switches differ):
   - `addons/AdmobPlugin/android_export.cfg`: `is_real=true`, `[Release] app_id="<App ID>"`.
   - `data/ads.json`: `"use_real_ads": true`, `"interstitial_unit_id": "<unit id>"`.
6. Build, install, play to level 11 and finish a game. New ad units can take a few hours to serve; until then nothing shows (the game just carries on).
7. app-ads.txt: AdMob asks for one on the developer website listed on Play. Optional, but it improves fill.

Your own phones: sideloaded APKs already use test ads. A copy installed from Play serves real ads, so also register your phones in AdMob → Settings → Test devices before installing from the internal track.

## 7. After release: levels are frozen

`data/levels.lock.json` fingerprints every shipped level. The tests fail if a released level changes, because saved stars belong to a layout. To add content later, append new levels after level 100 and re-run `tools/freeze_levels.gd`; never regenerate or edit existing ones.
