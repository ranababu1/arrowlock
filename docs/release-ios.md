# iOS Release Guide

How to turn `main` into a build on TestFlight and then the App Store. Steps marked **Owner** need your Apple account, an iPhone or a decision, so an agent cannot do them. Everything else is in the repository. The Android guide is `release.md`.

Status (2026-11-13): the code, the export and the build script are in place. No iOS build has been signed, installed or uploaded. See "What has been checked" at the end.

## What is different from Android

- **No online leaderboard and no sign-in.** Play Games is Android-only. On iOS the Profile screen shows the local name and avatar, stats and badges; the leaderboard card and every mention of Google are hidden (the App Store rejects references to other platforms). Scores are still kept on the phone. A Game Center leaderboard would be a new feature and needs your approval.
- **Ads are a separate AdMob app.** iOS has its own AdMob app id and ad unit id (§6). Until they are set, the iOS build shows no ads and `--release` refuses to build.
- **No tracking prompt.** App Tracking Transparency is off, so ads are served without the advertising identifier (lower revenue, no permission dialog). Turning it on is a decision for you (§6).
- **iPhone only.** The preset targets iPhone; iPads run it in iPhone compatibility mode, and no iPad screenshots are needed.
- **Vibration.** iPhones ignore the requested length, so the blocked-tap, win and loss buzzes feel the same.
- **Version name `0.3.0`** comes from `project.godot`, shared with Android. The iOS build number is separate and starts at 1.

## 1. One-time setup (Owner)

Apple:
1. Join the Apple Developer Program (99 USD a year) and note your **Team ID** (developer.apple.com → Membership details; 10 letters and digits).
2. developer.apple.com → Identifiers → add an App ID with bundle id **`dev.imrn.arrowlock`**. No capabilities are needed.
3. App Store Connect → Apps → New App: iOS, name "Arrowlock", primary language English, that bundle id, any SKU (for example `arrowlock`).

This Mac:
1. **Xcode 26 or later** from the App Store, then open it once and install the iOS platform when it asks. Xcode 16 cannot build the game: Godot 4.7's iOS libraries need the iOS 26 SDK, and the App Store only accepts builds from Xcode 26 or later. Xcode → Settings → Accounts → add your Apple ID.
2. Godot 4.7.2 with its export templates (installed on this Mac on 2026-11-13: `~/Library/Application Support/Godot/export_templates/4.7.2.stable`).
3. `gem install --user-install xcodeproj` (installed on this Mac on 2026-11-13). The ads plugin uses it to add Google's SDK to the Xcode project.

## 2. Export preset (Owner, once per Mac)

`export_presets.cfg` is gitignored. A working one, with an iOS preset only, was left on this Mac on 2026-11-13; the one thing to fill in is the Team ID. To recreate it, save this as `export_presets.cfg` in the project folder (if the file already holds the Android preset, add this as the next preset number instead):

```
[preset.0]

name="iOS"
platform="iOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter="build/*"
export_path="build/ios/Arrowlock.xcodeproj"
script_export_mode=2

[preset.0.options]

application/app_store_team_id=""
application/export_project_only=true
application/bundle_identifier="dev.imrn.arrowlock"
application/short_version=""
application/version="1"
application/min_ios_version="14.3"
application/targeted_device_family=0
application/export_method_release=0
application/additional_plist_content="<key>ITSAppUsesNonExemptEncryption</key>
<false/>"
icons/icon_1024x1024="res://assets/icon/ios_1024.png"
plugins/AdmobPlugin=true
```

