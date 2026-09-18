extends "res://scripts/cafe/cafe_region.gd"

func _ready() -> void:
	CafeProgress.region = 0
	_reconcile_saved_unlocks()
	super._ready()

func _reconcile_saved_unlocks() -> void:
	var cookie_objectives := SaveSystem.get_section("cookie_merge_objectives")
	var cookie_boxes := [
		"chocolate_chip_cookie_box",
		"pink_sugar_cookie_box",
		"sandwich_cookie_box",
		"lucky_cookie_box",
	]
	for item_id: String in cookie_boxes:
		if int(cookie_objectives.get(item_id, 0)) < 8:
			return
	SaveSystem.set_value("progression", "level_3_complete", true)
	SaveSystem.set_value("progression", "level_4_unlocked", true)
	SaveSystem.save_now()


