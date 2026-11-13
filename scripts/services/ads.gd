class_name Ads
extends Node
## Interstitial ads after a finished game (AdMob).
##
## Uses the Admob node of the AdmobPlugin addon (addons/AdmobPlugin, MIT, v7.0;
## Google Mobile Ads 24.9.0 on Android, 12.14.0 on iOS). On desktop, in tests,
## when "enabled" is false, or when real ads are switched on without a unit id
## for this platform, everything here quietly does nothing and the game plays
## exactly as before.
##
## Android and iOS are separate apps in AdMob, each with its own ad unit:
## "interstitial_unit_id" is Android's, "ios_interstitial_unit_id" is iOS's.
##
## Start-up order follows Google's UMP guidance: ask for consent info first,
## show the consent form when it is required (EEA/UK), and only then initialise
## the SDK and preload one interstitial. A new one is preloaded after each show.
##
## Which games earn an ad is AdPolicy; settings live in data/ads.json.

const SINGLETON := "AdmobPlugin"
const CONFIG_PATH := "res://data/ads.json"
const ANDROID_UNIT_KEY := "interstitial_unit_id"
const IOS_UNIT_KEY := "ios_interstitial_unit_id"
## Wait before retrying a failed load; doubles after each failure up to the max.
const RETRY_FIRST_SECONDS := 30.0
const RETRY_MAX_SECONDS := 300.0

var policy := AdPolicy.new()
var use_real_ads := false
## The real ad unit of the platform this build runs on ("" = none set).
var interstitial_unit_id := ""
## Which unit id is used. Tests replace it.
var is_ios := OS.has_feature("ios")
## Wall-clock Unix time in seconds. Tests replace it.
var clock: Callable = func() -> float: return Time.get_unix_time_from_system()

## The Admob node, or a stand-in with the same signals and methods in tests.
var _backend: Node
var _sdk_started := false
var _sdk_ready := false
var _loading := false
var _retry_seconds := RETRY_FIRST_SECONDS
## What to run once the ad on screen closes.
var _pending := Callable()


## `backend` is for tests; normally an Admob node is made when the native
## plugin (Android or iOS) is present. A build stamped "test_ads" by the build
## script (the device-testing build) always uses Google's test ad unit, whatever
## ads.json says, so the owner's own phones never load real ads.
func start(backend: Node = null, config_path: String = CONFIG_PATH, build_info_path: String = BuildInfo.PATH, state_path: String = AdPolicy.DEFAULT_STATE_PATH) -> void:
	var config := load_config(config_path)
	policy = AdPolicy.from_config(config)
	policy.state_path = state_path
	policy.load_state(clock.call())
	use_real_ads = bool(config.get("use_real_ads", false)) and not BuildInfo.forces_test_ads(build_info_path)
	interstitial_unit_id = unit_id_for(config, is_ios)
	if not policy.enabled:
		return
	if backend == null:
		backend = _make_admob()
	if backend == null:
		return
	_backend = backend
	_backend.consent_info_updated.connect(_on_consent_info_updated)
	_backend.consent_info_update_failed.connect(_on_consent_unavailable)
	_backend.consent_form_loaded.connect(_on_consent_form_loaded)
	_backend.consent_form_failed_to_load.connect(_on_consent_unavailable)
	_backend.consent_form_dismissed.connect(_on_consent_form_dismissed)
	_backend.initialization_completed.connect(_on_initialized)
	_backend.interstitial_ad_loaded.connect(_on_loaded)
	_backend.interstitial_ad_failed_to_load.connect(_on_load_failed)
	_backend.interstitial_ad_dismissed_full_screen_content.connect(_on_closed)
	_backend.interstitial_ad_failed_to_show_full_screen_content.connect(_on_closed)
	_backend.update_consent_info()


## True once ads can be requested (consent settled, SDK initialised).
func is_active() -> bool:
	return _sdk_ready