| Setting | Why |
|---|---|
| `application/app_store_team_id` | **Your Team ID.** Godot refuses to export without one. |
| `application/version` | The build number (a whole number). `--bump` raises it. |
| `application/short_version` | Leave empty: the version name comes from `project.godot`. |
| `application/export_project_only=true` | Godot only writes the Xcode project; the build script runs Xcode. |
| `plugins/AdmobPlugin=true` | Without it the ads plugin is left out of the app and no ad ever shows. |
| `exclude_filter="build/*"`, `include_filter="*.json"` | Keeps build output out of the game; keeps levels and config in. |
| `ITSAppUsesNonExemptEncryption` false | The game has no encryption of its own, so App Store Connect does not ask on every upload. |
| `icons/icon_1024x1024` | The App Store icon (no transparency). Regenerate with `python -I tools/make_icon.py`. |
| `application/targeted_device_family=0` | iPhone only. |

## 3. Build and check

Both workflows are in `tools/build_ios.sh`:

| Command | Output | Ads |
|---|---|---|
| `tools/build_ios.sh [--bump]` | `build/ios/Arrowlock.xcodeproj` | Google **test** ads |
| `tools/build_ios.sh --release [--bump] [--overwrite]` | `build/arrowlock-<v>-b<n>.xcarchive` and `build/arrowlock-<v>-b<n>.ipa` | **Real** ads |
| `tools/build_ios.sh --verify` | re-checks an existing archive and .ipa | |

**Your own iPhone:** run the first command, open `build/ios/Arrowlock.xcodeproj` in Xcode, choose your iPhone at the top and press Run. The first time, the phone asks you to trust the developer (Settings → General → VPN & Device Management). These builds are stamped to use Google's test ad unit, whatever `data/ads.json` says.

**Signing:** Xcode's automatic signing for the Team ID in the preset. Xcode creates the certificate and profile itself (`-allowProvisioningUpdates`). The script reads no certificate, profile or password.

**What `--release` checks before it reports success** (any failure stops it):
1. All automated tests pass.
2. Preset: bundle id, a real Team ID, ads plugin on, icon set, encryption key present.
3. Real iOS ads are configured: `ios_export.cfg` `is_real=true` with the iOS app id, `data/ads.json` with `use_real_ads` and an `ios_interstitial_unit_id` that is not the Android one.
4. Xcode is 26 or later.
5. The exported project contains the ads plugin and Google's SDK, and the export log has no errors.
6. The archived app and the app inside the .ipa: bundle id, version, build number, the real AdMob app id, `ITSAppUsesNonExemptEncryption` false, `SKAdNetworkItems`, the tracking text present only when ATT is on, the privacy manifest, the build stamp (this build number, real ads), a valid code signature for your team; the .ipa signed with an Apple Distribution certificate.
7. Prints the .ipa path, size and SHA-256. Nothing is uploaded.

Record the artifact name, version, build, commit and SHA-256 in `docs/changelog.md`.

## 4. Device checks (Owner, physical iPhone)

Write the result of each line in the changelog.

- [ ] Clean install starts without a crash; the menu shows Easy mode, 0 / 300 stars, 100 coins.
- [ ] Level 1 tutorial shows; a blocked tap vibrates (Vibration on) and does not when switched off.
- [ ] Win a level, swipe the app away in the app switcher, reopen: stars and coins kept.
- [ ] Go to the Home screen in the middle of a level and come back: the level is still there (Difficult: check the clock did not run out while away).
- [ ] Profile screen: no leaderboard card, no sign-in button, no mention of Google; name and avatar can be edited and are kept.
- [ ] Notch / Dynamic Island phone: nothing hidden under the island or the home bar.
- [ ] Play to level 11 and finish three rounds over three minutes: a test ad appears when leaving the result panel, and the game carries on after it closes.
- [ ] Sound: music and effects play; the silent switch behaves as you expect.
- [ ] **Upgrade test** (from the second build on): install the previous build, clear 2 levels, install the new one over it. Progress must still be there.

## 5. TestFlight and upload (Owner)

