#!/usr/bin/env bash
# iOS builds for Arrowlock. Runs on a Mac only (docs/release-ios.md).
#
# Device-testing build (Google's TEST ads): makes the Xcode project, which you
# then run on your own iPhone from Xcode:
#   tools/build_ios.sh [--bump]
#   -> build/ios/Arrowlock.xcodeproj
#
# App Store release (REAL ads): archives, signs and exports an .ipa, then
# verifies it. Nothing is uploaded:
#   tools/build_ios.sh --release [--bump] [--overwrite]
#   -> build/arrowlock-<version>-b<build>.xcarchive
#   -> build/arrowlock-<version>-b<build>.ipa
#
#   Signing is Xcode's automatic signing for the Team ID in the export preset.
#   Xcode must be signed in to that Apple Developer account (Xcode > Settings >
#   Accounts). No certificate, profile or password is read, stored or logged here.
#
#   --bump       raise the build number by 1 first (App Store Connect rejects a
#                build number it has already received for the same version).
#   --overwrite  allow replacing existing release artifacts (refused otherwise).
#
# Re-check an existing release archive and .ipa without rebuilding:
#   tools/build_ios.sh --verify
#
# Version name: project.godot (application/config/version).
# Build number: export_presets.cfg, iOS preset, application/version (gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."

PRESETS=export_presets.cfg
BUNDLE_ID="dev.imrn.arrowlock"
SCHEME="Arrowlock"
PROJECT_DIR=build/ios
PROJECT="$PROJECT_DIR/$SCHEME.xcodeproj"
IOS_CFG=addons/AdmobPlugin/ios_export.cfg
# Godot 4.7 iOS templates use iOS 26 SDK symbols, and the App Store accepts only
# builds made with Xcode 26 or later.
MIN_XCODE_MAJOR=26

release=0
bump=0
overwrite=0
verify=0
while [ $# -gt 0 ]; do
	case "$1" in
		--bump) bump=1 ;;
		--overwrite) overwrite=1 ;;
		--verify) verify=1 ;;
		--release) release=1 ;;
		*) echo "Unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done

fail() { echo "FAILED: $*" >&2; exit 1; }
[ "$(uname)" = "Darwin" ] || fail "iOS builds need a Mac"
[ -f "$PRESETS" ] || fail "missing $PRESETS (see docs/release-ios.md §2)"
if [ $verify -eq 1 ]; then
	[ $release -eq 0 ] && [ $bump -eq 0 ] && [ $overwrite -eq 0 ] || fail "--verify takes no other options"
fi

# --- the iOS preset ------------------------------------------------------------
# The options of the preset whose platform is iOS, one "key=value" per line.
ios_options() {
	awk '
		/^\[preset\.[0-9]+\]$/ { id = $0; sub(/^\[preset\./, "", id); sub(/\]$/, "", id); in_options = 0; next }
		/^\[preset\.[0-9]+\.options\]$/ { in_options = ($0 == "[preset." ios ".options]"); next }
		/^platform="iOS"$/ { ios = id }
		in_options { print }
	' "$PRESETS"
}
preset() { ios_options | sed -n "s|^$1=\(.*\)$|\1|p" | head -1 | tr -d '"'; }
ios_options | grep -q . || fail "$PRESETS has no iOS preset (see docs/release-ios.md §2)"

