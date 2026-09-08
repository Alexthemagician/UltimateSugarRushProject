extends Node

signal database_ready
signal record_changed(table_name: String, record_id: String)

const DATABASE_PATH := "res://data/game_database.json"
const MUTABLE_TABLES := [&"users", &"player_stats", &"quest_progress", &"inventory"]

var _tables: Dictionary = {}
var _indexes: Dictionary = {}


func _ready() -> void:
	_load_definitions()
	_load_player_tables()
	_ensure_local_player()
	database_ready.emit()


func get_record(table_name: StringName, record_id: String, default_value: Variant = null) -> Variant:
	var table_index: Dictionary = _indexes.get(table_name, {})
	var record: Variant = table_index.get(record_id, default_value)
	return record.duplicate(true) if record is Dictionary or record is Array else record


func get_all(table_name: StringName) -> Array:
	var table: Array = _tables.get(table_name, [])
	return table.duplicate(true)


func has_record(table_name: StringName, record_id: String) -> bool:
	return _indexes.get(table_name, {}).has(record_id)


func upsert_record(table_name: StringName, record: Dictionary) -> bool:
	if table_name not in MUTABLE_TABLES:
		push_error("Table '%s' is read-only." % table_name)
		return false
	var record_id := str(record.get("id", ""))
	if record_id.is_empty():
		push_error("Records require a non-empty id.")
		return false
	var table: Array = _tables.get(table_name, [])
	var replaced := false
	for index in table.size():
		if str(table[index].get("id", "")) == record_id:
			table[index] = record.duplicate(true)
			replaced = true
			break
	if not replaced:
		table.append(record.duplicate(true))
	_tables[table_name] = table
	_rebuild_index(table_name)
	_persist_player_tables()
	record_changed.emit(String(table_name), record_id)
	return true


func update_fields(table_name: StringName, record_id: String, changes: Dictionary) -> bool:
	var record: Variant = get_record(table_name, record_id)
	if not record is Dictionary:
		return false
	for key: Variant in changes:
		if key != "id":
			record[key] = changes[key]
	return upsert_record(table_name, record)


func get_local_user() -> Dictionary:
	return get_record(&"users", "local_player", {})


func get_player_stats() -> Dictionary:
	return get_record(&"player_stats", "local_player", {})


func grant_xp(reward_id: String) -> bool:
	var reward: Variant = get_record(&"xp_rewards", reward_id)
	if not reward is Dictionary:
		return false
	var stats := get_player_stats()
	stats["xp"] = int(stats.get("xp", 0)) + int(reward.get("amount", 0))
	return upsert_record(&"player_stats", stats)


func grant_currency(reward_id: String) -> bool:
	var reward: Variant = get_record(&"currency_rewards", reward_id)
	if not reward is Dictionary:
		return false
	var stats := get_player_stats()
	var currency := str(reward.get("currency", ""))
	if currency not in ["coins", "gems"]:
		return false
	stats[currency] = int(stats.get(currency, 0)) + int(reward.get("amount", 0))
	return upsert_record(&"player_stats", stats)


func _load_definitions() -> void:
	var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if not file:
		push_error("Could not open game database definitions.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Game database definitions are not valid JSON.")
		return
	for key: Variant in parsed:
		if parsed[key] is Array:
			_tables[StringName(key)] = parsed[key]
	for table_name: StringName in _tables:
		_rebuild_index(table_name)


func _load_player_tables() -> void:
	var saved_tables := SaveSystem.get_section("database")
	for table_name: StringName in MUTABLE_TABLES:
		var saved_table: Variant = saved_tables.get(String(table_name), [])
		_tables[table_name] = saved_table if saved_table is Array else []
		_rebuild_index(table_name)


func _ensure_local_player() -> void:
	if not has_record(&"users", "local_player"):
		upsert_record(&"users", {
			"id": "local_player",
			"display_name": "Chef",
			"created_at_unix": int(Time.get_unix_time_from_system()),
			"last_played_at_unix": int(Time.get_unix_time_from_system())
		})
	if not has_record(&"player_stats", "local_player"):
		upsert_record(&"player_stats", {
			"id": "local_player",
			"level": 1,
			"xp": 0,
			"coins": 1250,
			"gems": 0,
			"orders_completed": 0,
			"quests_completed": 0,
			"total_play_seconds": 0
		})


func _persist_player_tables() -> void:
	var saved_tables: Dictionary = {}
	for table_name: StringName in MUTABLE_TABLES:
		saved_tables[String(table_name)] = _tables.get(table_name, []).duplicate(true)
	SaveSystem.set_section("database", saved_tables)


func _rebuild_index(table_name: StringName) -> void:
	var table_index: Dictionary = {}
	for record: Variant in _tables.get(table_name, []):
		if not record is Dictionary:
			continue
		var record_id := str(record.get("id", ""))
		if record_id.is_empty():
			push_warning("A record in '%s' has no id." % table_name)
			continue
		if table_index.has(record_id):
			push_warning("Duplicate id '%s' in '%s'." % [record_id, table_name])
		table_index[record_id] = record
	_indexes[table_name] = table_index
