#!/usr/bin/env bash
# Android builds for Arrowlock.
#
# Device-testing APK (unchanged workflow; internal key, Google's TEST ads):
#   tools/build_android.sh [--bump]
#   -> build/arrowlock-<version>-b<code>-arm64-v8a.apk
#
# Play release: signed AAB (REAL ads) + a matching device-testing APK (TEST ads),
# both signed with the Play upload key, then fully verified:
#   tools/build_android.sh --release <key folder or env file> [--bump] [--overwrite]
#   -> build/arrowlock-<version>-b<code>.aab
#   -> build/arrowlock-<version>-b<code>-arm64-v8a-upload.apk
#
#   <key folder> holds the upload keystore (*.jks). Credentials come from, in order:
#     1. an env file: the argument itself, or <key folder>/upload.env, defining
#        GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD;
#     2. otherwise the single *.jks in the folder, alias $UPLOAD_ALIAS
#        (default arrowlock-upload), and a hidden password prompt.
#   Passwords are never put on a command line, echoed or logged; export logs
#   are written with the password masked.
#
#   --bump       raise the version code by 1 first (Play rejects a reused code).
#   --overwrite  allow replacing existing release artifacts (refused otherwise).
#
# Re-check existing release artifacts without rebuilding (no key needed):
#   tools/build_android.sh --verify
#
# Version name: project.godot (application/config/version).
# Version code: export_presets.cfg (version/code; gitignored, docs/release.md §2).
# Expected upload certificate SHA-1: $UPLOAD_SHA1 (default below).
set -euo pipefail
cd "$(dirname "$0")/.."