1. Upload `build/arrowlock-<v>-b<n>.ipa` with the **Transporter** app (Mac App Store), or Xcode → Window → Organizer → Distribute App.
2. App Store Connect → TestFlight: the build appears after processing (10 to 30 minutes). Add yourself as an internal tester and install it through the TestFlight app. A build installed from TestFlight serves **real** ads: register your iPhone in AdMob → Settings → Test devices first, and never tap your own ads.
3. No submission for review without your explicit approval (`instructions.md` §7).

## 6. Ads (AdMob) (Owner)

1. https://admob.google.com → Apps → Add app → **iOS** → not listed yet. Name: Arrowlock. Copy the **App ID** (`ca-app-pub-…~…`).
2. Ad units → Add ad unit → **Interstitial** → "After game". Copy the **unit id** (`ca-app-pub-…/…`).
3. Privacy & messaging → GDPR: make sure the message covers the iOS app too. Without it, players in the EEA/UK get no ads.
4. In the repo, both must change together (a test fails otherwise):
   - `addons/AdmobPlugin/ios_export.cfg`: `is_real=true`, `[Release] app_id="<iOS App ID>"`.
   - `data/ads.json`: `"ios_interstitial_unit_id": "<iOS unit id>"`.
5. The ad rules are the same as on Android (`release.md` §6a).

**Tracking prompt (optional).** With ATT off the game never asks "Allow Arrowlock to track your activity?" and ads are not personalised by device. To turn it on: `ios_export.cfg` `[ATT] att_enabled=true` with an `att_text`, a call to `request_tracking_authorization()` in `scripts/services/ads.gd` before the SDK starts, and "Used to track you" answers in the App Privacy form. Do not create an "IDFA explainer" message in AdMob while ATT is off: it would try to show the system prompt without the text Apple requires.

The plugin adds `NSAllowsArbitraryLoads` to Info.plist, as Google's setup guide asks. If App Review questions it, the answer is "required by the Google Mobile Ads SDK".

## 7. App Store listing checklist (Owner, before submitting for review)

- [ ] Name, subtitle, description, keywords, support URL, category Games → Puzzle.
- [ ] Screenshots: iPhone 6.9" (1320 x 2868 or 1290 x 2796), at least one. No Android status bars or Google Play wording in them.
- [ ] **Privacy policy URL** (required). The Android text needs an iOS paragraph: ads by Google AdMob; no sign-in and no leaderboard on iOS.
- [ ] **App Privacy** form, for AdMob without ATT: Identifiers → Device ID; Usage Data → Advertising data and Product interaction; Location → Coarse location; Diagnostics → Crash and Performance data. Purpose: Third-party advertising (and Analytics where Google's guide says so). Linked to the user: no. Used for tracking: no. Check Google's current "Apple privacy details" page for AdMob, since its list changes.
- [ ] Age rating questionnaire: no violence, no user content, no purchases; **contains ads**. Expected 4+.
- [ ] Pricing: Free. Availability: your choice of countries.
- [ ] App Review notes: no account is needed; ads appear from level 11.
- [ ] Export compliance: answered by `ITSAppUsesNonExemptEncryption` false in the build.
- [ ] Content rights: the game uses the Poppins font (OFL) and its own art and audio.

## What has been checked (2026-11-13, this Mac: macOS 15, Godot 4.7.2, Xcode 16.4)

- `tools/build_ios.sh` (device build): tests pass, the Xcode project is exported with no errors, with the ads plugin, Google Mobile Ads 12.14.0 (Swift package), the 1024 icon, the launch screen, Godot's privacy manifest and a test-ads build stamp.
- Compiling that project with Xcode 16.4, unsigned: all sources and Google's SDK compile; linking stops only on five iOS 26 SDK symbols (`CADynamicRange…`, `MTLTensorDomain`) that Godot 4.7 needs. That is the Xcode 26 requirement, not a project fault.
- `--release` stops correctly at each missing item: Team ID, iOS ad ids, Xcode version.
- **Not run:** archive, signing, .ipa export and the checks on them (they need Xcode 26, your Team ID and the iOS ad ids); any run on an iPhone or simulator.
