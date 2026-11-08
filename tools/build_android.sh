#!/usr/bin/env bash
# Builds a signed release APK named after its version and build number:
#   build/arrowlock-<version>-b<code>-arm64-v8a.apk
#
# Usage: tools/build_android.sh [--bump]
#   --bump  raise the build number (version code) by 1 before building.
#           Do this for every build you install or upload: Android refuses to
#           install a lower code over a higher one, and Play rejects reused codes.
#
# Version name comes from project.godot (application/config/version).
# Build number comes from export_presets.cfg (version/code; the file is
# gitignored, see docs/release.md §2). Signing uses ~/.arrowlock/signing.env.
set -euo pipefail
cd "$(dirname "$0")/.."

PRESETS=export_presets.cfg
[ -f "$PRESETS" ] || { echo "Missing $PRESETS (see docs/release.md §2)" >&2; exit 1; }
SIGNING="$HOME/.arrowlock/signing.env"
[ -f "$SIGNING" ] || { echo "Missing $SIGNING" >&2; exit 1; }

code=$(sed -n 's/^version\/code=\([0-9]*\)$/\1/p' "$PRESETS")
if [ "${1:-}" = "--bump" ]; then
	code=$((code + 1))
	sed -i "s/^version\/code=[0-9]*$/version\/code=$code/" "$PRESETS"
fi
version=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
out="build/arrowlock-$version-b$code-arm64-v8a.apk"

echo "Testing..."
godot --headless --path . -s tests/run_tests.gd 2>&1 | tail -1 | tee /dev/stderr | grep -q " 0 failed" \
	|| { echo "Tests failed; not building." >&2; exit 1; }

# shellcheck disable=SC1090
source "$SIGNING"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
mkdir -p build
echo "Building $out ..."
godot --headless --path . --export-release Android "$out" 2>&1 | grep -E "ERROR" && { echo "Export failed." >&2; exit 1; }
[ -f "$out" ] || { echo "Export produced no file." >&2; exit 1; }
echo "Built $out (version $version, build $code, commit $(git rev-parse --short HEAD)$(git diff --quiet || echo '+uncommitted'))"