PRESETS=export_presets.cfg
UPLOAD_SHA1="${UPLOAD_SHA1:-57:AC:89:CF:26:6A:D1:8D:16:07:ED:4E:EA:C4:34:9C:41:50:08:75}"
UPLOAD_ALIAS="${UPLOAD_ALIAS:-arrowlock-upload}"
PACKAGE="dev.imrn.arrowlock"
BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-$(ls -d "${LOCALAPPDATA:-$HOME}"/Android/Sdk/build-tools/* 2>/dev/null | sort -V | tail -1)}"

release=""
bump=0
overwrite=0
verify=0
while [ $# -gt 0 ]; do
	case "$1" in
		--bump) bump=1 ;;
		--overwrite) overwrite=1 ;;
		--verify) verify=1 ;;
		--release) shift; release="${1:-}"; [ -n "$release" ] || { echo "--release needs the key folder or env file" >&2; exit 2; } ;;
		*) echo "Unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done

fail() { echo "FAILED: $*" >&2; exit 1; }
# Replaces the keystore password with <hidden> without passing it as an argument.
mask() { awk 'BEGIN { p = ENVIRON["GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"] }
	{ if (p != "") { while ((i = index($0, p)) > 0) $0 = substr($0, 1, i - 1) "<hidden>" substr($0, i + length(p)) } print }'; }
preset() { sed -n "s/^$1=\(.*\)$/\1/p" "$PRESETS" | head -1 | tr -d '"'; }

[ -f "$PRESETS" ] || fail "missing $PRESETS (see docs/release.md §2)"

# --- credentials -------------------------------------------------------------
if [ $verify -eq 1 ]; then
	[ -z "$release" ] && [ $bump -eq 0 ] || fail "--verify takes no other options"
elif [ -z "$release" ]; then
	SIGNING="$HOME/.arrowlock/signing.env"
	[ -f "$SIGNING" ] || fail "missing $SIGNING"
	# shellcheck disable=SC1090
	source "$SIGNING"
else
	envfile=""
	if [ -f "$release" ]; then envfile="$release"; elif [ -f "$release/upload.env" ]; then envfile="$release/upload.env"; fi
	if [ -n "$envfile" ]; then
		# shellcheck disable=SC1090
		source "$envfile"
	else
		[ -d "$release" ] || fail "$release is neither a folder nor an env file"
		shopt -s nullglob; jks=("$release"/*.jks); shopt -u nullglob
		[ ${#jks[@]} -eq 1 ] || fail "expected exactly one .jks in $release (found ${#jks[@]})"
		[ -t 0 ] || fail "no upload.env in $release and no terminal to ask for the password"
		GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${jks[0]}"
		GODOT_ANDROID_KEYSTORE_RELEASE_USER="$UPLOAD_ALIAS"
		read -rsp "Password for $UPLOAD_ALIAS in ${jks[0]}: " GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; echo
	fi
fi
if [ $verify -eq 0 ]; then
	export GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
	[ -f "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] || fail "keystore not found: ${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-<unset>}"
	[ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-}" ] && [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-}" ] || fail "keystore alias or password not set"
fi

# --- version -----------------------------------------------------------------
code=$(preset "version\/code")
if [ $bump -eq 1 ]; then
	code=$((code + 1))
	sed -i "s/^version\/code=[0-9]*$/version\/code=$code/" "$PRESETS"
fi
version=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
commit="$(git rev-parse --short HEAD)$(git diff --quiet HEAD -- . ':!data/build_info.json' || echo '+uncommitted')"

# --- tests -------------------------------------------------------------------
if [ $verify -eq 0 ]; then
	echo "Testing..."
	godot --headless --path . -s tests/run_tests.gd 2>&1 | tail -1 | tee /dev/stderr | grep -q " 0 failed" \
		|| fail "tests failed; not building"
fi

# Writes data/build_info.json (gitignored): build number for About, ads mode.
stamp() { printf '{"build": %s, "commit": "%s", "test_ads": %s}\n' "$code" "$(git rev-parse --short HEAD)" "$1" > data/build_info.json; }

# Exports with the preset's format set to $1 (0 = APK, 1 = AAB; Godot 4.7.2,
# verified by the bundle check below), restoring the preset afterwards.
original_format=$(preset "gradle_build\/export_format")
set_format() { sed -i "s/^gradle_build\/export_format=.*/gradle_build\/export_format=$1/" "$PRESETS"; }
trap 'set_format "$original_format"' EXIT
export_as() {
	local format=$1 out=$2 log=$3
	set_format "$format"
	mkdir -p build/logs
	godot --headless --path . --export-release Android "$out" 2>&1 | mask > "$log" || true
	if grep -qE "ERROR" "$log"; then grep -E "ERROR" "$log" | head -20 >&2; fail "export of $out reported errors (log: $log)"; fi
	[ -f "$out" ] || fail "export produced no file: $out"
}

if [ -z "$release" ] && [ $verify -eq 0 ]; then
	out="build/arrowlock-$version-b$code-arm64-v8a.apk"
	stamp true
	echo "Building $out (test ads) ..."
	export_as 0 "$out" build/logs/export-apk.log
	echo "Built $out (version $version, build $code, commit $commit)"
	exit 0
fi

# --- release: validate configuration -------------------------------------------
echo "Checking release configuration..."
[ "$(preset "package\/unique_name")" = "$PACKAGE" ] || fail "package/unique_name is not $PACKAGE"
[ "$(preset "gradle_build\/use_gradle_build")" = "true" ] || fail "Gradle build is off"
[ "$(preset "architectures\/arm64-v8a")" = "true" ] || fail "arm64-v8a is off"
[ "$(preset "permissions\/vibrate")" = "true" ] || fail "Vibrate permission is off"
game_id=$(preset "godot_play_game_services\/game_id")
[[ "$game_id" =~ ^[0-9]{12}$ && "$game_id" != "000000000000" ]] || fail "Play Games game_id is not set"
for icon in main_192x192 adaptive_foreground_432x432 adaptive_background_432x432; do
	[ -n "$(preset "launcher_icons\/$icon")" ] || fail "launcher icon $icon is not set"
done
python -I - <<'PY' || fail "data config check"
import json, configparser
pg = json.load(open("data/play_games.json", encoding="utf-8"))["leaderboards"]
assert all(pg.get(k, "").startswith("CgkI") for k in ("score_easy", "score_difficult")), "leaderboard ids missing"
ads = json.load(open("data/ads.json", encoding="utf-8"))
assert ads.get("use_real_ads") is True and ads.get("interstitial_unit_id", "").startswith("ca-app-pub-"), "ads.json is not set to the real ad unit"
cfg = open("addons/AdmobPlugin/android_export.cfg", encoding="utf-8").read()
assert "is_real=true" in cfg and "ca-app-pub-" in cfg.split("[Release]")[1], "AdMob export config is not real"
PY

aab="build/arrowlock-$version-b$code.aab"
apk="build/arrowlock-$version-b$code-arm64-v8a-upload.apk"
if [ $verify -eq 1 ]; then
	for f in "$aab" "$apk"; do [ -f "$f" ] || fail "nothing to verify: $f does not exist"; done
	commit="not rebuilt; stamped from commit $(unzip -p "$apk" assets/data/build_info.json | sed -n 's/.*"commit": "\([^"]*\)".*/\1/p')"
else
	if [ $overwrite -eq 0 ]; then
		for f in "$aab" "$apk"; do [ ! -e "$f" ] || fail "$f already exists (check it, then rerun with --overwrite)"; done
	fi
	echo "Building $aab (real ads) ..."
	stamp false
	export_as 1 "$aab" build/logs/export-aab.log
	echo "Building $apk (test ads) ..."
	stamp true
	export_as 0 "$apk" build/logs/export-apk-upload.log
fi
mkdir -p build/logs

# --- release: verify -----------------------------------------------------------
echo "Verifying..."
python -I tools/aab_manifest.py "$aab" > build/logs/aab-manifest.json
python -I - "$aab" "$PACKAGE" "$code" "$version" "$game_id" <<'PY' || fail "AAB manifest check"
import json, sys, zipfile
aab, package, code, version, game_id = sys.argv[1:]
m = json.load(open("build/logs/aab-manifest.json", encoding="utf-8"))
assert m["is_bundle"], "not an Android App Bundle"
assert m["package"] == package, f"package {m['package']}"
assert m["versionCode"] == code, f"versionCode {m['versionCode']}"
assert m["versionName"] == version, f"versionName {m['versionName']}"
assert "arm64-v8a" in m["abis"], f"abis {m['abis']}"
assert "com.google.android.gms.games.APP_ID" in m["meta"], "Play Games APP_ID meta-data missing"
assert m["meta"].get("com.google.android.gms.ads.APPLICATION_ID", "").startswith("ca-app-pub-1106747567696734~"), "AdMob app id is not the real one"
with zipfile.ZipFile(aab) as z:
    assert game_id.encode() in z.read("base/resources.pb"), "game_services_project_id is not the configured Game ID"
    # Godot 4.7 puts game files in an install-time asset pack, not in base/.
    stamps = [n for n in ("assetPackInstallTime/assets/data/build_info.json", "base/assets/data/build_info.json") if n in z.namelist()]
    assert stamps, "build stamp data/build_info.json not found in the bundle"
    info = json.loads(z.read(stamps[0]))
    assert info.get("test_ads") is False and info.get("build") == int(code), f"build stamp {info}"
print(f"  package {m['package']}, version {m['versionName']} ({m['versionCode']}), abis {', '.join(m['abis'])}")
print(f"  permissions: {', '.join(p.split('.')[-1] for p in m['permissions'])}")
PY

jarsigner -verify "$aab" | grep -q "jar verified" || fail "AAB signature does not verify"
aab_sha1=$(keytool -printcert -jarfile "$aab" | sed -n 's/^[[:space:]]*SHA1: //p' | head -1)
[ "$aab_sha1" = "$UPLOAD_SHA1" ] || fail "AAB is signed with $aab_sha1, expected upload key $UPLOAD_SHA1"
echo "  AAB signature verified; certificate SHA-1 $aab_sha1 (upload key)"

"$BUILD_TOOLS/apksigner.bat" verify "$apk" >/dev/null 2>&1 || "$BUILD_TOOLS/apksigner" verify "$apk" >/dev/null 2>&1 || fail "APK signature does not verify"
apk_sha1=$("$BUILD_TOOLS/apksigner.bat" verify --print-certs "$apk" 2>/dev/null | sed -n 's/.*certificate SHA-1 digest: //p' | head -1 | tr 'a-f' 'A-F' | sed 's/../&:/g; s/:$//')
[ "$apk_sha1" = "$UPLOAD_SHA1" ] || fail "APK is signed with $apk_sha1, expected $UPLOAD_SHA1"
unzip -p "$apk" assets/data/build_info.json | grep -q '"test_ads": true' || fail "APK is not a test-ads build"
echo "  APK signature verified; same upload key; test ads"

echo
echo "Release build OK (version $version, build $code, commit $commit)"
for f in "$aab" "$apk"; do
	printf '  %s  %s bytes  sha256 %s\n' "$f" "$(stat -c %s "$f")" "$(sha256sum "$f" | cut -d' ' -f1)"
done
