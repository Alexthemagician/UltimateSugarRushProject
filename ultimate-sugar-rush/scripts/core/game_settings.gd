extends Node

signal settings_changed

const SETTINGS_SECTION := "settings"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var music_volume := 0.8
var sfx_volume := 0.8
var notifications_enabled := false


func _ready() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)
	music_volume = clampf(float(SaveSystem.get_value(SETTINGS_SECTION, "music_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(SaveSystem.get_value(SETTINGS_SECTION, "sfx_volume", 0.8)), 0.0, 1.0)
	# Notification scheduling/permission is intentionally not integrated yet.
	notifications_enabled = bool(SaveSystem.get_value(SETTINGS_SECTION, "notifications_enabled", false))
	_apply_audio()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(MUSIC_BUS, music_volume)
	_store("music_volume", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(SFX_BUS, sfx_volume)
	_store("sfx_volume", sfx_volume)


func set_notifications_enabled(enabled: bool) -> void:
	notifications_enabled = enabled
	_store("notifications_enabled", notifications_enabled)


func _store(key: String, value: Variant) -> void:
	SaveSystem.set_value(SETTINGS_SECTION, key, value)
	settings_changed.emit()


func _apply_audio() -> void:
	_apply_bus_volume(MUSIC_BUS, music_volume)
	_apply_bus_volume(SFX_BUS, sfx_volume)


func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, 0.0001)))


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