## Call when the player leaves an end-of-game panel. Records the finished
## round, then shows an interstitial first if that game earns one and an ad
## is ready, then runs `then`; otherwise runs `then` at once. Returns true
## if an ad was shown. A missing ad is not marked as shown, so the next
## eligible leave can still show one.
func show_after_game(level_id: int, then: Callable) -> bool:
	# An earlier ad that never reported closing must not fire its action later.
	_pending = Callable()
	var now: float = clock.call()
	policy.record_round(level_id, now)
	if not _sdk_ready or not policy.should_show(level_id, now) or not _backend.is_interstitial_ad_loaded():
		then.call()
		return false
	_pending = then
	policy.mark_shown(now)
	_backend.show_interstitial_ad()
	return true


## Consent answers that let us request ads: none needed, or the player answered.
static func consent_allows_ads(consent: Object) -> bool:
	if consent == null:
		return false
	return consent.status == UserConsent.Status.NOT_REQUIRED or consent.status == UserConsent.Status.OBTAINED


## The real interstitial unit id in `config` for iOS or for Android.
static func unit_id_for(config: Dictionary, ios: bool) -> String:
	return str(config.get(IOS_UNIT_KEY if ios else ANDROID_UNIT_KEY, "")).strip_edges()


## Reads data/ads.json; {} (ads on, test ads, defaults) when missing or broken.
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ads: %s is not a JSON object; using defaults" % path)
		return {}
	return parsed


func _make_admob() -> Node:
	if not Engine.has_singleton(SINGLETON):
		return null
	if use_real_ads and interstitial_unit_id == "":
		push_warning("Ads: use_real_ads is on but %s is empty; ads are off" % (IOS_UNIT_KEY if is_ios else ANDROID_UNIT_KEY))
		return null
	var admob := Admob.new()
	# Set before add_child: Admob._ready picks the ad unit ids from these.
	admob.is_real = use_real_ads
	if is_ios:
		admob.ios_real_interstitial_id = interstitial_unit_id
	else:
		admob.android_real_interstitial_id = interstitial_unit_id
	# A shown interstitial cannot be shown again; drop it so the next load counts.
	admob.remove_interstitial_ads_after_displayed = true
	add_child(admob)
	return admob


func _on_consent_info_updated() -> void:
	var consent: Object = _backend.get_consent_status()
	if consent != null and consent.status == UserConsent.Status.REQUIRED and _backend.is_consent_form_available():
		_backend.load_consent_form()
	elif consent_allows_ads(consent):
		_start_sdk()


func _on_consent_form_loaded() -> void:
	_backend.show_consent_form()


func _on_consent_form_dismissed(_error: Variant = null) -> void:
	if consent_allows_ads(_backend.get_consent_status()):
		_start_sdk()


## Offline or the form failed: go on only if an earlier answer allows ads.
func _on_consent_unavailable(_error: Variant = null) -> void:
	if consent_allows_ads(_backend.get_consent_status()):
		_start_sdk()


func _start_sdk() -> void:
	if _sdk_started:
		return
	_sdk_started = true
	_backend.initialize()


func _on_initialized(_status: Variant = null) -> void:
	_sdk_ready = true
	_load()


func _load() -> void:
	if not _sdk_ready or _loading or _backend.is_interstitial_ad_loaded():
		return
	_loading = true
	_backend.load_interstitial_ad()


func _on_loaded(_ad: Variant = null, _info: Variant = null) -> void:
	_loading = false
	_retry_seconds = RETRY_FIRST_SECONDS


func _on_load_failed(_ad: Variant = null, _error: Variant = null) -> void:
	_loading = false
	if is_inside_tree():
		get_tree().create_timer(_retry_seconds).timeout.connect(_load)
	_retry_seconds = minf(_retry_seconds * 2.0, RETRY_MAX_SECONDS)


## The ad closed (or could not be shown): carry on and preload the next one.
func _on_closed(_ad: Variant = null, _error: Variant = null) -> void:
	var then := _pending
	_pending = Callable()
	if then.is_valid():
		then.call()
	_load()
