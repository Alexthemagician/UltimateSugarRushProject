extends Node

signal data_loaded
signal data_saved

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1
const AUTOSAVE_DELAY := 0.75

var _data: Dictionary = {}
var _dirty := false
var _autosave_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_DELAY
	_autosave_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_autosave_timer.timeout.connect(save_now)
	add_child(_autosave_timer)
	load_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
	or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
	or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func load_save() -> void:
	_data = {"save_version": SAVE_VERSION}
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	_data["save_version"] = SAVE_VERSION
	_dirty = false
	data_loaded.emit()


func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	var section_data: Variant = _data.get(section, {})
	if section_data is Dictionary:
		return section_data.get(key, default_value)
	return default_value


func set_value(section: String, key: String, value: Variant) -> void:
	var section_data: Dictionary = _data.get(section, {})
	if section_data.get(key) == value:
		return
	section_data[key] = value
	_data[section] = section_data
	mark_dirty()


func set_section(section: String, values: Dictionary) -> void:
	if _data.get(section, {}) == values:
		return
	_data[section] = values.duplicate(true)
	mark_dirty()


func get_section(section: String) -> Dictionary:
	var values: Variant = _data.get(section, {})
	return values.duplicate(true) if values is Dictionary else {}


func mark_dirty() -> void:
	_dirty = true
	if _autosave_timer:
		_autosave_timer.start()


func save_now() -> void:
	if not _dirty:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Could not open the autosave file (error %s)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.flush()
	_dirty = false
	data_saved.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