cfg_value() { awk -v section="[$1]" -v key="$2" '
	/^\[/ { in_section = ($0 == section) }
	in_section && index($0, key "=") == 1 { value = substr($0, length(key) + 2); gsub(/"/, "", value); print value; exit }' "$IOS_CFG"; }

# --- version -------------------------------------------------------------------
build=$(preset "application/version")
[[ "$build" =~ ^[0-9]+$ ]] || fail "iOS preset application/version (the build number) must be a whole number, found '$build'"
if [ $bump -eq 1 ]; then
	build=$((build + 1))
	sed -i '' "s|^application/version=\"[0-9]*\"$|application/version=\"$build\"|" "$PRESETS"
	[ "$(preset "application/version")" = "$build" ] || fail "could not write the new build number to $PRESETS"
fi
version=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
short_version=$(preset "application/short_version")
[ -z "$short_version" ] || [ "$short_version" = "$version" ] || fail "iOS preset application/short_version is '$short_version'; leave it empty so project.godot ($version) is the only version name"
commit="$(git rev-parse --short HEAD)$(git diff --quiet HEAD -- . ':!data/build_info.json' || echo '+uncommitted')"

archive="build/arrowlock-$version-b$build.xcarchive"
ipa="build/arrowlock-$version-b$build.ipa"

# --- configuration checks --------------------------------------------------------
check_common() {
	[ "$(preset "application/bundle_identifier")" = "$BUNDLE_ID" ] || fail "application/bundle_identifier is not $BUNDLE_ID"
	[ "$(preset "plugins/AdmobPlugin")" = "true" ] || fail "plugins/AdmobPlugin is not on in the iOS preset: the ads plugin would be left out of the app"
	[ -n "$(preset "icons/icon_1024x1024")" ] || fail "icons/icon_1024x1024 is not set"
	[ "$(preset "application/export_project_only")" = "true" ] || fail "application/export_project_only must be true (this script runs Xcode itself)"
	[ -f ios/plugins/AdmobPlugin.gdip ] || fail "ios/plugins/AdmobPlugin.gdip is missing"
}
check_release_config() {
	team=$(preset "application/app_store_team_id")
	[[ "$team" =~ ^[A-Z0-9]{10}$ && "$team" != "0000000000" ]] || fail "application/app_store_team_id is not your Apple Team ID (10 letters and digits)"
	grep -q "ITSAppUsesNonExemptEncryption" "$PRESETS" || fail "application/additional_plist_content lacks ITSAppUsesNonExemptEncryption"
	[ "$(cfg_value General is_real)" = "true" ] || fail "$IOS_CFG is_real is not true (no real iOS ads configured; docs/release-ios.md §6)"
	ios_app_id=$(cfg_value Release app_id)
	[[ "$ios_app_id" =~ ^ca-app-pub-[0-9]+~[0-9]+$ ]] || fail "$IOS_CFG [Release] app_id is not an AdMob app id"
	att_enabled=$(cfg_value ATT att_enabled)
	python3 -I - <<'PY' || fail "data/ads.json check"
import json
ads = json.load(open("data/ads.json", encoding="utf-8"))
assert ads.get("use_real_ads") is True, "use_real_ads is not true"
unit = ads.get("ios_interstitial_unit_id", "")
assert unit.startswith("ca-app-pub-") and "/" in unit, "ios_interstitial_unit_id is not set"
assert unit != ads.get("interstitial_unit_id"), "ios_interstitial_unit_id is a copy of the Android unit id"
PY
}
check_tools() {
	command -v godot >/dev/null || fail "godot is not on the PATH"
	command -v xcodebuild >/dev/null || fail "Xcode is not installed"
	ruby -rxcodeproj -e 1 2>/dev/null || fail "the Ruby gem 'xcodeproj' is missing (the ads plugin needs it to add Google's SDK): gem install --user-install xcodeproj"
}
check_xcode_version() {
	local major
	major=$(xcodebuild -version | sed -n 's/^Xcode \([0-9]*\).*/\1/p')
	[ "${major:-0}" -ge $MIN_XCODE_MAJOR ] || fail "Xcode $MIN_XCODE_MAJOR or later is needed (found $(xcodebuild -version | head -1)): Godot 4.7 does not link with an older iOS SDK and the App Store refuses the build"
}

# Writes data/build_info.json (gitignored): build number for About, ads mode.
stamp() { printf '{"build": %s, "commit": "%s", "test_ads": %s}\n' "$build" "$(git rev-parse --short HEAD)" "$1" > data/build_info.json; }

# Exports the Xcode project. Godot scans everything under res://, so build/ is
# marked as not part of the game, otherwise old build output ends up in the app.
export_project() {
	mkdir -p build/logs
	touch build/.gdignore
	rm -rf "$PROJECT_DIR"
	mkdir -p "$PROJECT_DIR"
	godot --headless --path . --export-release iOS "$PROJECT" > build/logs/export-ios.log 2>&1 || true
	if grep -qE "ERROR" build/logs/export-ios.log; then
		grep -E "ERROR" build/logs/export-ios.log | head -20 >&2
		fail "the export reported errors (log: build/logs/export-ios.log)"
	fi
	[ -d "$PROJECT" ] || fail "the export produced no Xcode project (log: build/logs/export-ios.log)"
	grep -q "AdmobPlugin.xcframework" "$PROJECT/project.pbxproj" || fail "the ads plugin is not in the Xcode project"
	grep -q "GoogleMobileAds" "$PROJECT/project.pbxproj" || fail "Google's ads SDK was not added to the Xcode project (log: build/logs/export-ios.log)"
}

if [ $verify -eq 0 ]; then
	check_tools
	check_common
	echo "Testing..."
	godot --headless --path . -s tests/run_tests.gd 2>&1 | tail -1 | tee /dev/stderr | grep -q " 0 failed" \
		|| fail "tests failed; not building"
fi

# --- device-testing build --------------------------------------------------------
if [ $release -eq 0 ] && [ $verify -eq 0 ]; then
	stamp true
	echo "Exporting $PROJECT (test ads) ..."
	export_project
	echo "Exported $PROJECT (version $version, build $build, commit $commit, test ads)"
	echo "Next: open it in Xcode, pick your iPhone and press Run (docs/release-ios.md §3)."
	exit 0
fi

# --- release: build ----------------------------------------------------------------
echo "Checking release configuration..."
check_common
check_release_config
if [ $verify -eq 1 ]; then
	for f in "$archive" "$ipa"; do [ -e "$f" ] || fail "nothing to verify: $f does not exist"; done
else
	check_xcode_version
	if [ $overwrite -eq 0 ]; then
		for f in "$archive" "$ipa"; do [ ! -e "$f" ] || fail "$f already exists (check it, then rerun with --overwrite)"; done
	fi
	stamp false
	echo "Exporting $PROJECT (real ads) ..."
	export_project

	echo "Archiving (this takes a few minutes) ..."
	rm -rf "$archive"
	xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
		-destination "generic/platform=iOS" -archivePath "$archive" \
		-allowProvisioningUpdates archive > build/logs/xcodebuild-archive.log 2>&1 \
		|| { grep -E "error:" build/logs/xcodebuild-archive.log | sort -u | head -20 >&2; fail "archive failed (log: build/logs/xcodebuild-archive.log)"; }

	echo "Exporting the .ipa ..."
	options=build/logs/ios-export-options.plist
	cat > "$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST
	rm -rf build/ios-ipa
	xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" \
		-exportPath build/ios-ipa -allowProvisioningUpdates > build/logs/xcodebuild-export.log 2>&1 \
		|| { grep -E "error:" build/logs/xcodebuild-export.log | sort -u | head -20 >&2; fail ".ipa export failed (log: build/logs/xcodebuild-export.log)"; }
	shopt -s nullglob; made=(build/ios-ipa/*.ipa); shopt -u nullglob
	[ ${#made[@]} -eq 1 ] || fail "expected one .ipa in build/ios-ipa, found ${#made[@]}"
	mv -f "${made[0]}" "$ipa"
	rm -rf build/ios-ipa
fi

# --- release: verify ---------------------------------------------------------------
# Checks one .app folder: identity, version, ads, plist keys, build stamp, signature.
verify_app() {
	local app=$1 label=$2 plist="$1/Info.plist"
	[ -f "$plist" ] || fail "$label: no Info.plist in $app"
	pl() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist" 2>/dev/null || true; }
	[ "$(pl CFBundleIdentifier)" = "$BUNDLE_ID" ] || fail "$label: bundle id is $(pl CFBundleIdentifier)"
	[ "$(pl CFBundleShortVersionString)" = "$version" ] || fail "$label: version is $(pl CFBundleShortVersionString), expected $version"
	[ "$(pl CFBundleVersion)" = "$build" ] || fail "$label: build is $(pl CFBundleVersion), expected $build"
	[ "$(pl GADApplicationIdentifier)" = "$ios_app_id" ] || fail "$label: AdMob app id is '$(pl GADApplicationIdentifier)', expected the real one"
	[ "$(pl ITSAppUsesNonExemptEncryption)" = "false" ] || fail "$label: ITSAppUsesNonExemptEncryption is not false"
	[ -n "$(pl SKAdNetworkItems:0:SKAdNetworkIdentifier)" ] || fail "$label: SKAdNetworkItems missing"
	local tracking; tracking=$(pl NSUserTrackingUsageDescription)
	if [ "$att_enabled" = "true" ]; then
		[ -n "$tracking" ] || fail "$label: ATT is on but NSUserTrackingUsageDescription is missing"
	else
		[ -z "$tracking" ] || fail "$label: NSUserTrackingUsageDescription is present although ATT is off"
	fi
	[ -f "$app/PrivacyInfo.xcprivacy" ] || fail "$label: PrivacyInfo.xcprivacy missing"
	[ -f "$app/$SCHEME.pck" ] || fail "$label: game data $SCHEME.pck missing"
	# The .pck stores small files as plain text, so the stamp can be read in place.
	grep -a -q "\"build\": $build, \"commit\": \"[0-9a-f]*\", \"test_ads\": false" "$app/$SCHEME.pck" \
		|| fail "$label: the build stamp for build $build with real ads is not in the game data"
	codesign --verify --deep --strict "$app" 2>/dev/null || fail "$label: code signature does not verify"
	local signed_team; signed_team=$(codesign -dv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')
	[ "$signed_team" = "$team" ] || fail "$label: signed for team '$signed_team', expected $team"
	echo "  $label: $BUNDLE_ID $version ($build), real ads, signed by $(codesign -dv --verbose=2 "$app" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
}

echo "Verifying..."
verify_app "$archive/Products/Applications/$SCHEME.app" "archive"
unpacked=$(mktemp -d)
trap 'rm -rf "$unpacked"' EXIT
unzip -q "$ipa" -d "$unpacked"
verify_app "$unpacked/Payload/$SCHEME.app" ".ipa"
codesign -dv --verbose=2 "$unpacked/Payload/$SCHEME.app" 2>&1 | grep -q "^Authority=Apple Distribution" \
	|| fail ".ipa is not signed with an Apple Distribution certificate"

if [ $verify -eq 1 ]; then commit="not rebuilt"; fi
echo
echo "iOS release build OK (version $version, build $build, commit $commit). Not uploaded."
printf '  %s\n' "$archive"
printf '  %s  %s bytes  sha256 %s\n' "$ipa" "$(stat -f %z "$ipa")" "$(shasum -a 256 "$ipa" | cut -d' ' -f1)"
echo "Next: upload the .ipa with the Transporter app or Xcode's Organizer (docs/release-ios.md §5)."
