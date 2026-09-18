extends Node

# Stable game-facing boundary for rewarded ads. Desktop/editor/headless builds use
# a short mock so the complete reward flow remains testable without ad traffic.
signal rewarded_result(earned: bool)

var mock_delay := 1.2
var _admob: Node
var _show_in_progress := false
var _resolved := false

func _ready() -> void:
	if not OS.has_feature("android"):
		return
	_admob = get_node_or_null("/root/AdmobClient")
	if _admob == null:
		push_error("AdMob client autoload is missing.")
		return
	_admob.initialization_completed.connect(_on_initialization_completed)
	_admob.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
	_admob.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
	_admob.rewarded_ad_user_earned_reward.connect(_on_reward_earned)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(_on_reward_dismissed)
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(_on_reward_failed_to_show)
	_admob.initialize()

func is_available() -> bool:
	if not OS.has_feature("android"):
		return OS.has_feature("editor") or DisplayServer.get_name() == "headless"
	return _admob != null and not _show_in_progress and _admob.is_rewarded_ad_loaded()

func show_rewarded_spin_ad() -> bool:
	if not OS.has_feature("android"):
		if not is_available():
			return false
		await get_tree().create_timer(mock_delay).timeout
		return true
	if not is_available():
		return false
	_show_in_progress = true
	_resolved = false
	_admob.show_rewarded_ad()
	return await rewarded_result

func _on_initialization_completed(_status: Variant) -> void:
	_load_next_rewarded_ad()

func _on_rewarded_ad_loaded(_ad_info: Variant, _response: Variant) -> void:
	pass

func _on_rewarded_ad_failed_to_load(_ad_info: Variant, error: Variant) -> void:
	push_warning("Rewarded ad failed to load: %s" % str(error))

func _on_reward_earned(_ad_info: Variant, _reward: Variant) -> void:
	_resolve_show(true)

func _on_reward_dismissed(_ad_info: Variant) -> void:
	_resolve_show(false)
	_load_next_rewarded_ad()

func _on_reward_failed_to_show(_ad_info: Variant, error: Variant) -> void:
	push_warning("Rewarded ad failed to show: %s" % str(error))
	_resolve_show(false)
	_load_next_rewarded_ad()

func _resolve_show(earned: bool) -> void:
	if not _show_in_progress or _resolved:
		return
	_resolved = true
	_show_in_progress = false
	rewarded_result.emit(earned)

func _load_next_rewarded_ad() -> void:
	if _admob != null and not _admob.is_rewarded_ad_loaded():
		_admob.load_rewarded_ad()
