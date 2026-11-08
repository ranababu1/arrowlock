class_name BuildInfo
extends RefCounted
## Facts stamped into each exported build by tools/build_android.sh, read from
## res://data/build_info.json (gitignored, absent in the editor and in tests):
##   "build"    : the Android version code
##   "commit"   : short git commit
##   "test_ads" : true for device-testing APKs (Google's test ad unit), false
##                for the Play AAB (the real ad unit)

const PATH := "res://data/build_info.json"


## The stamp as a Dictionary, or {} when there is none or it is unreadable.
static func read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return info if typeof(info) == TYPE_DICTIONARY else {}


## Version code, or -1 when the build was not stamped.
static func build_number(path: String = PATH) -> int:
	var build: Variant = read(path).get("build")
	return int(build) if typeof(build) in [TYPE_INT, TYPE_FLOAT] else -1


## True only when the build script marked this build as a test-ads build.
static func forces_test_ads(path: String = PATH) -> bool:
	return read(path).get("test_ads", false) == true
